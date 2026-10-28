/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * darling-webhost's web process extension: script access between pages
 * and the Darling app that owns them, over a TCP connection to the app's
 * bridge (WebKitLegacy's DWKBridge).  Calls block and nest in both
 * directions: while waiting for an answer, each side serves the other's
 * requests.  JS objects travel as handles ({"$js":n}) kept here, the app's
 * Objective-C objects as handles ({"$oc":n}) that pages see through Proxy
 * objects.  See docs/darling-webhost.md.
 */

#include <webkit2/webkit-web-extension.h>
#include <jsc/jsc.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <math.h>
#include <glib-unix.h>

static WebKitWebExtension *extension;
static guint16 bridge_port;
static int bridge_fd = -1;
static GString *read_buffer;
static gint64 next_id;
static GHashTable *stashed_replies; /* id -> JSCValue (protocol context) */
static GPtrArray *handles;          /* JSCValue, in their page's context */
static JSCContext *protocol;        /* where messages are parsed and built */
static gboolean debug;

static const char bootstrap[] =
	"(function (native) {\n"
	"  var ids = new WeakMap(), cache = new Map();\n"
	"  Object.defineProperty(globalThis, '__dwk_ids', { value: ids });\n"
	"  Object.defineProperty(globalThis, '__dwk_proxy', { value: function (h) {\n"
	"    var p = cache.get(h);\n"
	"    if (p) return p;\n"
	"    p = new Proxy({}, {\n"
	"      get: function (t, k) {\n"
	"        if (typeof k !== 'string') return k === Symbol.toPrimitive ? function () { return '[object ObjC]'; } : undefined;\n"
	"        if (k === 'toString' || k === 'valueOf') return function () { return '[object ObjC]'; };\n"
	"        if (k === 'then' || k === 'toJSON' || k === 'constructor') return undefined;\n"
	"        var r = native('get', h, k);\n"
	"        if (r !== null && typeof r === 'object' && r.__dwk_m === 1)\n"
	"          return function () { return native('call', h, k, Array.prototype.slice.call(arguments)); };\n"
	"        return r;\n"
	"      },\n"
	"      set: function (t, k, v) { native('set', h, k, v); return true; },\n"
	"      has: function (t, k) { return typeof k === 'string' && native('get', h, k) !== undefined; }\n"
	"    });\n"
	"    cache.set(h, p);\n"
	"    ids.set(p, h);\n"
	"    return p;\n"
	"  } });\n"
	"})";

/* Connection */

static gboolean on_bridge_readable(gint fd, GIOCondition condition, gpointer data);

static gboolean bridge_connect(void)
{
	if (bridge_fd >= 0)
		return TRUE;
	if (bridge_port == 0)
		return FALSE;
	int fd = socket(AF_INET, SOCK_STREAM, 0);
	struct sockaddr_in address = { 0 };
	address.sin_family = AF_INET;
	address.sin_port = htons(bridge_port);
	address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	if (fd < 0 || connect(fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
		g_warning("darling-webhost-extension: cannot reach the app on port %u: %s", bridge_port, g_strerror(errno));
		if (fd >= 0)
			close(fd);
		bridge_port = 0;
		return FALSE;
	}
	int one = 1;
	setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
	bridge_fd = fd;
	/* The app's requests arrive while the page is idle too. */
	g_unix_fd_add(fd, G_IO_IN | G_IO_HUP | G_IO_ERR, on_bridge_readable, NULL);
	return TRUE;
}

static void bridge_close(void)
{
	if (bridge_fd >= 0)
		close(bridge_fd);
	bridge_fd = -1;
	bridge_port = 0;
}

static gboolean write_message(JSCValue *message)
{
	if (bridge_fd < 0)
		return FALSE;
	char *json = jsc_value_to_json(message, 0);
	if (debug)
		g_message("ext> %.300s", json);
	GString *line = g_string_new(json);
	g_free(json);
	g_string_append_c(line, '\n');
	const char *bytes = line->str;
	gsize left = line->len;
	while (left > 0) {
		ssize_t n = write(bridge_fd, bytes, left);
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0) {
			g_string_free(line, TRUE);
			bridge_close();
			return FALSE;
		}
		bytes += n;
		left -= n;
	}
	g_string_free(line, TRUE);
	return TRUE;
}

/* The next message, blocking; NULL when the app has gone. */
static JSCValue *read_message(void)
{
	for (;;) {
		char *newline = memchr(read_buffer->str, '\n', read_buffer->len);
		if (newline != NULL) {
			gsize length = newline - read_buffer->str;
			char *line = g_strndup(read_buffer->str, length);
			g_string_erase(read_buffer, 0, length + 1);
			if (debug)
				g_message("<ext %.300s", line);
			JSCValue *message = jsc_value_new_from_json(protocol, line);
			g_free(line);
			if (jsc_context_get_exception(protocol) != NULL) {
				jsc_context_clear_exception(protocol);
				g_clear_object(&message);
				continue;
			}
			return message;
		}
		if (bridge_fd < 0)
			return NULL;
		char chunk[65536];
		ssize_t n = read(bridge_fd, chunk, sizeof(chunk));
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0) {
			bridge_close();
			return NULL;
		}
		g_string_append_len(read_buffer, chunk, n);
	}
}

/* Values */

static JSCValue *protocol_string(const char *string)
{
	return jsc_value_new_string(protocol, string);
}

static void set_member(JSCValue *object, const char *name, JSCValue *value)
{
	jsc_value_object_set_property(object, name, value);
	g_object_unref(value);
}

static JSCValue *get_member(JSCValue *object, const char *name)
{
	return jsc_value_object_get_property(object, name);
}

static gboolean has_member(JSCValue *object, const char *name)
{
	JSCValue *value = get_member(object, name);
	gboolean has = value != NULL && !jsc_value_is_undefined(value);
	g_clear_object(&value);
	return has;
}

static gint64 member_int(JSCValue *object, const char *name)
{
	JSCValue *value = get_member(object, name);
	gint64 number = value != NULL && jsc_value_is_number(value) ? (gint64)jsc_value_to_double(value) : -1;
	g_clear_object(&value);
	return number;
}

static char *member_string(JSCValue *object, const char *name)
{
	JSCValue *value = get_member(object, name);
	char *string = value != NULL && jsc_value_is_string(value) ? jsc_value_to_string(value) : NULL;
	g_clear_object(&value);
	return string;
}

static gint64 remember(JSCValue *value)
{
	g_ptr_array_add(handles, g_object_ref(value));
	return handles->len - 1;
}

static JSCValue *handle_value(gint64 handle)
{
	return handle >= 0 && handle < (gint64)handles->len ? g_ptr_array_index(handles, handle) : NULL;
}

/* An object that stands for one of the app's objects: its handle, or -1. */
static gint64 objc_handle_of(JSCValue *value)
{
	JSCContext *context = jsc_value_get_context(value);
	JSCValue *ids = jsc_context_get_value(context, "__dwk_ids");
	gint64 handle = -1;
	if (ids != NULL && jsc_value_is_object(ids)) {
		JSCValue *found = jsc_value_object_invoke_method(ids, "get", JSC_TYPE_VALUE, value, G_TYPE_NONE);
		if (found != NULL && jsc_value_is_number(found))
			handle = (gint64)jsc_value_to_double(found);
		g_clear_object(&found);
	}
	g_clear_object(&ids);
	return handle;
}

/* A page value as a protocol value. */
static JSCValue *encode(JSCValue *value)
{
	if (value == NULL || jsc_value_is_undefined(value)) {
		JSCValue *marker = jsc_value_new_object(protocol, NULL, NULL);
		set_member(marker, "$u", jsc_value_new_number(protocol, 1));
		return marker;
	}
	if (jsc_value_is_null(value))
		return jsc_value_new_null(protocol);
	if (jsc_value_is_boolean(value))
		return jsc_value_new_boolean(protocol, jsc_value_to_boolean(value));
	if (jsc_value_is_number(value)) {
		double number = jsc_value_to_double(value);
		if (isfinite(number))
			return jsc_value_new_number(protocol, number);
		JSCValue *marker = jsc_value_new_object(protocol, NULL, NULL);
		set_member(marker, "$n", protocol_string(isnan(number) ? "nan" : number > 0 ? "inf" : "-inf"));
		return marker;
	}
	if (jsc_value_is_string(value)) {
		char *string = jsc_value_to_string(value);
		JSCValue *encoded = protocol_string(string);
		g_free(string);
		return encoded;
	}
	JSCValue *marker = jsc_value_new_object(protocol, NULL, NULL);
	gint64 objc = objc_handle_of(value);
	if (objc >= 0)
		set_member(marker, "$oc", jsc_value_new_number(protocol, objc));
	else
		set_member(marker, "$js", jsc_value_new_number(protocol, remember(value)));
	return marker;
}

/* A protocol value as a value in context. */
static JSCValue *decode(JSCValue *value, JSCContext *context)
{
	if (value == NULL || jsc_value_is_undefined(value))
		return jsc_value_new_undefined(context);
	if (jsc_value_is_null(value))
		return jsc_value_new_null(context);
	if (jsc_value_is_boolean(value))
		return jsc_value_new_boolean(context, jsc_value_to_boolean(value));
	if (jsc_value_is_number(value))
		return jsc_value_new_number(context, jsc_value_to_double(value));
	if (jsc_value_is_string(value)) {
		char *string = jsc_value_to_string(value);
		JSCValue *decoded = jsc_value_new_string(context, string);
		g_free(string);
		return decoded;
	}
	if (jsc_value_is_array(value)) {
		GPtrArray *items = g_ptr_array_new_with_free_func(g_object_unref);
		gint64 length = member_int(value, "length");
		for (gint64 i = 0; i < length; i++) {
			JSCValue *item = jsc_value_object_get_property_at_index(value, (guint)i);
			g_ptr_array_add(items, decode(item, context));
			g_clear_object(&item);
		}
		JSCValue *array = jsc_value_new_array_from_garray(context, items);
		g_ptr_array_unref(items);
		return array;
	}
	if (has_member(value, "$u"))
		return jsc_value_new_undefined(context);
	if (has_member(value, "$m")) {
		JSCValue *marker = jsc_value_new_object(context, NULL, NULL);
		JSCValue *one = jsc_value_new_number(context, 1);
		jsc_value_object_set_property(marker, "__dwk_m", one);
		g_object_unref(one);
		return marker;
	}
	if (has_member(value, "$n")) {
		char *special = member_string(value, "$n");
		double number = special != NULL && strcmp(special, "inf") == 0 ? INFINITY :
			special != NULL && strcmp(special, "-inf") == 0 ? -INFINITY : NAN;
		g_free(special);
		return jsc_value_new_number(context, number);
	}
	if (has_member(value, "$js")) {
		JSCValue *found = handle_value(member_int(value, "$js"));
		return found != NULL ? g_object_ref(found) : jsc_value_new_undefined(context);
	}
	if (has_member(value, "$oc")) {
		JSCValue *factory = jsc_context_get_value(context, "__dwk_proxy");
		JSCValue *proxy = NULL;
		if (factory != NULL && jsc_value_is_function(factory)) {
			JSCValue *handle = jsc_value_new_number(context, member_int(value, "$oc"));
			proxy = jsc_value_function_call(factory, JSC_TYPE_VALUE, handle, G_TYPE_NONE);
			g_object_unref(handle);
		}
		g_clear_object(&factory);
		return proxy != NULL ? proxy : jsc_value_new_undefined(context);
	}
	if (has_member(value, "$a")) {
		JSCValue *array = get_member(value, "$a");
		JSCValue *decoded = decode(array, context);
		g_clear_object(&array);
		return decoded;
	}
	return jsc_value_new_undefined(context);
}

/* Requests */

static JSCValue *serve(JSCValue *request);
static gboolean drain_later(gpointer data);

/* Sends a request and waits for its answer, serving the app's requests
 * meanwhile.  Returns the answer (protocol context) or NULL. */
static JSCValue *send_request(JSCValue *request)
{
	if (!bridge_connect())
		return NULL;
	gint64 id = ++next_id;
	set_member(request, "id", jsc_value_new_number(protocol, id));
	if (!write_message(request))
		return NULL;
	for (;;) {
		JSCValue *reply = g_hash_table_lookup(stashed_replies, &id);
		if (reply != NULL) {
			g_object_ref(reply);
			g_hash_table_remove(stashed_replies, &id);
			char *error = member_string(reply, "err");
			JSCValue *ok = error == NULL ? get_member(reply, "ok") : NULL;
			if (error != NULL)
				g_warning("darling-webhost-extension: the app failed a request: %s", error);
			g_free(error);
			g_object_unref(reply);
			/* What was read past the answer waits for the main loop. */
			if (memchr(read_buffer->str, '\n', read_buffer->len) != NULL)
				g_idle_add(drain_later, NULL);
			return ok;
		}
		JSCValue *message = read_message();
		if (message == NULL)
			return NULL;
		if (has_member(message, "re")) {
			gint64 re = member_int(message, "re");
			g_hash_table_insert(stashed_replies, g_memdup2(&re, sizeof(re)), message);
			continue;
		}
		JSCValue *answer = serve(message);
		write_message(answer);
		g_object_unref(answer);
		g_object_unref(message);
	}
}

/* Serves the complete messages already read (outside any wait). */
static void drain(void)
{
	while (bridge_fd >= 0 && memchr(read_buffer->str, '\n', read_buffer->len) != NULL) {
		JSCValue *message = read_message();
		if (message == NULL)
			return;
		if (has_member(message, "re")) {
			gint64 re = member_int(message, "re");
			g_hash_table_insert(stashed_replies, g_memdup2(&re, sizeof(re)), message);
			continue;
		}
		JSCValue *answer = serve(message);
		write_message(answer);
		g_object_unref(answer);
		g_object_unref(message);
	}
}

static gboolean drain_later(gpointer data)
{
	drain();
	return G_SOURCE_REMOVE;
}

static gboolean on_bridge_readable(gint fd, GIOCondition condition, gpointer data)
{
	if (fd != bridge_fd)
		return G_SOURCE_REMOVE;
	char chunk[65536];
	ssize_t n = recv(fd, chunk, sizeof(chunk), MSG_DONTWAIT);
	if (n == 0 || (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)) {
		bridge_close();
		return G_SOURCE_REMOVE;
	}
	if (n > 0)
		g_string_append_len(read_buffer, chunk, n);
	drain();
	return bridge_fd >= 0 ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE;
}

static JSCContext *page_context(gint64 page_id)
{
	WebKitWebPage *page = page_id >= 0 ? webkit_web_extension_get_page(extension, (guint64)page_id) : NULL;
	if (page == NULL)
		return NULL;
	return webkit_frame_get_js_context(webkit_web_page_get_main_frame(page));
}

/* Answers one of the app's requests. */
static JSCValue *serve(JSCValue *request)
{
	JSCValue *answer = jsc_value_new_object(protocol, NULL, NULL);
	JSCValue *id = get_member(request, "id");
	set_member(answer, "re", id);
	char *op = member_string(request, "op");
	JSCValue *object = handle_value(member_int(request, "obj"));
	JSCContext *context = object != NULL ? g_object_ref(jsc_value_get_context(object)) : page_context(member_int(request, "page"));
	char *key = member_string(request, "key");
	char *name = member_string(request, "name");
	JSCValue *result = NULL;
	char *error = NULL;

	if (op == NULL || context == NULL) {
		error = g_strdup("no such page or object");
	} else if (strcmp(op, "eval") == 0) {
		char *script = member_string(request, "script");
		result = jsc_context_evaluate(context, script != NULL ? script : "", -1);
		g_free(script);
	} else if (strcmp(op, "window") == 0) {
		result = jsc_context_get_global_object(context);
	} else if (object == NULL) {
		error = g_strdup("no such object");
	} else if (strcmp(op, "get") == 0 && key != NULL) {
		result = jsc_value_object_get_property(object, key);
	} else if (strcmp(op, "set") == 0 && key != NULL) {
		JSCValue *protocol_value = get_member(request, "value");
		JSCValue *value = decode(protocol_value, context);
		jsc_value_object_set_property(object, key, value);
		g_object_unref(value);
		g_clear_object(&protocol_value);
	} else if (strcmp(op, "remove") == 0 && key != NULL) {
		jsc_value_object_delete_property(object, key);
	} else if (strcmp(op, "index") == 0) {
		result = jsc_value_object_get_property_at_index(object, (guint)member_int(request, "i"));
	} else if (strcmp(op, "setindex") == 0) {
		JSCValue *protocol_value = get_member(request, "value");
		JSCValue *value = decode(protocol_value, context);
		jsc_value_object_set_property_at_index(object, (guint)member_int(request, "i"), value);
		g_object_unref(value);
		g_clear_object(&protocol_value);
	} else if (strcmp(op, "string") == 0) {
		char *string = jsc_value_to_string(object);
		result = jsc_value_new_string(context, string);
		g_free(string);
	} else if (strcmp(op, "call") == 0 || strcmp(op, "apply") == 0) {
		JSCValue *protocol_args = get_member(request, "args");
		JSCValue *args = decode(protocol_args, context);
		gint64 count = jsc_value_is_array(args) ? member_int(args, "length") : 0;
		GPtrArray *list = g_ptr_array_new_with_free_func(g_object_unref);
		for (gint64 i = 0; i < count; i++)
			g_ptr_array_add(list, jsc_value_object_get_property_at_index(args, (guint)i));
		if (strcmp(op, "call") == 0 && name != NULL)
			result = jsc_value_object_invoke_methodv(object, name, list->len, (JSCValue **)list->pdata);
		else
			result = jsc_value_function_callv(object, list->len, (JSCValue **)list->pdata);
		g_ptr_array_unref(list);
		g_object_unref(args);
		g_clear_object(&protocol_args);
	} else {
		error = g_strdup_printf("unknown request %s", op);
	}

	JSCException *exception = context != NULL ? jsc_context_get_exception(context) : NULL;
	if (exception != NULL && error == NULL) {
		error = g_strdup(jsc_exception_get_message(exception));
		jsc_context_clear_exception(context);
	}
	if (error != NULL)
		set_member(answer, "err", protocol_string(error));
	else
		set_member(answer, "ok", encode(result));
	g_clear_object(&result);
	g_clear_object(&context);
	g_free(error);
	g_free(op);
	g_free(key);
	g_free(name);
	return answer;
}

/* Called by the proxies: native('get' | 'set' | 'call', handle, key, value or args). */
static JSCValue *native_call(GPtrArray *args, gpointer data)
{
	JSCContext *context = jsc_context_get_current();
	if (args->len < 3)
		return jsc_value_new_undefined(context);
	char *op = jsc_value_to_string(g_ptr_array_index(args, 0));
	double handle = jsc_value_to_double(g_ptr_array_index(args, 1));
	char *key = jsc_value_to_string(g_ptr_array_index(args, 2));

	JSCValue *request = jsc_value_new_object(protocol, NULL, NULL);
	set_member(request, "op", protocol_string(op));
	set_member(request, "obj", jsc_value_new_number(protocol, handle));
	set_member(request, "key", protocol_string(key));
	if (strcmp(op, "set") == 0 && args->len > 3)
		set_member(request, "value", encode(g_ptr_array_index(args, 3)));
	if (strcmp(op, "call") == 0) {
		GPtrArray *encoded = g_ptr_array_new_with_free_func(g_object_unref);
		JSCValue *list = args->len > 3 ? g_ptr_array_index(args, 3) : NULL;
		gint64 count = 0;
		if (list != NULL && jsc_value_is_array(list)) {
			JSCValue *length = jsc_value_object_get_property(list, "length");
			count = (gint64)jsc_value_to_double(length);
			g_object_unref(length);
		}
		for (gint64 i = 0; i < count; i++) {
			JSCValue *item = jsc_value_object_get_property_at_index(list, (guint)i);
			g_ptr_array_add(encoded, encode(item));
			g_object_unref(item);
		}
		set_member(request, "args", jsc_value_new_array_from_garray(protocol, encoded));
		g_ptr_array_unref(encoded);
	}
	JSCValue *reply = send_request(request);
	g_object_unref(request);
	JSCValue *result = decode(reply, context);
	g_clear_object(&reply);
	g_free(op);
	g_free(key);
	return result;
}

/* Pages */

static void on_window_object_cleared(WebKitScriptWorld *world, WebKitWebPage *page, WebKitFrame *frame, gpointer data)
{
	if (!bridge_connect())
		return;
	JSCContext *context = webkit_frame_get_js_context_for_script_world(frame, world);
	JSCValue *native = jsc_value_new_function_variadic(context, "native", G_CALLBACK(native_call), NULL, NULL, JSC_TYPE_VALUE);
	JSCValue *factory = jsc_context_evaluate(context, bootstrap, -1);
	JSCValue *done = jsc_value_function_call(factory, JSC_TYPE_VALUE, native, G_TYPE_NONE);
	if (jsc_context_get_exception(context) != NULL) {
		g_warning("darling-webhost-extension: bootstrap failed: %s", jsc_exception_get_message(jsc_context_get_exception(context)));
		jsc_context_clear_exception(context);
	}
	g_clear_object(&done);
	g_clear_object(&factory);
	g_clear_object(&native);

	JSCValue *window = jsc_context_get_global_object(context);
	JSCValue *request = jsc_value_new_object(protocol, NULL, NULL);
	set_member(request, "op", protocol_string("clear"));
	set_member(request, "page", jsc_value_new_number(protocol, webkit_web_page_get_id(page)));
	set_member(request, "main", jsc_value_new_boolean(protocol, webkit_frame_is_main_frame(frame)));
	set_member(request, "window", encode(window));
	JSCValue *reply = send_request(request);
	g_clear_object(&reply);
	g_object_unref(request);
	g_object_unref(window);
	g_object_unref(context);
}

G_MODULE_EXPORT void webkit_web_extension_initialize_with_user_data(WebKitWebExtension *web_extension, GVariant *user_data)
{
	extension = web_extension;
	if (user_data != NULL && g_variant_is_of_type(user_data, G_VARIANT_TYPE_UINT16))
		bridge_port = g_variant_get_uint16(user_data);
	read_buffer = g_string_new(NULL);
	stashed_replies = g_hash_table_new_full(g_int64_hash, g_int64_equal, g_free, g_object_unref);
	handles = g_ptr_array_new_with_free_func(g_object_unref);
	protocol = jsc_context_new();
	debug = g_getenv("DARLING_WEBHOST_DEBUG") != NULL;
	if (debug)
		g_message("darling-webhost-extension: loaded, app bridge on port %u", bridge_port);
	g_signal_connect(webkit_script_world_get_default(), "window-object-cleared", G_CALLBACK(on_window_object_cleared), NULL);
}
