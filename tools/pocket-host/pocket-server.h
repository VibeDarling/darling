/*
 * The host's side of AppKit's Pocket protocol
 * (src/external/cocotron/AppKit/Pocket.backend/PocketProtocol.h), for
 * pocket-host on Linux and for the Android app's display.
 *
 * A server listens on a Unix socket and keeps each app's windows. A thread
 * runs pocket_server_poll(); any thread may send input or compose the screen.
 * Each call takes the server's lock, and the events are called with it held,
 * so an event may call back into the server.
 */

#ifndef POCKET_SERVER_H
#define POCKET_SERVER_H

#include <stddef.h>
#include <stdint.h>

#include "../../src/external/cocotron/AppKit/Pocket.backend/PocketProtocol.h"

struct pocket_server;

struct pocket_server_events {
	void *context;
	// What an app did, as one line: "hello PID version N", "window ...",
	// "buffer ID W H", "present ID N", "order ...", "keyboard 0|1 type ...",
	// "destroy ID", "closed PID".
	void (*log)(void *context, const char *line);
	// An app wants the soft keyboard shown or hidden, and for what text.
	void (*keyboard)(void *context, const struct pocket_keyboard *keyboard);
	// A window presented a frame, so the screen should be composed again.
	void (*frame)(void *context);
};

struct pocket_server *pocket_server_listen(const char *path, const struct pocket_screen *screen,
										   const struct pocket_server_events *events);
void pocket_server_close(struct pocket_server *server);

// Waits up to `timeout` milliseconds (-1 for ever) for apps, and handles what
// they sent. Returns 1 when `extra` (another descriptor, or -1) is readable,
// 0 otherwise, and -1 when the server can no longer listen.
int pocket_server_poll(struct pocket_server *server, int extra, int timeout);

void pocket_server_set_screen(struct pocket_server *server, const struct pocket_screen *screen);
struct pocket_screen pocket_server_screen(struct pocket_server *server);

// Input, sent to every app.
void pocket_server_touch(struct pocket_server *server, uint32_t phase, uint32_t finger, float x, float y,
						 double time);
void pocket_server_key(struct pocket_server *server, int down, uint32_t keycode, uint32_t modifiers,
					   const char *characters, size_t length);
void pocket_server_text(struct pocket_server *server, const char *text, size_t length);
// The soft keyboard covers `height` pixels at the screen's bottom (0: it's gone).
void pocket_server_keyboard_frame(struct pocket_server *server, uint32_t height);

// Draws every visible window, from the back, over black, into `pixels`: the
// screen's size, `stride` bytes per row, BGRA or (with `rgba`) RGBA bytes.
void pocket_server_compose(struct pocket_server *server, uint8_t *pixels, size_t stride, int rgba);

// Where part of an app's window is on the screen, for the host to put a view
// of its own there (a web page, under an iOS UIWebView). The window is the
// app's (its pid) window `id`; `rect` is x, y, width and height in its pixels,
// and becomes the screen's. Returns 1 when that part shows: the window is
// visible and no window in front of it overlaps the part; 0 when it is hidden
// or covered; -1 when there is no such window.
int pocket_server_window_part(struct pocket_server *server, uint32_t pid, uint32_t id, int32_t rect[4]);

double pocket_server_now(void);

#endif
