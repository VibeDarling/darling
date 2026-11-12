/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * darling-webhost: the web engine behind Darling's iOS WebKit (UIWebView).
 * A Linux program, run beside Darling on the same X display.  Each Darling
 * app connects over TCP (127.0.0.1:7690, or DARLING_WEBHOST_PORT) and asks
 * for web views; each is a WebKitGTK view in an undecorated window that is
 * reparented into the app's X11 window over its UIWebView.  The app's
 * scripts reach the pages through the web process extension
 * (darling-webhost-extension.so), which connects back to the app.  The
 * protocol is in docs/darling-webhost.md.
 */

#include <gtk/gtk.h>
#include <gtk/gtkx.h>
#include <gdk/gdkx.h>
#include <webkit2/webkit2.h>
#include <json-glib/json-glib.h>
#include <X11/Xlib.h>
#include <gio/gio.h>
#include <string.h>
#include <stdlib.h>
#include <netinet/in.h>

typedef struct App App;

typedef struct {
	App *app;
	gint64 id;
	Window container;      /* ours: the window we move into the app's */
	gulong container_parent;
	GtkWidget *window;     /* a GtkPlug in the container */
	WebKitWebView *view;
	gulong parent;
	gboolean visible;
	int x, y, w, h;
} View;

struct App {
	GSocketConnection *connection;
	GOutputStream *output;
	GDataInputStream *input;
	GCancellable *cancellable;
	WebKitWebContext *context;
	guint16 bridge;
	GHashTable *views;     /* id -> View */
	GHashTable *requests;  /* id -> pending WebKitPolicyDecision / WebKitURISchemeRequest */
	gint64 next_request;
	GHashTable *schemes;
};

static char *extension_directory;
static gboolean debug;

/* Messages */

/* A message as a JSON object, or NULL.  (JSON is json-glib's here: a
 * JavaScriptCore context in this process stops WebKit loading pages.) */
static JsonObject *parse_json(const char *line)
{
	JsonParser *parser = json_parser_new();
	GError *error = NULL;
	JsonObject *object = NULL;
	if (!json_parser_load_from_data(parser, line, -1, &error)) {
		g_warning("darling-webhost: bad message: %s", error->message);
		g_error_free(error);
	} else {
		JsonNode *root = json_parser_get_root(parser);
		if (root != NULL && JSON_NODE_HOLDS_OBJECT(root))
			object = json_object_ref(json_node_get_object(root));
	}
	g_object_unref(parser);
	return object;
}

static char *member_string(JsonObject *object, const char *name)
{
	JsonNode *node = json_object_get_member(object, name);
	if (node == NULL || !JSON_NODE_HOLDS_VALUE(node) || json_node_get_value_type(node) != G_TYPE_STRING)
		return NULL;
	return g_strdup(json_node_get_string(node));
}

static gint64 member_int(JsonObject *object, const char *name)
{
	JsonNode *node = json_object_get_member(object, name);
	if (node == NULL || !JSON_NODE_HOLDS_VALUE(node))
		return 0;
	GType type = json_node_get_value_type(node);
	if (type == G_TYPE_INT64)
		return json_node_get_int(node);
	if (type == G_TYPE_DOUBLE)
		return (gint64)json_node_get_double(node);
	return 0;
}

static gboolean member_bool(JsonObject *object, const char *name)
{
	JsonNode *node = json_object_get_member(object, name);
	return node != NULL && JSON_NODE_HOLDS_VALUE(node) && json_node_get_value_type(node) == G_TYPE_BOOLEAN && json_node_get_boolean(node);
}

static void send_value(App *app, JsonObject *object)
{
	if (app->output == NULL)
		return;
	JsonNode *node = json_node_alloc();
	json_node_init_object(node, object);
	char *json = json_to_string(node, FALSE);
	json_node_unref(node);
	if (debug)
		g_message("<app %s", json);
	GString *line = g_string_new(json);
	g_string_append_c(line, '\n');
	GError *error = NULL;
	if (!g_output_stream_write_all(app->output, line->str, line->len, NULL, NULL, &error)) {
		g_warning("darling-webhost: write failed: %s", error->message);
		g_error_free(error);
	}
	g_string_free(line, TRUE);
	g_free(json);
}

static JsonObject *new_event(const char *name, View *view)
{
	JsonObject *event = json_object_new();
	json_object_set_string_member(event, "ev", name);
	if (view != NULL) {
		json_object_set_int_member(event, "view", view->id);
		json_object_set_boolean_member(event, "back", webkit_web_view_can_go_back(view->view));
		json_object_set_boolean_member(event, "forward", webkit_web_view_can_go_forward(view->view));
	}
	return event;
}

static void set_string(JsonObject *object, const char *name, const char *string)
{
	if (string != NULL)
		json_object_set_string_member(object, name, string);
	else
		json_object_set_null_member(object, name);
}

static void set_number(JsonObject *object, const char *name, double number)
{
	if (number == (gint64)number)
		json_object_set_int_member(object, name, (gint64)number);
	else
		json_object_set_double_member(object, name, number);
}

static void set_bool(JsonObject *object, const char *name, gboolean flag)
{
	json_object_set_boolean_member(object, name, flag);
}

static void send_simple_event(View *view, const char *name, const char *key, const char *string)
{
	JsonObject *event = new_event(name, view);
	if (key != NULL)
		set_string(event, key, string);
	send_value(view->app, event);
	json_object_unref(event);
}

/* Placement */

static Display *x_display(void)
{
	return GDK_DISPLAY_XDISPLAY(gdk_display_get_default());
}

static Window plug_window(View *view)
{
	GdkWindow *gdk_window = gtk_widget_get_window(view->window);
	return gdk_window != NULL ? gdk_x11_window_get_xid(gdk_window) : None;
}

/* Puts the view inside the app's window at the requested rect.  GTK only
 * ever sees a plug in our own container window; the container is what moves
 * between windows, so GTK's idea of the plug stays true. */
static void place(View *view)
{
	Display *display = x_display();
	if (!view->visible || view->parent == 0 || view->w <= 0 || view->h <= 0) {
		XUnmapWindow(display, view->container);
		XFlush(display);
		return;
	}
	if (view->container_parent != view->parent) {
		XReparentWindow(display, view->container, view->parent, view->x, view->y);
		view->container_parent = view->parent;
	}
	XMoveResizeWindow(display, view->container, view->x, view->y, view->w, view->h);
	Window plug = plug_window(view);
	if (plug != None) {
		XMoveResizeWindow(display, plug, 0, 0, view->w, view->h);
		XMapWindow(display, plug);
	}
	XMapRaised(display, view->container);
	XSync(display, False);
	if (debug) {
		XWindowAttributes attributes;
		XGetWindowAttributes(display, view->container, &attributes);
		g_message("darling-webhost: view %" G_GINT64_FORMAT " at %d,%d %dx%d in 0x%lx, %s", view->id, attributes.x, attributes.y,
		          attributes.width, attributes.height, view->parent, attributes.map_state == IsViewable ? "viewable" : "not viewable");
	}
}

/* Apps draw through windows of their own (Cocotron's OpenGL surface is a
 * child of the app's window, made on first draw), which can end up above
 * ours.  Keep each shown view the topmost child of its parent. */
static GList *all_apps;

static void keep_on_top(gpointer key, gpointer value, gpointer data)
{
	View *view = value;
	if (!view->visible || view->parent == 0)
		return;
	Display *display = x_display();
	Window xid = view->container;
	Window root, parent, *children = NULL;
	unsigned count = 0;
	if (!XQueryTree(display, view->parent, &root, &parent, &children, &count))
		return;
	gboolean ours = FALSE, on_top = count > 0 && children[count - 1] == xid;
	for (unsigned i = 0; i < count; i++)
		if (children[i] == xid)
			ours = TRUE;
	if (children != NULL)
		XFree(children);
	if (!ours) {
		/* Not inside the app's window any more: put it back. */
		view->container_parent = 0;
		place(view);
	} else if (!on_top) {
		if (debug)
			g_message("darling-webhost: raising view %" G_GINT64_FORMAT " over the app's own windows", view->id);
		XRaiseWindow(display, xid);
		XFlush(display);
	}
}

static gboolean keep_views_on_top(gpointer data)
{
	for (GList *item = all_apps; item != NULL; item = item->next)
		g_hash_table_foreach(((App *)item->data)->views, keep_on_top, NULL);
	return G_SOURCE_CONTINUE;
}

/* There is no window manager inside the app's window: take the keyboard
 * when clicked. */
static gboolean on_button_press(GtkWidget *widget, GdkEventButton *event, View *view)
{
	Window plug = plug_window(view);
	if (plug != None)
		XSetInputFocus(x_display(), plug, RevertToParent, CurrentTime);
	return FALSE;
}

/* WebKit callbacks */

static gint64 remember_request(App *app, GObject *request)
{
	gint64 id = ++app->next_request;
	g_hash_table_insert(app->requests, g_memdup2(&id, sizeof(id)), g_object_ref(request));
	return id;
}

static GObject *take_request(App *app, gint64 id)
{
	GObject *request = NULL;
	gpointer key = NULL;
	if (g_hash_table_lookup_extended(app->requests, &id, &key, (gpointer *)&request)) {
		g_hash_table_steal(app->requests, &id);
		g_free(key);
	}
	return request;
}

static const char *navigation_type(WebKitNavigationType type)
{
	switch (type) {
	case WEBKIT_NAVIGATION_TYPE_LINK_CLICKED: return "link";
	case WEBKIT_NAVIGATION_TYPE_FORM_SUBMITTED: return "form";
	case WEBKIT_NAVIGATION_TYPE_BACK_FORWARD: return "back";
	case WEBKIT_NAVIGATION_TYPE_RELOAD: return "reload";
	case WEBKIT_NAVIGATION_TYPE_FORM_RESUBMITTED: return "resubmit";
	default: return "other";
	}
}

static gboolean on_decide_policy(WebKitWebView *web_view, WebKitPolicyDecision *decision, WebKitPolicyDecisionType type, View *view)
{
	if (type == WEBKIT_POLICY_DECISION_TYPE_RESPONSE)
		return FALSE;
	WebKitNavigationAction *action = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
	WebKitURIRequest *request = webkit_navigation_action_get_request(action);
	const char *uri = webkit_uri_request_get_uri(request);
	/* The app's own loads of what it already decided need no second asking. */
	if (g_str_has_prefix(uri, "about:") || g_str_has_prefix(uri, "data:"))
		return FALSE;
	JsonObject *event = new_event("policy", view);
	set_number(event, "req", remember_request(view->app, G_OBJECT(decision)));
	set_string(event, "url", uri);
	set_string(event, "method", webkit_uri_request_get_http_method(request));
	set_string(event, "type", navigation_type(webkit_navigation_action_get_navigation_type(action)));
	if (type == WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) {
		g_object_set_data(G_OBJECT(decision), "darling-new-window", GINT_TO_POINTER(1));
		const char *frame = webkit_navigation_policy_decision_get_frame_name(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
		set_string(event, "target", frame != NULL ? frame : "_blank");
	} else {
		/* WebKitGTK does not say which frame; a frame name means a subframe. */
		const char *frame = webkit_navigation_policy_decision_get_frame_name(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
		set_bool(event, "main", frame == NULL || *frame == '\0');
	}
	send_value(view->app, event);
	json_object_unref(event);
	return TRUE;
}

static void on_load_changed(WebKitWebView *web_view, WebKitLoadEvent load_event, View *view)
{
	switch (load_event) {
	case WEBKIT_LOAD_STARTED:
		send_simple_event(view, "started", "url", webkit_web_view_get_uri(web_view));
		break;
	case WEBKIT_LOAD_COMMITTED: {
		JsonObject *event = new_event("committed", view);
		set_string(event, "url", webkit_web_view_get_uri(web_view));
		WebKitWebResource *resource = webkit_web_view_get_main_resource(web_view);
		WebKitURIResponse *response = resource != NULL ? webkit_web_resource_get_response(resource) : NULL;
		if (response != NULL)
			set_string(event, "mime", webkit_uri_response_get_mime_type(response));
		send_value(view->app, event);
		json_object_unref(event);
		break;
	}
	case WEBKIT_LOAD_FINISHED:
		send_simple_event(view, "finished", NULL, NULL);
		break;
	default:
		break;
	}
}

static gboolean on_load_failed(WebKitWebView *web_view, WebKitLoadEvent load_event, gchar *uri, GError *error, View *view)
{
	/* A load the app cancelled (by policy or a new load) is not a failure
	 * to report; WebKit1 stays quiet about those too. */
	if (g_error_matches(error, WEBKIT_NETWORK_ERROR, WEBKIT_NETWORK_ERROR_CANCELLED) ||
	    g_error_matches(error, WEBKIT_POLICY_ERROR, WEBKIT_POLICY_ERROR_FRAME_LOAD_INTERRUPTED_BY_POLICY_CHANGE))
		return TRUE;
	JsonObject *event = new_event("failed", view);
	set_string(event, "url", uri);
	set_string(event, "error", error->message);
	set_number(event, "code", error->code);
	set_bool(event, "provisional", load_event == WEBKIT_LOAD_STARTED);
	send_value(view->app, event);
	json_object_unref(event);
	return TRUE;
}

static void on_title(WebKitWebView *web_view, GParamSpec *pspec, View *view)
{
	send_simple_event(view, "title", "title", webkit_web_view_get_title(web_view));
}

static gboolean on_script_dialog(WebKitWebView *web_view, WebKitScriptDialog *dialog, View *view)
{
	switch (webkit_script_dialog_get_dialog_type(dialog)) {
	case WEBKIT_SCRIPT_DIALOG_ALERT:
		send_simple_event(view, "alert", "message", webkit_script_dialog_get_message(dialog));
		return TRUE;
	case WEBKIT_SCRIPT_DIALOG_CONFIRM:
	case WEBKIT_SCRIPT_DIALOG_BEFORE_UNLOAD_CONFIRM:
		webkit_script_dialog_confirm_set_confirmed(dialog, TRUE);
		return TRUE;
	case WEBKIT_SCRIPT_DIALOG_PROMPT:
		webkit_script_dialog_prompt_set_text(dialog, webkit_script_dialog_prompt_get_default_text(dialog));
		return TRUE;
	default:
		return FALSE;
	}
}

static void on_close(WebKitWebView *web_view, View *view)
{
	send_simple_event(view, "close", NULL, NULL);
}

static void on_scheme_request(WebKitURISchemeRequest *request, App *app)
{
	JsonObject *event = new_event("scheme", NULL);
	set_number(event, "req", remember_request(app, G_OBJECT(request)));
	set_string(event, "url", webkit_uri_scheme_request_get_uri(request));
	send_value(app, event);
	json_object_unref(event);
}

static void register_scheme(App *app, const char *scheme)
{
	if (scheme == NULL || g_hash_table_contains(app->schemes, scheme))
		return;
	static const char *const builtin[] = { "http", "https", "file", "about", "data", "blob", "javascript", "ftp", NULL };
	for (int i = 0; builtin[i] != NULL; i++)
		if (g_ascii_strcasecmp(scheme, builtin[i]) == 0)
			return;
	g_hash_table_add(app->schemes, g_strdup(scheme));
	webkit_web_context_register_uri_scheme(app->context, scheme, (WebKitURISchemeRequestCallback)on_scheme_request, app, NULL);
	/* An app's scheme acts like http for security purposes. */
	webkit_security_manager_register_uri_scheme_as_cors_enabled(webkit_web_context_get_security_manager(app->context), scheme);
}

/* Views */

static void destroy_view(gpointer data)
{
	View *view = data;
	if (view->window != NULL)
		gtk_widget_destroy(view->window);
	/* Gone already if the app's window went first; errors are trapped. */
	XDestroyWindow(x_display(), view->container);
	XFlush(x_display());
	g_free(view);
}

static void on_initialize_extensions(WebKitWebContext *context, App *app)
{
	webkit_web_context_set_web_extensions_directory(context, extension_directory);
	webkit_web_context_set_web_extensions_initialization_user_data(context, g_variant_new_uint16(app->bridge));
}

static WebKitWebContext *context_for(App *app)
{
	if (app->context == NULL) {
		app->context = webkit_web_context_new_ephemeral();
		g_signal_connect(app->context, "initialize-web-extensions", G_CALLBACK(on_initialize_extensions), app);
	}
	return app->context;
}

static View *create_view(App *app, gint64 id, const char *user_agent)
{
	View *view = g_new0(View, 1);
	view->app = app;
	view->id = id;
	Display *display = x_display();
	/* Override-redirect: Cocotron redirects its windows' substructure (it
	 * plays window manager for them), which would swallow our map and
	 * configure requests. */
	XSetWindowAttributes attributes = { 0 };
	attributes.override_redirect = True;
	attributes.background_pixel = WhitePixel(display, DefaultScreen(display));
	view->container = XCreateWindow(display, DefaultRootWindow(display), 0, 0, 1, 1, 0, CopyFromParent, InputOutput,
	                                CopyFromParent, CWOverrideRedirect | CWBackPixel, &attributes);
	XSelectInput(display, view->container, StructureNotifyMask);
	view->window = gtk_plug_new(view->container);
	view->view = WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW, "web-context", context_for(app), NULL));
	WebKitSettings *settings = webkit_web_view_get_settings(view->view);
	webkit_settings_set_javascript_can_open_windows_automatically(settings, TRUE);
	webkit_settings_set_enable_developer_extras(settings, FALSE);
	if (user_agent != NULL)
		webkit_settings_set_user_agent(settings, user_agent);
	gtk_container_add(GTK_CONTAINER(view->window), GTK_WIDGET(view->view));
	g_signal_connect(view->view, "decide-policy", G_CALLBACK(on_decide_policy), view);
	g_signal_connect(view->view, "load-changed", G_CALLBACK(on_load_changed), view);
	g_signal_connect(view->view, "load-failed", G_CALLBACK(on_load_failed), view);
	g_signal_connect(view->view, "notify::title", G_CALLBACK(on_title), view);
	g_signal_connect(view->view, "script-dialog", G_CALLBACK(on_script_dialog), view);
	g_signal_connect(view->view, "close", G_CALLBACK(on_close), view);
	g_signal_connect(view->view, "button-press-event", G_CALLBACK(on_button_press), view);
	gtk_widget_show_all(view->window);
	Window plug = plug_window(view);
	if (plug != None)
		XMapWindow(display, plug);
	XFlush(display);
	g_hash_table_insert(app->views, g_memdup2(&id, sizeof(id)), view);

	JsonObject *event = new_event("created", view);
	set_number(event, "page", webkit_web_view_get_page_id(view->view));
	send_value(app, event);
	json_object_unref(event);
	return view;
}

static View *lookup_view(App *app, JsonObject *message)
{
	gint64 id = member_int(message, "view");
	return g_hash_table_lookup(app->views, &id);
}

/* Requests from the app */

static void handle_message(App *app, JsonObject *message)
{
	char *op = member_string(message, "op");
	if (op == NULL)
		return;
	View *view = lookup_view(app, message);

	if (strcmp(op, "hello") == 0) {
		app->bridge = (guint16)member_int(message, "bridge");
		g_message("darling-webhost: app %" G_GINT64_FORMAT " connected, bridge port %u", member_int(message, "pid"), app->bridge);
		context_for(app);
		JsonNode *schemes = json_object_get_member(message, "schemes");
		if (schemes != NULL && JSON_NODE_HOLDS_ARRAY(schemes)) {
			JsonArray *array = json_node_get_array(schemes);
			for (guint i = 0; i < json_array_get_length(array); i++) {
				const char *scheme = json_array_get_string_element(array, i);
				register_scheme(app, scheme);
			}
		}
	} else if (strcmp(op, "scheme-register") == 0) {
		char *scheme = member_string(message, "scheme");
		register_scheme(app, scheme);
		g_free(scheme);
	} else if (strcmp(op, "create") == 0) {
		char *user_agent = member_string(message, "ua");
		if (view == NULL)
			create_view(app, member_int(message, "view"), user_agent);
		g_free(user_agent);
	} else if (strcmp(op, "settings") == 0 && view != NULL) {
		char *user_agent = member_string(message, "ua");
		if (user_agent != NULL)
			webkit_settings_set_user_agent(webkit_web_view_get_settings(view->view), user_agent);
		g_free(user_agent);
	} else if (strcmp(op, "embed") == 0 && view != NULL) {
		view->parent = (gulong)member_int(message, "parent");
		view->x = (int)member_int(message, "x");
		view->y = (int)member_int(message, "y");
		view->w = (int)member_int(message, "w");
		view->h = (int)member_int(message, "h");
		view->visible = member_bool(message, "visible");
		place(view);
	} else if (strcmp(op, "load") == 0 && view != NULL) {
		char *url = member_string(message, "url");
		char *scheme = url != NULL ? g_uri_parse_scheme(url) : NULL;
		register_scheme(app, scheme);
		if (url != NULL)
			webkit_web_view_load_uri(view->view, url);
		g_free(scheme);
		g_free(url);
	} else if (strcmp(op, "loadHTML") == 0 && view != NULL) {
		char *html = member_string(message, "html");
		char *base = member_string(message, "base");
		webkit_web_view_load_html(view->view, html != NULL ? html : "", base);
		g_free(html);
		g_free(base);
	} else if (strcmp(op, "loadData") == 0 && view != NULL) {
		char *data = member_string(message, "data");
		char *mime = member_string(message, "mime");
		char *encoding = member_string(message, "encoding");
		char *base = member_string(message, "base");
		gsize length = 0;
		guchar *bytes = g_base64_decode(data != NULL ? data : "", &length);
		GBytes *gbytes = g_bytes_new_take(bytes, length);
		webkit_web_view_load_bytes(view->view, gbytes, mime, encoding, base);
		g_bytes_unref(gbytes);
		g_free(data);
		g_free(mime);
		g_free(encoding);
		g_free(base);
	} else if (strcmp(op, "reload") == 0 && view != NULL) {
		if (member_bool(message, "origin"))
			webkit_web_view_reload_bypass_cache(view->view);
		else
			webkit_web_view_reload(view->view);
	} else if (strcmp(op, "stop") == 0 && view != NULL) {
		webkit_web_view_stop_loading(view->view);
	} else if (strcmp(op, "back") == 0 && view != NULL) {
		webkit_web_view_go_back(view->view);
	} else if (strcmp(op, "forward") == 0 && view != NULL) {
		webkit_web_view_go_forward(view->view);
	} else if (strcmp(op, "destroy") == 0 && view != NULL) {
		gint64 id = view->id;
		g_hash_table_remove(app->views, &id);
	} else if (strcmp(op, "policy") == 0) {
		GObject *request = take_request(app, member_int(message, "req"));
		if (request != NULL && WEBKIT_IS_POLICY_DECISION(request)) {
			WebKitPolicyDecision *decision = WEBKIT_POLICY_DECISION(request);
			gboolean use = member_bool(message, "use");
			if (use && g_object_get_data(request, "darling-new-window") != NULL) {
				/* No new windows: open it in the same view, as Cydia expects. */
				WebKitURIRequest *uri_request = webkit_navigation_action_get_request(webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(decision)));
				webkit_policy_decision_ignore(decision);
				if (view != NULL)
					webkit_web_view_load_request(view->view, uri_request);
			} else if (use) {
				webkit_policy_decision_use(decision);
			} else {
				webkit_policy_decision_ignore(decision);
			}
		}
		g_clear_object(&request);
	} else if (strcmp(op, "scheme") == 0) {
		GObject *request = take_request(app, member_int(message, "req"));
		if (request != NULL && WEBKIT_IS_URI_SCHEME_REQUEST(request)) {
			char *error = member_string(message, "error");
			if (error != NULL) {
				GError *gerror = g_error_new_literal(G_IO_ERROR, G_IO_ERROR_FAILED, error);
				webkit_uri_scheme_request_finish_error(WEBKIT_URI_SCHEME_REQUEST(request), gerror);
				g_error_free(gerror);
			} else {
				char *data = member_string(message, "data");
				char *mime = member_string(message, "mime");
				gsize length = 0;
				guchar *bytes = g_base64_decode(data != NULL ? data : "", &length);
				GInputStream *stream = g_memory_input_stream_new_from_data(bytes, length, g_free);
				WebKitURISchemeResponse *response = webkit_uri_scheme_response_new(stream, length);
				webkit_uri_scheme_response_set_content_type(response, mime != NULL ? mime : "application/octet-stream");
				webkit_uri_scheme_response_set_status(response, (guint)(member_int(message, "status") ?: 200), NULL);
				webkit_uri_scheme_request_finish_with_response(WEBKIT_URI_SCHEME_REQUEST(request), response);
				g_object_unref(response);
				g_object_unref(stream);
				g_free(data);
				g_free(mime);
			}
			g_free(error);
		}
		g_clear_object(&request);
	} else {
		g_debug("darling-webhost: ignoring %s", op);
	}
	g_free(op);
}

/* Connections */

static void app_free(App *app)
{
	all_apps = g_list_remove(all_apps, app);
	g_cancellable_cancel(app->cancellable);
	g_hash_table_destroy(app->views);
	g_hash_table_destroy(app->requests);
	g_hash_table_destroy(app->schemes);
	g_clear_object(&app->input);
	app->output = NULL;
	g_clear_object(&app->connection);
	g_clear_object(&app->cancellable);
	/* Kept: WebKit holds on to contexts with registered schemes. */
	app->context = NULL;
	g_free(app);
}

static void read_line(App *app);

static void on_line(GObject *source, GAsyncResult *result, gpointer data)
{
	App *app = data;
	GError *error = NULL;
	gsize length = 0;
	char *line = g_data_input_stream_read_line_finish_utf8(G_DATA_INPUT_STREAM(source), result, &length, &error);
	if (line == NULL) {
		if (error != NULL && !g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED))
			g_message("darling-webhost: app disconnected: %s", error->message);
		else if (error == NULL)
			g_message("darling-webhost: app disconnected");
		g_clear_error(&error);
		app_free(app);
		return;
	}
	if (debug)
		g_message("app> %s", line);
	JsonObject *message = parse_json(line);
	if (message != NULL)
		handle_message(app, message);
	if (message != NULL)
		json_object_unref(message);
	g_free(line);
	read_line(app);
}

static void read_line(App *app)
{
	g_data_input_stream_read_line_async(app->input, G_PRIORITY_DEFAULT, app->cancellable, on_line, app);
}

static gboolean on_incoming(GSocketService *service, GSocketConnection *connection, GObject *source, gpointer data)
{
	App *app = g_new0(App, 1);
	app->connection = g_object_ref(connection);
	app->output = g_io_stream_get_output_stream(G_IO_STREAM(connection));
	app->input = g_data_input_stream_new(g_io_stream_get_input_stream(G_IO_STREAM(connection)));
	g_data_input_stream_set_newline_type(app->input, G_DATA_STREAM_NEWLINE_TYPE_LF);
	app->cancellable = g_cancellable_new();
	app->views = g_hash_table_new_full(g_int64_hash, g_int64_equal, g_free, destroy_view);
	app->requests = g_hash_table_new_full(g_int64_hash, g_int64_equal, g_free, g_object_unref);
	app->schemes = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
	GSocket *socket = g_socket_connection_get_socket(connection);
	g_socket_set_option(socket, IPPROTO_TCP, 1 /* TCP_NODELAY */, 1, NULL);
	all_apps = g_list_prepend(all_apps, app);
	read_line(app);
	return TRUE;
}

static int on_x_error(Display *display, XErrorEvent *event)
{
	if (debug) {
		char text[128];
		XGetErrorText(display, event->error_code, text, sizeof(text));
		g_message("darling-webhost: X error %s (request %d) on 0x%lx", text, event->request_code, event->resourceid);
	}
	return 0;
}

int main(int argc, char *argv[])
{
	/* Software rendering: no GPU path into a reparented window over X. */
	g_setenv("WEBKIT_DISABLE_COMPOSITING_MODE", "1", FALSE);
	g_setenv("WEBKIT_DISABLE_DMABUF_RENDERER", "1", FALSE);
	gdk_set_allowed_backends("x11");
	gtk_init(&argc, &argv);
	debug = g_getenv("DARLING_WEBHOST_DEBUG") != NULL;
	/* Our windows live inside the apps' windows and vanish with them; the
	 * errors that follow are expected, not fatal. */
	XSetErrorHandler(on_x_error);

	extension_directory = g_strdup(g_getenv("DARLING_WEBHOST_EXTENSIONS"));
	if (extension_directory == NULL) {
		char *self = g_file_read_link("/proc/self/exe", NULL);
		extension_directory = self != NULL ? g_path_get_dirname(self) : g_strdup(".");
		g_free(self);
	}

	const char *port_spec = g_getenv("DARLING_WEBHOST_PORT");
	guint16 port = port_spec != NULL ? (guint16)atoi(port_spec) : 7690;
	GSocketService *service = g_socket_service_new();
	GInetAddress *loopback = g_inet_address_new_loopback(G_SOCKET_FAMILY_IPV4);
	GSocketAddress *address = g_inet_socket_address_new(loopback, port);
	GError *error = NULL;
	if (!g_socket_listener_add_address(G_SOCKET_LISTENER(service), address, G_SOCKET_TYPE_STREAM, G_SOCKET_PROTOCOL_TCP, NULL, NULL, &error)) {
		g_printerr("darling-webhost: cannot listen on 127.0.0.1:%u: %s\n", port, error->message);
		return 1;
	}
	g_signal_connect(service, "incoming", G_CALLBACK(on_incoming), NULL);
	g_socket_service_start(service);
	g_timeout_add(300, keep_views_on_top, NULL);
	g_message("darling-webhost: listening on 127.0.0.1:%u, extensions in %s", port, extension_directory);
	gtk_main();
	return 0;
}
