/* Portable guest-side transport. See dwb_client.h for why it is free of AppKit. */
#include "dwb_client.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

static int send_all(int fd, const void *buf, size_t len)
{
	const unsigned char *p = buf;
	while (len) {
		ssize_t n = write(fd, p, len);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		p += n;
		len -= (size_t)n;
	}
	return 0;
}

static int recv_all(int fd, void *buf, size_t len)
{
	unsigned char *p = buf;
	while (len) {
		ssize_t n = read(fd, p, len);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		if (n == 0)
			return -1;
		p += n;
		len -= (size_t)n;
	}
	return 0;
}

static int send_msg(dwb_client *c, uint16_t type, const void *payload, uint32_t len)
{
	dwb_header h = { .magic = DWB_MAGIC, .version = DWB_PROTO_VERSION,
	                 .type = type, .length = len };
	if (send_all(c->fd, &h, sizeof(h)) != 0)
		return -1;
	if (len && send_all(c->fd, payload, len) != 0)
		return -1;
	return 0;
}

static int recv_msg(dwb_client *c, dwb_header *h, char *payload, size_t cap)
{
	if (recv_all(c->fd, h, sizeof(*h)) != 0)
		return -1;
	if (h->magic != DWB_MAGIC || h->version != DWB_PROTO_VERSION)
		return -1;
	/* Strictly less than cap, not at most: the terminator below writes
	 * payload[h->length], so a payload of exactly cap bytes would write one
	 * past the end of a cap-byte buffer. */
	if (h->length >= cap)
		return -1;
	if (h->length && recv_all(c->fd, payload, h->length) != 0)
		return -1;
	payload[h->length] = '\0';
	return 0;
}

/* Extracts a flat JSON string value. Good enough for the host's replies, which
 * are all flat objects of strings and integers. */
/* Value of a string field, decoded.
 *
 * Every string the host puts on the wire is escaped, so every read has to
 * resolve escapes. This was the naive "up to the next quote" version, and it is
 * kept as the single entry point rather than leaving some call sites decoded and
 * some not - a mix is how a body arrives intact in one test and truncated in
 * another. */
static char *json_decoded_str(const char *json, const char *key);

static char *json_str(const char *json, const char *key)
{
	return json_decoded_str(json, key);
}

static int json_int(const char *json, const char *key, int *out)
{
	char pat[64];
	snprintf(pat, sizeof(pat), "\"%s\":", key);
	const char *at = strstr(json, pat);
	if (!at)
		return -1;
	at += strlen(pat);
	if (*at < '0' || *at > '9')
		return -1;
	*out = (int)strtol(at, NULL, 10);
	return 0;
}

int dwb_client_connect(dwb_client *c, const char *socket_path)
{
	/* No error clear here: the memset below discards the whole struct, previous
	 * error included, so anything written before it would be thrown away. */
	memset(c, 0, sizeof(*c));
	c->fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (c->fd < 0)
		return -1;
	struct sockaddr_un addr = { .sun_family = AF_UNIX };
	if (socket_path == NULL || socket_path[0] == '\0') {
		close(c->fd);
		c->fd = -1;
		strncpy(c->error, "no socket path given", sizeof(c->error) - 1);
		return -1;
	}
	/* sun_path is a fixed 108 bytes. A longer path is not a path this transport
	 * can ever use, and silently truncating it connects to the wrong socket or
	 * fails with no explanation. Say which. */
	if (strlen(socket_path) >= sizeof(addr.sun_path)) {
		close(c->fd);
		c->fd = -1;
		snprintf(c->error, sizeof(c->error),
		         "socket path too long (%zu bytes, max %zu): %s",
		         strlen(socket_path), sizeof(addr.sun_path) - 1, socket_path);
		return -1;
	}
	strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);
	if (connect(c->fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
		close(c->fd);
		c->fd = -1;
		return -1;
	}
	return 0;
}

void dwb_client_close(dwb_client *c)
{
	/* The error is deliberately left alone: this is how a caller finds out why
	 * a connection died, and clearing it on the way out would erase the only
	 * record. */

	if (c->fd >= 0)
		close(c->fd);
	c->fd = -1;
}

int dwb_client_hello(dwb_client *c, char **backend_name, int *width, int *height)
{
	c->error[0] = '\0';

	char buf[4096];
	if (send_msg(c, DWB_MSG_HELLO, "{\"proto\":1}", 11) != 0)
		return -1;
	dwb_header h;
	if (recv_msg(c, &h, buf, sizeof(buf)) != 0 || h.type != DWB_MSG_HELLO_ACK)
		return -1;
	if (backend_name)
		*backend_name = json_str(buf, "backend");
	if (width)
		json_int(buf, "width", width);
	if (height)
		json_int(buf, "height", height);
	return 0;
}

static char *json_escape(const char *in, size_t out_bytes);

/* {"k":"v"} with v escaped. Returns the length, or -1 if it will not fit. */
static int json_pair(char *out, size_t out_sz, const char *key, const char *value)
{
	char *escaped = json_escape(value, out_sz - 32);
	if (escaped == NULL)
		return -1;
	int n = snprintf(out, out_sz, "{\"%s\":\"%s\"}", key, escaped);
	free(escaped);
	return (n < 0 || (size_t)n >= out_sz) ? -1 : n;
}

/* A JSON integer field, or 0 if absent. Absent is not an error: the host omits
 * status for a backend that does not report one. */
static int json_int_value(const char *json, const char *key)
{
	char pat[64];
	snprintf(pat, sizeof(pat), "\"%s\":", key);
	const char *at = strstr(json, pat);
	if (!at)
		return 0;
	at += strlen(pat);
	char *endp = NULL;
	long v = strtol(at, &endp, 10);
	return (endp && endp != at) ? (int)v : 0;
}

int dwb_client_navigate(dwb_client *c, const char *url)
{
	c->error[0] = '\0';
	/* A previous response is not kept across navigations: the caller that wants
	 * one takes ownership through dwb_client_navigate_info, and anything still
	 * here belongs to nobody. */
	free(c->last_url);
	free(c->last_mime);
	c->last_url = NULL;
	c->last_mime = NULL;
	c->last_status = 0;

	/* A URL can carry a quote in a query string, and it is read back by the
	 * same decoder that truncated scripts, so it is escaped for the same reason. */
	char msg[65536];
	int n = json_pair(msg, sizeof(msg), "url", url);
	if (n < 0) {
		strncpy(c->error, "url too long to send", sizeof(c->error) - 1);
		return -1;
	}
	if (n < 0 || (size_t)n >= sizeof(msg))
		return -1;
	if (send_msg(c, DWB_MSG_NAVIGATE, msg, (uint32_t)n) != 0)
		return -1;
	char buf[4096];
	dwb_header h;
	if (recv_msg(c, &h, buf, sizeof(buf)) != 0)
		return -1;
	if (h.type != DWB_MSG_EVENT) {
		snprintf(c->error, sizeof(c->error), "unexpected reply %u", h.type);
		return -1;
	}
	/* The host reports load-finished, or an error carrying the reason. An
	 * unknown URL must not look like success. */
	if (strstr(buf, "\"name\":\"error\"")) {
		char *detail = json_str(buf, "detail");
		snprintf(c->error, sizeof(c->error), "%s", detail ? detail : "navigation failed");
		free(detail);
		c->had_error = 1;
		return -1;
	}
	if (!strstr(buf, "load-finished")) {
		snprintf(c->error, sizeof(c->error), "unexpected event: %s", buf);
		return -1;
	}
	c->had_error = 0;
	/* An empty field is normalised to NULL. A backend that reports nothing
	 * sends "" rather than omitting the key, and "" is indistinguishable from a
	 * real empty value unless something normalises it. The guest needs the
	 * difference: it treats a missing response as "unknown" and must not treat
	 * an empty string as a response it can hand a delegate. */
	{
		char *u = json_decoded_str(buf, "url");
		char *m = json_decoded_str(buf, "mime");
		c->last_url = (u && *u) ? u : (u ? (free(u), (char *)NULL) : NULL);
		c->last_mime = (m && *m) ? m : (m ? (free(m), (char *)NULL) : NULL);
	}
	c->last_status = json_int_value(buf, "status");
	return 0;
}

int dwb_client_navigate_info(dwb_client *c, const char *url, dwb_load_info *info)
{
	if (dwb_client_navigate(c, url) != 0)
		return -1;
	if (info) {
		info->url = c->last_url;
		info->mime = c->last_mime;
		info->status = c->last_status;
		/* Ownership moves to the caller. A second navigate frees the previous
		 * values first, so this cannot leak or double-free either way. */
		c->last_url = NULL;
		c->last_mime = NULL;
		c->last_status = 0;
	}
	return 0;
}

int dwb_client_resize(dwb_client *c, int width, int height)
{
	c->error[0] = '\0';

	char msg[128];
	int n = snprintf(msg, sizeof(msg), "{\"w\":%d,\"h\":%d}", width, height);
	return send_msg(c, DWB_MSG_RESIZE, msg, (uint32_t)n);
}

/* Escapes a UTF-8 string for embedding inside a JSON string literal, returning
 * a malloc'd copy. Returns NULL if the input would not fit, so the caller can
 * refuse rather than truncate a script in half.
 *
 * This is the fix for a bug the app hits on its very first message. Scripts were
 * interpolated raw with snprintf, so a script containing a double quote - which
 * any script containing JSON does - produced malformed JSON and the host
 * reported a syntax error at the end of the truncated document rather than the
 * real problem. YouLearn's own injected script posts a JSON body, so its very
 * first postMessage could never arrive:
 *
 *     post error: https://example.com/:1: SyntaxError: Unexpected EOF
 *
 * which reads like a JavaScript error in the page and is nothing of the sort. */
static char *json_escape(const char *in, size_t out_bytes)
{
	if (in == NULL)
		return NULL;
	size_t worst = 0;
	for (const unsigned char *p = (const unsigned char *)in; *p; p++)
		worst += (*p == '"' || *p == '\\' || *p < 0x20) ? 6 : 1;
	worst++; /* NUL */
	if (worst > out_bytes)
		return NULL;
	char *out = malloc(worst);
	if (out == NULL)
		return NULL;
	char *w = out;
	for (const unsigned char *p = (const unsigned char *)in; *p; p++) {
		switch (*p) {
		case '"':  memcpy(w, "\\\"", 2); w += 2; break;
		case '\\': memcpy(w, "\\\\", 2); w += 2; break;
		case '\n': memcpy(w, "\\n", 2); w += 2; break;
		case '\r': memcpy(w, "\\r", 2); w += 2; break;
		case '\t': memcpy(w, "\\t", 2); w += 2; break;
		case '\b': memcpy(w, "\\b", 2); w += 2; break;
		case '\f': memcpy(w, "\\f", 2); w += 2; break;
		default:
			if (*p < 0x20) {
				w += sprintf(w, "\\u%04x", *p);
			} else {
				*w++ = (char)*p;
			}
			break;
		}
	}
	*w = '\0';
	return out;
}


int dwb_client_eval(dwb_client *c, const char *js, char **value)
{
	c->error[0] = '\0';

	char msg[262144];
	char *escaped = json_escape(js, sizeof(msg) - 32);
	if (escaped == NULL) {
		strncpy(c->error, "script too large to send", sizeof(c->error) - 1);
		return -1;
	}
	int n = snprintf(msg, sizeof(msg), "{\"js\":\"%s\"}", escaped);
	free(escaped);
	if (n < 0 || (size_t)n >= sizeof(msg)) {
		strncpy(c->error, "script too large to send", sizeof(c->error) - 1);
		return -1;
	}
	if (send_msg(c, DWB_MSG_EVAL, msg, (uint32_t)n) != 0)
		return -1;
	char buf[65536];
	dwb_header h;
	if (recv_msg(c, &h, buf, sizeof(buf)) != 0 || h.type != DWB_MSG_EVAL_RESULT)
		return -1;
	if (strstr(buf, "\"error\"")) {
		char *e = json_str(buf, "error");
		snprintf(c->error, sizeof(c->error), "%s", e ? e : "eval failed");
		free(e);
		return -1;
	}
	if (value)
		*value = json_decoded_str(buf, "value");
	return 0;
}

int dwb_client_attach_shm(dwb_client *c, const char *path, size_t bytes)
{
	c->error[0] = '\0';

	char msg[4096];
	char *ppath = json_escape(path, sizeof(msg) - 64);
	if (ppath == NULL) {
		strncpy(c->error, "socket path too long to send", sizeof(c->error) - 1);
		return -1;
	}
	int n = snprintf(msg, sizeof(msg), "{\"path\":\"%s\",\"size\":%zu}", ppath, bytes);
	free(ppath);
	if (n < 0 || (size_t)n >= sizeof(msg)) {
		strncpy(c->error, "socket path too long to send", sizeof(c->error) - 1);
		return -1;
	}
	if (send_msg(c, DWB_MSG_SHM_ATTACH, msg, (uint32_t)n) != 0)
		return -1;
	char buf[1024];
	dwb_header h;
	if (recv_msg(c, &h, buf, sizeof(buf)) != 0)
		return -1;
	if (strstr(buf, "shm-attached"))
		return 0;
	char *detail = json_str(buf, "detail");
	snprintf(c->error, sizeof(c->error), "shm attach refused: %s",
	         detail ? detail : "unknown");
	free(detail);
	return -1;
}

int dwb_client_add_script(dwb_client *c, const char *js, int at_document_start,
                          int main_only)
{
	c->error[0] = '\0';
	char msg[262144];
	char *escaped = json_escape(js, sizeof(msg) - 64);
	if (escaped == NULL) {
		strncpy(c->error, "script too large to send", sizeof(c->error) - 1);
		return -1;
	}
	int n = snprintf(msg, sizeof(msg), "{\"js\":\"%s\",\"at\":\"%s\",\"main\":%d}",
	                 escaped, at_document_start ? "document-start" : "document-end",
	                 main_only ? 1 : 0);
	free(escaped);
	if (n < 0 || (size_t)n >= sizeof(msg)) {
		strncpy(c->error, "script too large to send", sizeof(c->error) - 1);
		return -1;
	}
	if (send_msg(c, DWB_MSG_ADD_SCRIPT, msg, (uint32_t)n) != 0)
		return -1;
	char buf[2048];
	dwb_header h;
	if (recv_msg(c, &h, buf, sizeof(buf)) != 0)
		return -1;
	if (strstr(buf, "script-added"))
		return 0;
	char *detail = json_str(buf, "detail");
	snprintf(c->error, sizeof(c->error), "%s", detail ? detail : "add_script refused");
	free(detail);
	return -1;
}

int dwb_frame_describe(const dwb_frame_header *fh, size_t buffer_bytes,
                       dwb_frame_layout *out)
{
	if (!fh || !out)
		return -1;
	memset(out, 0, sizeof(*out));
	out->pixel_offset = sizeof(dwb_frame_header);
	if (fh->magic != DWB_FRAME_MAGIC) {
		out->bad_magic = 1;
		return -1;
	}
	/* The buffer must hold the header and the pixels it claims. A header that
	 * promises more than the transport delivered is rejected here rather than
	 * producing an out-of-bounds read in the caller. */
	if (buffer_bytes < sizeof(dwb_frame_header))
		return -1;
	if (fh->size > buffer_bytes - sizeof(dwb_frame_header))
		return -1;
	out->pixel_bytes = fh->size;

	switch (fh->format) {
	case DWB_PIXEL_RGB:
		out->is_raw = 1; out->components = 3; out->has_alpha = 0;
		break;
	case DWB_PIXEL_RGBA:
	case DWB_PIXEL_BGRA:
		out->is_raw = 1; out->components = 4; out->has_alpha = 1;
		break;
	case DWB_PIXEL_ARGB:
		out->is_raw = 1; out->components = 4; out->has_alpha = 1;
		break;
	default:
		/* Compressed: no rows to blit. Saying so is the whole point - the
		 * previous behaviour drew it as raw, which is reading the JPEG header
		 * as pixels. */
		out->is_raw = 0; out->components = 0; out->needs_decode = 1;
		break;
	}
	if (out->is_raw) {
		/* A raw frame must describe its rows consistently, or a blit computed
		 * from the stride walks outside the buffer. */
		if (fh->width == 0 || fh->height == 0)
			return -1;
		if (fh->width > fh->stride / out->components)
			return -1;
		/* Division, not a product: size_t is 32 bits in the i386 slice. */
		if (fh->height > fh->size / fh->stride)
			return -1;
	}
	return 0;
}

int dwb_client_add_handler(dwb_client *c, const char *name)
{
	c->error[0] = '\0';

	char msg[4096];
	int n = json_pair(msg, sizeof(msg), "name", name);
	if (n < 0) {
		strncpy(c->error, "channel name too long to send", sizeof(c->error) - 1);
		return -1;
	}
	if (send_msg(c, DWB_MSG_ADD_HANDLER, msg, (uint32_t)n) != 0)
		return -1;
	char buf[1024];
	dwb_header h;
	if (recv_msg(c, &h, buf, sizeof(buf)) != 0)
		return -1;
	if (strstr(buf, "handler-added"))
		return 0;
	char *detail = json_str(buf, "detail");
	snprintf(c->error, sizeof(c->error), "%s", detail ? detail : "add_handler refused");
	free(detail);
	return -1;
}

/* Resolves JSON string escapes into a malloc'd copy.
 *
 * The mirror of the host's json_escape. Without it the client read a value only
 * as far as the first quote inside it, so a multi-line body - which is what a
 * page's stringified postMessage always is - arrived truncated. */
static char *json_unescape(const char *in, size_t len)
{
	char *out = malloc(len + 1);
	if (out == NULL)
		return NULL;
	size_t w = 0;
	for (size_t i = 0; i < len; i++) {
		if (in[i] != '\\' || i + 1 >= len) {
			out[w++] = in[i];
			continue;
		}
		i++;
		switch (in[i]) {
		case 'n': out[w++] = '\n'; break;
		case 'r': out[w++] = '\r'; break;
		case 't': out[w++] = '\t'; break;
		case 'b': out[w++] = '\b'; break;
		case 'f': out[w++] = '\f'; break;
		case 'u': {
			if (i + 4 >= len) { out[w++] = in[i]; break; }
			char hex[5] = { in[i+1], in[i+2], in[i+3], in[i+4], 0 };
			char *endp = NULL;
			long v = strtol(hex, &endp, 16);
			if (endp && *endp == 0 && v > 0 && v < 0x80) {
				out[w++] = (char)v; i += 4; break;
			}
			if (endp && *endp == 0 && v >= 0x80 && v < 0x800) {
				out[w++] = (char)(0xC0 | (v >> 6));
				out[w++] = (char)(0x80 | (v & 0x3F)); i += 4; break;
			}
			if (endp && *endp == 0 && v >= 0x800 && v < 0x10000) {
				out[w++] = (char)(0xE0 | (v >> 12));
				out[w++] = (char)(0x80 | ((v >> 6) & 0x3F));
				out[w++] = (char)(0x80 | (v & 0x3F)); i += 4; break;
			}
			out[w++] = in[i];
			break;
		}
		default: out[w++] = in[i]; break;
		}
	}
	out[w] = '\0';
	return out;
}

/* Decoded value of a string field, or NULL. Scans past escapes so a value
 * containing \" does not end the scan early. */
static char *json_decoded_str(const char *json, const char *key)
{
	char pat[64];
	snprintf(pat, sizeof(pat), "\"%s\":\"", key);
	const char *at = strstr(json, pat);
	if (!at)
		return NULL;
	at += strlen(pat);
	const char *end = at;
	while (*end != '\0' && !(*end == '"' && (end == at || end[-1] != '\\'))) {
		if (*end == '\\' && end[1])
			end++;
		end++;
	}
	if (*end != '"')
		return NULL;
	return json_unescape(at, (size_t)(end - at));
}

int dwb_client_poll_message(dwb_client *c, const char *name, char **body)
{
	c->error[0] = '\0';

	char msg[4096];
	int n = json_pair(msg, sizeof(msg), "name", name);
	if (n < 0) {
		strncpy(c->error, "channel name too long to send", sizeof(c->error) - 1);
		return -1;
	}
	if (send_msg(c, DWB_MSG_POLL_MESSAGE, msg, (uint32_t)n) != 0)
		return -1;
	char buf[4096];
	dwb_header h;
	if (recv_msg(c, &h, buf, sizeof(buf)) != 0)
		return -1;
	if (h.type != DWB_MSG_SCRIPT_MESSAGE)
		return -1;
	if (strstr(buf, "\"empty\""))
		return 0;
	if (body)
		*body = json_decoded_str(buf, "body");
	return 1;
}

int dwb_client_frame(dwb_client *c, dwb_frame_header *out, const void **pixels,

                     size_t *pixel_bytes, void **shm_map, size_t *shm_size,
                     int *in_shm)
{
	/* Sized to the capacity it is told, not to the frame header. The two were
	 * different: this used to malloc(sizeof(dwb_frame_header)) - 32 bytes,
	 * asserted in protocol.h - and hand recv_msg a cap of 4096, so any host
	 * reply longer than 32 bytes wrote up to 4096 bytes into a 32-byte heap
	 * allocation. The frame reply is exactly 32 bytes, so the terminator alone
	 * already overflowed by one, and an error event's JSON overflowed it by
	 * however long the message was. */
	char *buf = malloc(4097);
	if (!buf)
		return -1;
	if (send_msg(c, DWB_MSG_FRAME, NULL, 0) != 0) {
		free(buf);
		return -1;
	}
	dwb_header h;
	if (recv_msg(c, &h, buf, 4096) != 0) {
		free(buf);
		return -1;
	}
	if (h.type == DWB_MSG_EVENT) {
		/* Host reported an error instead of a frame; surface it rather than
		 * handing the caller a stale surface to paint. */
		char *detail = json_str(buf, "detail");
		snprintf(c->error, sizeof(c->error), "%s", detail ? detail : "frame error");
		free(detail);
		free(buf);
		*pixels = NULL;
		return -1;
	}
	if (h.type != DWB_MSG_FRAME || h.length != sizeof(dwb_frame_header)) {
		free(buf);
		return -1;
	}
	memcpy(out, buf, sizeof(*out));
	free(buf);
	*pixel_bytes = out->size;
	*in_shm = out->reserved == DWB_FRAME_IN_SHM;

	if (*in_shm) {
		/* Pixels are in the region the caller mapped; nothing crosses the
		 * socket and nothing is owned here. */
		*pixels = NULL;
		return 0;
	}
	if (out->size) {
		void *p = malloc(out->size);
		if (!p)
			return -1;
		if (recv_all(c->fd, p, out->size) != 0) {
			free(p);
			return -1;
		}
		*pixels = p;
	}
	return 0;
}

void dwb_client_free_frame(dwb_client *c, void *pixels)
{
	(void)c;
	free(pixels);
}
