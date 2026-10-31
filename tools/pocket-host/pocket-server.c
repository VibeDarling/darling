/*
 * The host's side of AppKit's Pocket protocol: see pocket-server.h.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <poll.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#include "pocket-server.h"

#define MAX_CLIENTS 16
#define MAX_WINDOWS 64

struct window {
	int used;
	int client;
	uint32_t id;
	struct pocket_window state;
	uint8_t *mapped; // the app's buffer
	size_t mapped_size;
	uint32_t width, height, stride;
	uint8_t *pixels; // the last frame, copied out of it
	int order;       // stacking within a level, higher in front
	unsigned presents;
};

struct client {
	int fd;
	uint32_t pid;
	uint8_t input[sizeof(struct pocket_header) + POCKET_MAX_MESSAGE];
	size_t length;
	int fds[8];
	int nfds;
};

struct pocket_server {
	pthread_mutex_t lock;
	int listener;
	char path[sizeof(((struct sockaddr_un *) 0)->sun_path)];
	struct pocket_server_events events;
	struct pocket_screen screen;
	struct client clients[MAX_CLIENTS];
	struct window windows[MAX_WINDOWS];
	int next_order;
};

static void lock(struct pocket_server *s)
{
	pthread_mutex_lock(&s->lock);
}

static void unlock(struct pocket_server *s)
{
	pthread_mutex_unlock(&s->lock);
}

static void say(struct pocket_server *s, const char *format, ...)
{
	if (s->events.log == NULL)
		return;
	char line[1024];
	va_list args;
	va_start(args, format);
	vsnprintf(line, sizeof(line), format, args);
	va_end(args);
	s->events.log(s->events.context, line);
}

double pocket_server_now(void)
{
	struct timespec t;
	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec + t.tv_nsec / 1e9;
}

static void send_message(struct pocket_server *s, int client, uint32_t type, const void *bytes, size_t length)
{
	struct client *c = &s->clients[client];
	if (c->fd < 0 || length > POCKET_MAX_MESSAGE)
		return;
	uint8_t message[sizeof(struct pocket_header) + POCKET_MAX_MESSAGE];
	struct pocket_header header = {type, (uint32_t) length};
	memcpy(message, &header, sizeof(header));
	if (length)
		memcpy(message + sizeof(header), bytes, length);
	size_t total = sizeof(header) + length, done = 0;
	while (done < total) {
		ssize_t sent = send(c->fd, message + done, total - done, MSG_NOSIGNAL);
		if (sent < 0 && errno == EINTR)
			continue;
		if (sent <= 0)
			return;
		done += sent;
	}
}

static void broadcast(struct pocket_server *s, uint32_t type, const void *bytes, size_t length)
{
	for (int i = 0; i < MAX_CLIENTS; i++)
		if (s->clients[i].fd >= 0)
			send_message(s, i, type, bytes, length);
}

static struct window *find_window(struct pocket_server *s, int client, uint32_t id, int create)
{
	for (int i = 0; i < MAX_WINDOWS; i++)
		if (s->windows[i].used && s->windows[i].client == client && s->windows[i].id == id)
			return &s->windows[i];
	if (!create)
		return NULL;
	for (int i = 0; i < MAX_WINDOWS; i++)
		if (!s->windows[i].used) {
			memset(&s->windows[i], 0, sizeof(s->windows[i]));
			s->windows[i].used = 1;
			s->windows[i].client = client;
			s->windows[i].id = id;
			s->windows[i].order = s->next_order++;
			return &s->windows[i];
		}
	return NULL;
}

static void drop_window(struct window *w)
{
	if (w->mapped)
		munmap(w->mapped, w->mapped_size);
	free(w->pixels);
	w->used = 0;
}

static int stacking(const void *a, const void *b)
{
	const struct window *x = *(struct window *const *) a, *y = *(struct window *const *) b;
	if (x->state.level != y->state.level)
		return x->state.level < y->state.level ? -1 : 1;
	return x->order - y->order;
}

#define SWAP_RED_BLUE(p) (((p) & 0xff00ff00) | (((p) & 0xff) << 16) | (((p) >> 16) & 0xff))

// A row of a window over the screen's. One plain loop per case, so the
// compiler can vectorize them: a frame is megabytes.
static void compose_row(uint32_t *dst, const uint32_t *src, int count, int opaque, int rgba)
{
	if (opaque && !rgba) {
		memcpy(dst, src, (size_t) count * 4);
	} else if (opaque) {
		for (int i = 0; i < count; i++)
			dst[i] = SWAP_RED_BLUE(src[i]) | 0xff000000;
	} else {
		for (int i = 0; i < count; i++) {
			uint32_t pixel = rgba ? SWAP_RED_BLUE(src[i]) : src[i];
			uint32_t alpha = pixel >> 24;
			if (alpha == 255) {
				dst[i] = pixel;
			} else if (pixel != 0) {
				// Premultiplied: dst = src + dst * (1 - alpha), two channels at a time.
				uint32_t under = dst[i], keep = 255 - alpha;
				uint32_t rb = (under & 0x00ff00ff) * keep + 0x00800080;
				rb = ((rb + ((rb >> 8) & 0x00ff00ff)) >> 8) & 0x00ff00ff;
				uint32_t ag = ((under >> 8) & 0x00ff00ff) * keep + 0x00800080;
				ag = (ag + ((ag >> 8) & 0x00ff00ff)) & 0xff00ff00;
				dst[i] = pixel + rb + ag;
			}
		}
	}
}

static int covers_screen(const struct window *w, uint32_t width, uint32_t height)
{
	return (w->state.flags & POCKET_WINDOW_OPAQUE) && w->state.x <= 0 && w->state.y <= 0
		&& w->state.x + (int64_t) w->width >= width && w->state.y + (int64_t) w->height >= height;
}

static int overlaps(const struct window *w, const int32_t rect[4])
{
	return w->state.x < rect[0] + rect[2] && rect[0] < w->state.x + (int64_t) w->width
		&& w->state.y < rect[1] + rect[3] && rect[1] < w->state.y + (int64_t) w->height;
}

int pocket_server_window_part(struct pocket_server *s, uint32_t pid, uint32_t id, int32_t rect[4])
{
	lock(s);
	struct window *found = NULL;
	for (int i = 0; i < MAX_WINDOWS && found == NULL; i++) {
		struct window *w = &s->windows[i];
		if (w->used && w->id == id && s->clients[w->client].fd >= 0 && s->clients[w->client].pid == pid)
			found = w;
	}
	int shows = -1;
	if (found != NULL) {
		rect[0] += found->state.x;
		rect[1] += found->state.y;
		shows = (found->state.flags & POCKET_WINDOW_VISIBLE) && found->pixels != NULL;
		for (int i = 0; i < MAX_WINDOWS && shows; i++) {
			struct window *w = &s->windows[i];
			const struct window *pair[2] = { found, w };
			if (w != found && w->used && w->pixels && (w->state.flags & POCKET_WINDOW_VISIBLE)
				&& stacking(&pair[0], &pair[1]) < 0 && overlaps(w, rect))
				shows = 0;
		}
	}
	unlock(s);
	return shows;
}

void pocket_server_compose(struct pocket_server *s, uint8_t *pixels, size_t stride, int rgba)
{
	lock(s);
	uint32_t width = s->screen.width, height = s->screen.height;

	struct window *sorted[MAX_WINDOWS];
	int count = 0;
	for (int i = 0; i < MAX_WINDOWS; i++)
		if (s->windows[i].used && s->windows[i].pixels && (s->windows[i].state.flags & POCKET_WINDOW_VISIBLE))
			sorted[count++] = &s->windows[i];
	qsort(sorted, count, sizeof(sorted[0]), stacking);

	// What is under an opaque window that covers the screen (a game's, an
	// app's main window) is not seen: neither windows nor the black.
	int first = 0;
	for (int n = count - 1; n >= 0 && first == 0; n--)
		if (covers_screen(sorted[n], width, height))
			first = n + 1;
	if (first == 0) {
		for (uint32_t y = 0; y < height; y++) {
			uint32_t *row = (uint32_t *) (pixels + y * stride);
			for (uint32_t x = 0; x < width; x++)
				row[x] = 0xff000000; // opaque black, in either byte order
		}
	} else {
		first--;
	}

	for (int n = first; n < count; n++) {
		struct window *w = sorted[n];
		int opaque = (w->state.flags & POCKET_WINDOW_OPAQUE) != 0;
		// The part of the window on the screen.
		int x0 = w->state.x < 0 ? -w->state.x : 0, y0 = w->state.y < 0 ? -w->state.y : 0;
		int x1 = (int) w->width, y1 = (int) w->height;
		if (w->state.x + x1 > (int) width)
			x1 = (int) width - w->state.x;
		if (w->state.y + y1 > (int) height)
			y1 = (int) height - w->state.y;
		for (int row = y0; row < y1 && x0 < x1; row++) {
			const uint32_t *src = (const uint32_t *) (w->pixels + ((size_t) row * w->width + x0) * 4);
			uint32_t *dst = (uint32_t *) (pixels + (size_t) (w->state.y + row) * stride + (size_t) (w->state.x + x0) * 4);
			compose_row(dst, src, x1 - x0, opaque, rgba);
		}
	}
	unlock(s);
}

static void handle(struct pocket_server *s, int client, uint32_t type, const uint8_t *bytes, size_t length)
{
	struct client *c = &s->clients[client];
	switch (type) {
	case POCKET_HELLO: {
		struct pocket_hello hello = {0};
		memcpy(&hello, bytes, length < sizeof(hello) ? length : sizeof(hello));
		c->pid = hello.pid;
		say(s, "hello %u version %u", hello.pid, hello.version);
		send_message(s, client, POCKET_SCREEN, &s->screen, sizeof(s->screen));
		break;
	}
	case POCKET_WINDOW: {
		struct pocket_window state;
		if (length < sizeof(state))
			break;
		memcpy(&state, bytes, sizeof(state));
		struct window *w = find_window(s, client, state.window, 1);
		if (w == NULL)
			break;
		int was_visible = (w->state.flags & POCKET_WINDOW_VISIBLE) != 0;
		w->state = state;
		say(s, "window %u %d %d %d %d flags %u level %d", state.window, state.x, state.y, state.width,
			state.height, state.flags, state.level);
		// A window hidden or moved changes the screen without a frame.
		if ((was_visible || (state.flags & POCKET_WINDOW_VISIBLE)) && w->pixels && s->events.frame)
			s->events.frame(s->events.context);
		break;
	}
	case POCKET_BUFFER: {
		struct pocket_buffer buffer;
		if (length < sizeof(buffer) || c->nfds == 0)
			break;
		memcpy(&buffer, bytes, sizeof(buffer));
		int fd = c->fds[0];
		memmove(c->fds, c->fds + 1, --c->nfds * sizeof(int));
		struct window *w = find_window(s, client, buffer.window, 1);
		if (w == NULL || buffer.format != POCKET_FORMAT_BGRA || buffer.stride < buffer.width * 4) {
			close(fd);
			break;
		}
		if (w->mapped)
			munmap(w->mapped, w->mapped_size);
		w->mapped_size = (size_t) buffer.stride * buffer.height;
		w->mapped = mmap(NULL, w->mapped_size, PROT_READ, MAP_SHARED, fd, 0);
		close(fd);
		if (w->mapped == MAP_FAILED) {
			w->mapped = NULL;
			say(s, "buffer %u cannot be mapped: %s", buffer.window, strerror(errno));
			break;
		}
		w->width = buffer.width;
		w->height = buffer.height;
		w->stride = buffer.stride;
		free(w->pixels);
		w->pixels = calloc((size_t) w->width * w->height, 4);
		say(s, "buffer %u %u %u", buffer.window, buffer.width, buffer.height);
		break;
	}
	case POCKET_PRESENT: {
		struct pocket_present present;
		if (length < sizeof(present))
			break;
		memcpy(&present, bytes, sizeof(present));
		struct window *w = find_window(s, client, present.window, 0);
		if (w != NULL && w->mapped && w->pixels) {
			// Only the part that changed: the rest is in the last frame.
			int64_t x0 = present.x > 0 ? present.x : 0, y0 = present.y > 0 ? present.y : 0;
			int64_t x1 = (int64_t) present.x + present.width, y1 = (int64_t) present.y + present.height;
			if (x1 > w->width)
				x1 = w->width;
			if (y1 > w->height)
				y1 = w->height;
			for (int64_t row = y0; row < y1 && x0 < x1; row++)
				memcpy(w->pixels + ((size_t) row * w->width + x0) * 4, w->mapped + (size_t) row * w->stride + x0 * 4,
					   (size_t) (x1 - x0) * 4);
			w->presents++;
			say(s, "present %u %u", present.window, w->presents);
		}
		// The frame is copied, so the app may draw the next one.
		struct pocket_window_id release = {present.window};
		send_message(s, client, POCKET_RELEASE, &release, sizeof(release));
		if (w != NULL && s->events.frame)
			s->events.frame(s->events.context);
		break;
	}
	case POCKET_DESTROY: {
		struct pocket_window_id id;
		if (length < sizeof(id))
			break;
		memcpy(&id, bytes, sizeof(id));
		struct window *w = find_window(s, client, id.window, 0);
		if (w != NULL)
			drop_window(w);
		say(s, "destroy %u", id.window);
		if (s->events.frame)
			s->events.frame(s->events.context);
		break;
	}
	case POCKET_ORDER: {
		char line[1024];
		int used = snprintf(line, sizeof(line), "order");
		for (size_t i = 0; i + 4 <= length; i += 4) {
			uint32_t id;
			memcpy(&id, bytes + i, 4);
			struct window *w = find_window(s, client, id, 0);
			if (w != NULL)
				w->order = s->next_order++;
			if (used < (int) sizeof(line))
				used += snprintf(line + used, sizeof(line) - used, " %u", id);
		}
		say(s, "%s", line);
		if (s->events.frame)
			s->events.frame(s->events.context);
		break;
	}
	case POCKET_KEYBOARD: {
		struct pocket_keyboard keyboard = {0};
		memcpy(&keyboard, bytes, length < sizeof(keyboard) ? length : sizeof(keyboard));
		say(s, "keyboard %u type %u return %u caps %u correct %u flags %u", keyboard.shown, keyboard.keyboard_type,
			keyboard.return_key, keyboard.autocapitalization, keyboard.autocorrection, keyboard.flags);
		if (s->events.keyboard)
			s->events.keyboard(s->events.context, &keyboard);
		break;
	}
	default:
		say(s, "unknown message %u", type);
		break;
	}
}

static void close_client(struct pocket_server *s, int client)
{
	struct client *c = &s->clients[client];
	say(s, "closed %u", c->pid);
	for (int i = 0; i < MAX_WINDOWS; i++)
		if (s->windows[i].used && s->windows[i].client == client)
			drop_window(&s->windows[i]);
	for (int i = 0; i < c->nfds; i++)
		close(c->fds[i]);
	close(c->fd);
	c->fd = -1;
	if (s->events.frame)
		s->events.frame(s->events.context);
}

static void read_client(struct pocket_server *s, int client)
{
	struct client *c = &s->clients[client];
	union {
		struct cmsghdr header;
		char space[CMSG_SPACE(sizeof(int) * 8)];
	} control;
	struct iovec iov = {c->input + c->length, sizeof(c->input) - c->length};
	struct msghdr msg = {.msg_iov = &iov, .msg_iovlen = 1, .msg_control = control.space,
						 .msg_controllen = sizeof(control.space)};
	ssize_t got = recvmsg(c->fd, &msg, MSG_CMSG_CLOEXEC | MSG_DONTWAIT);
	if (got < 0 && (errno == EAGAIN || errno == EINTR))
		return;
	if (got <= 0) {
		close_client(s, client);
		return;
	}
	for (struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg); cmsg; cmsg = CMSG_NXTHDR(&msg, cmsg)) {
		if (cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS)
			continue;
		int n = (cmsg->cmsg_len - CMSG_LEN(0)) / sizeof(int);
		for (int i = 0; i < n; i++) {
			int fd;
			memcpy(&fd, CMSG_DATA(cmsg) + i * sizeof(int), sizeof(int));
			if (c->nfds < 8)
				c->fds[c->nfds++] = fd;
			else
				close(fd);
		}
	}
	c->length += got;
	size_t offset = 0;
	while (c->length - offset >= sizeof(struct pocket_header)) {
		struct pocket_header header;
		memcpy(&header, c->input + offset, sizeof(header));
		if (header.size > POCKET_MAX_MESSAGE) {
			close_client(s, client);
			return;
		}
		if (c->length - offset < sizeof(header) + header.size)
			break;
		handle(s, client, header.type, c->input + offset + sizeof(header), header.size);
		if (c->fd < 0)
			return;
		offset += sizeof(header) + header.size;
	}
	memmove(c->input, c->input + offset, c->length - offset);
	c->length -= offset;
}

struct pocket_server *pocket_server_listen(const char *path, const struct pocket_screen *screen,
										   const struct pocket_server_events *events)
{
	struct sockaddr_un address = {.sun_family = AF_UNIX};
	if (strlen(path) >= sizeof(address.sun_path)) {
		errno = ENAMETOOLONG;
		return NULL;
	}
	strcpy(address.sun_path, path);
	int listener = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
	if (listener < 0)
		return NULL;
	unlink(path);
	if (bind(listener, (struct sockaddr *) &address, sizeof(address)) != 0 || listen(listener, 8) != 0) {
		int error = errno;
		close(listener);
		errno = error;
		return NULL;
	}

	struct pocket_server *s = calloc(1, sizeof(*s));
	pthread_mutexattr_t attributes;
	pthread_mutexattr_init(&attributes);
	pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&s->lock, &attributes);
	pthread_mutexattr_destroy(&attributes);
	s->listener = listener;
	strcpy(s->path, path);
	if (events)
		s->events = *events;
	s->screen = *screen;
	s->next_order = 1;
	for (int i = 0; i < MAX_CLIENTS; i++)
		s->clients[i].fd = -1;
	return s;
}

void pocket_server_close(struct pocket_server *s)
{
	lock(s);
	for (int i = 0; i < MAX_CLIENTS; i++)
		if (s->clients[i].fd >= 0)
			close_client(s, i);
	close(s->listener);
	unlink(s->path);
	unlock(s);
	pthread_mutex_destroy(&s->lock);
	free(s);
}

int pocket_server_poll(struct pocket_server *s, int extra, int timeout)
{
	struct pollfd fds[MAX_CLIENTS + 2];
	int map[MAX_CLIENTS + 2], n = 0;
	lock(s);
	fds[n] = (struct pollfd) {s->listener, POLLIN};
	map[n++] = -1;
	if (extra >= 0) {
		fds[n] = (struct pollfd) {extra, POLLIN};
		map[n++] = -2;
	}
	for (int i = 0; i < MAX_CLIENTS; i++)
		if (s->clients[i].fd >= 0) {
			fds[n] = (struct pollfd) {s->clients[i].fd, POLLIN};
			map[n++] = i;
		}
	unlock(s);

	if (poll(fds, n, timeout) < 0)
		return errno == EINTR ? 0 : -1;

	int extra_ready = 0;
	lock(s);
	for (int i = 0; i < n; i++) {
		if (!(fds[i].revents & (POLLIN | POLLHUP | POLLERR)))
			continue;
		if (map[i] == -1) {
			if (fds[i].revents & POLLERR) {
				unlock(s);
				return -1;
			}
			int fd = accept4(s->listener, NULL, NULL, SOCK_CLOEXEC);
			for (int k = 0; fd >= 0 && k < MAX_CLIENTS; k++)
				if (s->clients[k].fd < 0) {
					memset(&s->clients[k], 0, sizeof(s->clients[k]));
					s->clients[k].fd = fd;
					fd = -1;
				}
			if (fd >= 0)
				close(fd);
		} else if (map[i] == -2) {
			extra_ready = 1;
		} else if (s->clients[map[i]].fd == fds[i].fd) {
			read_client(s, map[i]);
		}
	}
	unlock(s);
	return extra_ready;
}

void pocket_server_set_screen(struct pocket_server *s, const struct pocket_screen *screen)
{
	lock(s);
	s->screen = *screen;
	broadcast(s, POCKET_SCREEN, &s->screen, sizeof(s->screen));
	unlock(s);
}

struct pocket_screen pocket_server_screen(struct pocket_server *s)
{
	lock(s);
	struct pocket_screen screen = s->screen;
	unlock(s);
	return screen;
}

void pocket_server_touch(struct pocket_server *s, uint32_t phase, uint32_t finger, float x, float y, double time)
{
	struct pocket_touch t = {phase, finger, x, y, time};
	lock(s);
	broadcast(s, POCKET_TOUCH, &t, sizeof(t));
	unlock(s);
}

void pocket_server_key(struct pocket_server *s, int down, uint32_t keycode, uint32_t modifiers,
					   const char *characters, size_t length)
{
	uint8_t message[sizeof(struct pocket_key) + 256];
	if (length > 256)
		length = 256;
	struct pocket_key k = {down != 0, keycode, modifiers, (uint32_t) length};
	memcpy(message, &k, sizeof(k));
	if (length)
		memcpy(message + sizeof(k), characters, length);
	lock(s);
	broadcast(s, POCKET_KEY, message, sizeof(k) + length);
	unlock(s);
}

void pocket_server_keyboard_frame(struct pocket_server *s, uint32_t height)
{
	struct pocket_keyboard_frame frame = {height};
	lock(s);
	broadcast(s, POCKET_KEYBOARD_FRAME, &frame, sizeof(frame));
	unlock(s);
}

void pocket_server_text(struct pocket_server *s, const char *text, size_t length)
{
	if (length > POCKET_MAX_MESSAGE)
		length = POCKET_MAX_MESSAGE;
	lock(s);
	broadcast(s, POCKET_TEXT, text, length);
	unlock(s);
}
