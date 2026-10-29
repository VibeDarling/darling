/*
 * pocket-host: a phone host for AppKit's Pocket backend, on Linux.
 *
 * It does what the Android app's display does (see
 * src/external/cocotron/AppKit/Pocket.backend/PocketProtocol.h): it gives
 * apps a screen, shows their windows, and sends them touches, keys and text.
 * Here the screen is a framebuffer in memory and input comes from commands on
 * stdin, so tests can drive an app and look at what it drew.
 *
 *   pocket-host SOCKET WIDTHxHEIGHT@SCALE [TOP,LEFT,BOTTOM,RIGHT]
 *
 * The size and the insets are pixels. Commands, one per line:
 *
 *   tap X Y                 a finger down and up
 *   down|move|up FINGER X Y
 *   drag X1 Y1 X2 Y2 STEPS  a finger moved in steps
 *   text STRING             what an input method commits
 *   key CODE [CHARS]        a key down and up (a Mac virtual key code)
 *   screen WIDTHxHEIGHT@SCALE [TOP,LEFT,BOTTOM,RIGHT]
 *   pixel X Y               prints "pixel X Y RRGGBB"
 *   shot FILE.png           writes the screen
 *   quit
 *
 * It prints what apps tell it: hello, window, buffer, present (each), order,
 * keyboard and destroy lines, and "closed PID" when an app goes.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>
#include <zlib.h>

#include "../../src/external/cocotron/AppKit/Pocket.backend/PocketProtocol.h"

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

static struct client clients[MAX_CLIENTS];
static struct window windows[MAX_WINDOWS];
static struct pocket_screen screen;
static uint8_t *framebuffer; // BGRA, like the apps' buffers
static int next_order = 1;

static void send_message(int client, uint32_t type, const void *bytes, size_t length)
{
	struct client *c = &clients[client];
	if (c->fd < 0)
		return;
	uint8_t message[sizeof(struct pocket_header) + POCKET_MAX_MESSAGE];
	struct pocket_header header = {type, (uint32_t) length};
	memcpy(message, &header, sizeof(header));
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

static void broadcast(uint32_t type, const void *bytes, size_t length)
{
	for (int i = 0; i < MAX_CLIENTS; i++)
		if (clients[i].fd >= 0)
			send_message(i, type, bytes, length);
}

static struct window *find_window(int client, uint32_t id, int create)
{
	for (int i = 0; i < MAX_WINDOWS; i++)
		if (windows[i].used && windows[i].client == client && windows[i].id == id)
			return &windows[i];
	if (!create)
		return NULL;
	for (int i = 0; i < MAX_WINDOWS; i++)
		if (!windows[i].used) {
			memset(&windows[i], 0, sizeof(windows[i]));
			windows[i].used = 1;
			windows[i].client = client;
			windows[i].id = id;
			windows[i].order = next_order++;
			return &windows[i];
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

// Draws every visible window, from the back, over black.
static void compose(void)
{
	size_t size = (size_t) screen.width * screen.height * 4;
	memset(framebuffer, 0, size);
	for (size_t i = 3; i < size; i += 4)
		framebuffer[i] = 255;

	struct window *sorted[MAX_WINDOWS];
	int count = 0;
	for (int i = 0; i < MAX_WINDOWS; i++)
		if (windows[i].used && windows[i].pixels && (windows[i].state.flags & POCKET_WINDOW_VISIBLE))
			sorted[count++] = &windows[i];
	qsort(sorted, count, sizeof(sorted[0]), stacking);

	for (int n = 0; n < count; n++) {
		struct window *w = sorted[n];
		int opaque = (w->state.flags & POCKET_WINDOW_OPAQUE) != 0;
		for (uint32_t row = 0; row < w->height; row++) {
			int y = w->state.y + (int) row;
			if (y < 0 || y >= (int) screen.height)
				continue;
			const uint8_t *src = w->pixels + (size_t) row * w->width * 4;
			for (uint32_t col = 0; col < w->width; col++) {
				int x = w->state.x + (int) col;
				if (x < 0 || x >= (int) screen.width)
					continue;
				uint8_t *dst = framebuffer + ((size_t) y * screen.width + x) * 4;
				const uint8_t *s = src + col * 4;
				if (opaque || s[3] == 255) {
					memcpy(dst, s, 3);
				} else if (s[3] != 0) {
					// Premultiplied: dst = src + dst * (1 - alpha).
					for (int k = 0; k < 3; k++)
						dst[k] = (uint8_t) (s[k] + dst[k] * (255 - s[3]) / 255);
				}
			}
		}
	}
}

static uint32_t crc_of(const uint8_t *type, const uint8_t *data, size_t length)
{
	uLong crc = crc32(0, type, 4);
	return (uint32_t) crc32(crc, data, (uInt) length);
}

static void put32(FILE *f, uint32_t v)
{
	uint8_t b[4] = {v >> 24, v >> 16, v >> 8, v};
	fwrite(b, 1, 4, f);
}

static void chunk(FILE *f, const char *type, const uint8_t *data, size_t length)
{
	put32(f, (uint32_t) length);
	fwrite(type, 1, 4, f);
	fwrite(data, 1, length, f);
	put32(f, crc_of((const uint8_t *) type, data, length));
}

static int write_png(const char *path)
{
	compose();
	size_t raw_size = (size_t) screen.height * (1 + screen.width * 3);
	uint8_t *raw = malloc(raw_size);
	for (uint32_t y = 0; y < screen.height; y++) {
		uint8_t *line = raw + (size_t) y * (1 + screen.width * 3);
		line[0] = 0;
		for (uint32_t x = 0; x < screen.width; x++) {
			const uint8_t *p = framebuffer + ((size_t) y * screen.width + x) * 4;
			line[1 + x * 3] = p[2];
			line[2 + x * 3] = p[1];
			line[3 + x * 3] = p[0];
		}
	}
	uLongf packed_size = compressBound(raw_size);
	uint8_t *packed = malloc(packed_size);
	compress2(packed, &packed_size, raw, raw_size, 6);
	FILE *f = fopen(path, "wb");
	if (f == NULL) {
		free(raw);
		free(packed);
		return -1;
	}
	fwrite("\x89PNG\r\n\x1a\n", 1, 8, f);
	uint8_t ihdr[13] = {screen.width >> 24, screen.width >> 16, screen.width >> 8, screen.width,
	                    screen.height >> 24, screen.height >> 16, screen.height >> 8, screen.height,
	                    8, 2, 0, 0, 0};
	chunk(f, "IHDR", ihdr, sizeof(ihdr));
	chunk(f, "IDAT", packed, packed_size);
	chunk(f, "IEND", NULL, 0);
	fclose(f);
	free(raw);
	free(packed);
	return 0;
}

static void handle(int client, uint32_t type, const uint8_t *bytes, size_t length)
{
	struct client *c = &clients[client];
	switch (type) {
	case POCKET_HELLO: {
		struct pocket_hello hello = {0};
		memcpy(&hello, bytes, length < sizeof(hello) ? length : sizeof(hello));
		c->pid = hello.pid;
		printf("hello %u version %u\n", hello.pid, hello.version);
		send_message(client, POCKET_SCREEN, &screen, sizeof(screen));
		break;
	}
	case POCKET_WINDOW: {
		struct pocket_window state;
		if (length < sizeof(state))
			break;
		memcpy(&state, bytes, sizeof(state));
		struct window *w = find_window(client, state.window, 1);
		if (w == NULL)
			break;
		w->state = state;
		printf("window %u %d %d %d %d flags %u level %d\n", state.window, state.x, state.y, state.width,
		       state.height, state.flags, state.level);
		break;
	}
	case POCKET_BUFFER: {
		struct pocket_buffer buffer;
		if (length < sizeof(buffer) || c->nfds == 0)
			break;
		memcpy(&buffer, bytes, sizeof(buffer));
		int fd = c->fds[0];
		memmove(c->fds, c->fds + 1, --c->nfds * sizeof(int));
		struct window *w = find_window(client, buffer.window, 1);
		if (w == NULL || buffer.format != POCKET_FORMAT_BGRA) {
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
			printf("buffer %u cannot be mapped: %s\n", buffer.window, strerror(errno));
			break;
		}
		w->width = buffer.width;
		w->height = buffer.height;
		w->stride = buffer.stride;
		free(w->pixels);
		w->pixels = calloc((size_t) w->width * w->height, 4);
		printf("buffer %u %u %u\n", buffer.window, buffer.width, buffer.height);
		break;
	}
	case POCKET_PRESENT: {
		struct pocket_present present;
		if (length < sizeof(present))
			break;
		memcpy(&present, bytes, sizeof(present));
		struct window *w = find_window(client, present.window, 0);
		if (w != NULL && w->mapped) {
			for (uint32_t row = 0; row < w->height; row++)
				memcpy(w->pixels + (size_t) row * w->width * 4, w->mapped + (size_t) row * w->stride,
				       (size_t) w->width * 4);
			w->presents++;
			printf("present %u %u\n", present.window, w->presents);
		}
		struct pocket_window_id release = {present.window};
		send_message(client, POCKET_RELEASE, &release, sizeof(release));
		break;
	}
	case POCKET_DESTROY: {
		struct pocket_window_id id;
		if (length < sizeof(id))
			break;
		memcpy(&id, bytes, sizeof(id));
		struct window *w = find_window(client, id.window, 0);
		if (w != NULL)
			drop_window(w);
		printf("destroy %u\n", id.window);
		break;
	}
	case POCKET_ORDER: {
		printf("order");
		for (size_t i = 0; i + 4 <= length; i += 4) {
			uint32_t id;
			memcpy(&id, bytes + i, 4);
			struct window *w = find_window(client, id, 0);
			if (w != NULL)
				w->order = next_order++;
			printf(" %u", id);
		}
		printf("\n");
		break;
	}
	case POCKET_KEYBOARD: {
		struct pocket_keyboard keyboard = {0};
		memcpy(&keyboard, bytes, length < sizeof(keyboard) ? length : sizeof(keyboard));
		printf("keyboard %u\n", keyboard.shown);
		break;
	}
	default:
		printf("unknown message %u\n", type);
		break;
	}
}

static void close_client(int client)
{
	struct client *c = &clients[client];
	printf("closed %u\n", c->pid);
	for (int i = 0; i < MAX_WINDOWS; i++)
		if (windows[i].used && windows[i].client == client)
			drop_window(&windows[i]);
	for (int i = 0; i < c->nfds; i++)
		close(c->fds[i]);
	close(c->fd);
	c->fd = -1;
}

static void read_client(int client)
{
	struct client *c = &clients[client];
	union {
		struct cmsghdr header;
		char space[CMSG_SPACE(sizeof(int) * 8)];
	} control;
	struct iovec iov = {c->input + c->length, sizeof(c->input) - c->length};
	struct msghdr msg = {.msg_iov = &iov, .msg_iovlen = 1, .msg_control = control.space,
	                     .msg_controllen = sizeof(control.space)};
	ssize_t got = recvmsg(c->fd, &msg, MSG_CMSG_CLOEXEC);
	if (got <= 0) {
		close_client(client);
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
			close_client(client);
			return;
		}
		if (c->length - offset < sizeof(header) + header.size)
			break;
		handle(client, header.type, c->input + offset + sizeof(header), header.size);
		offset += sizeof(header) + header.size;
	}
	memmove(c->input, c->input + offset, c->length - offset);
	c->length -= offset;
}

static double now(void)
{
	struct timespec t;
	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec + t.tv_nsec / 1e9;
}

static void touch(uint32_t phase, uint32_t finger, float x, float y)
{
	struct pocket_touch t = {phase, finger, x, y, now()};
	broadcast(POCKET_TOUCH, &t, sizeof(t));
}

static void key(uint32_t code, const char *chars)
{
	uint8_t message[sizeof(struct pocket_key) + 256];
	size_t n = chars ? strlen(chars) : 0;
	if (n > 256)
		n = 256;
	for (int up = 0; up < 2; up++) {
		struct pocket_key k = {!up, code, 0, (uint32_t) n};
		memcpy(message, &k, sizeof(k));
		memcpy(message + sizeof(k), chars, n);
		broadcast(POCKET_KEY, message, sizeof(k) + n);
	}
}

static int parse_screen(const char *size, const char *insets, struct pocket_screen *out)
{
	unsigned width, height;
	double scale = 1;
	if (sscanf(size, "%ux%u@%lf", &width, &height, &scale) < 2 || width == 0 || height == 0)
		return -1;
	struct pocket_screen s = {width, height, (uint32_t) (scale * 1000 + 0.5)};
	if (insets != NULL && sscanf(insets, "%u,%u,%u,%u", &s.inset_top, &s.inset_left, &s.inset_bottom,
	                             &s.inset_right) != 4)
		return -1;
	*out = s;
	return 0;
}

static void set_screen(struct pocket_screen s)
{
	screen = s;
	free(framebuffer);
	framebuffer = calloc((size_t) screen.width * screen.height, 4);
	broadcast(POCKET_SCREEN, &screen, sizeof(screen));
}

static int command(char *line)
{
	char *nl = strchr(line, '\n');
	if (nl)
		*nl = 0;
	char word[32] = "";
	int used = 0;
	sscanf(line, "%31s %n", word, &used);
	const char *rest = line + used;
	float x, y, x2, y2;
	unsigned finger, steps, code;
	char path[1024], chars[256];

	if (!strcmp(word, "tap") && sscanf(rest, "%f %f", &x, &y) == 2) {
		touch(POCKET_TOUCH_BEGAN, 1, x, y);
		usleep(50000);
		touch(POCKET_TOUCH_ENDED, 1, x, y);
	} else if (!strcmp(word, "down") && sscanf(rest, "%u %f %f", &finger, &x, &y) == 3) {
		touch(POCKET_TOUCH_BEGAN, finger, x, y);
	} else if (!strcmp(word, "move") && sscanf(rest, "%u %f %f", &finger, &x, &y) == 3) {
		touch(POCKET_TOUCH_MOVED, finger, x, y);
	} else if (!strcmp(word, "up") && sscanf(rest, "%u %f %f", &finger, &x, &y) == 3) {
		touch(POCKET_TOUCH_ENDED, finger, x, y);
	} else if (!strcmp(word, "drag") && sscanf(rest, "%f %f %f %f %u", &x, &y, &x2, &y2, &steps) == 5) {
		touch(POCKET_TOUCH_BEGAN, 1, x, y);
		for (unsigned i = 1; i <= steps; i++) {
			usleep(16000);
			touch(POCKET_TOUCH_MOVED, 1, x + (x2 - x) * i / steps, y + (y2 - y) * i / steps);
		}
		touch(POCKET_TOUCH_ENDED, 1, x2, y2);
	} else if (!strcmp(word, "text")) {
		broadcast(POCKET_TEXT, rest, strlen(rest));
	} else if (!strcmp(word, "key") && sscanf(rest, "%u", &code) == 1) {
		chars[0] = 0;
		sscanf(rest, "%*u %255s", chars);
		key(code, chars);
	} else if (!strcmp(word, "screen")) {
		char size[64] = "", insets[64] = "";
		struct pocket_screen s;
		int n = sscanf(rest, "%63s %63s", size, insets);
		if (n >= 1 && parse_screen(size, n == 2 ? insets : NULL, &s) == 0)
			set_screen(s);
		else
			printf("error: screen WIDTHxHEIGHT@SCALE [T,L,B,R]\n");
	} else if (!strcmp(word, "pixel") && sscanf(rest, "%f %f", &x, &y) == 2) {
		compose();
		if (x >= 0 && y >= 0 && x < screen.width && y < screen.height) {
			const uint8_t *p = framebuffer + ((size_t) y * screen.width + (size_t) x) * 4;
			printf("pixel %d %d %02x%02x%02x\n", (int) x, (int) y, p[2], p[1], p[0]);
		}
	} else if (!strcmp(word, "shot") && sscanf(rest, "%1023s", path) == 1) {
		printf(write_png(path) == 0 ? "shot %s\n" : "error: cannot write %s\n", path);
	} else if (!strcmp(word, "quit")) {
		return 0;
	} else if (word[0] != 0) {
		printf("error: %s\n", line);
	}
	return 1;
}

int main(int argc, char **argv)
{
	if (argc < 3 || parse_screen(argv[2], argc > 3 ? argv[3] : NULL, &screen) != 0) {
		fprintf(stderr, "usage: %s SOCKET WIDTHxHEIGHT@SCALE [TOP,LEFT,BOTTOM,RIGHT]\n", argv[0]);
		return 2;
	}
	setvbuf(stdout, NULL, _IOLBF, 0);
	framebuffer = calloc((size_t) screen.width * screen.height, 4);
	for (int i = 0; i < MAX_CLIENTS; i++)
		clients[i].fd = -1;

	int listener = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
	struct sockaddr_un address = {.sun_family = AF_UNIX};
	if (strlen(argv[1]) >= sizeof(address.sun_path)) {
		fprintf(stderr, "pocket-host: the socket path is too long\n");
		return 1;
	}
	strcpy(address.sun_path, argv[1]);
	unlink(argv[1]);
	if (bind(listener, (struct sockaddr *) &address, sizeof(address)) != 0 || listen(listener, 8) != 0) {
		fprintf(stderr, "pocket-host: cannot listen on %s: %s\n", argv[1], strerror(errno));
		return 1;
	}
	printf("listening %s %ux%u\n", argv[1], screen.width, screen.height);

	char line[2048];
	int running = 1, input_open = 1;
	while (running) {
		struct pollfd fds[MAX_CLIENTS + 2];
		int map[MAX_CLIENTS + 2], n = 0;
		fds[n] = (struct pollfd) {listener, POLLIN};
		map[n++] = -1;
		if (input_open) {
			fds[n] = (struct pollfd) {0, POLLIN};
			map[n++] = -2;
		}
		for (int i = 0; i < MAX_CLIENTS; i++)
			if (clients[i].fd >= 0) {
				fds[n] = (struct pollfd) {clients[i].fd, POLLIN};
				map[n++] = i;
			}
		if (poll(fds, n, -1) < 0 && errno != EINTR)
			break;
		for (int i = 0; i < n; i++) {
			if (!(fds[i].revents & (POLLIN | POLLHUP | POLLERR)))
				continue;
			if (map[i] == -1) {
				int fd = accept4(listener, NULL, NULL, SOCK_CLOEXEC);
				for (int k = 0; fd >= 0 && k < MAX_CLIENTS; k++)
					if (clients[k].fd < 0) {
						memset(&clients[k], 0, sizeof(clients[k]));
						clients[k].fd = fd;
						fd = -1;
					}
				if (fd >= 0)
					close(fd);
			} else if (map[i] == -2) {
				if (fgets(line, sizeof(line), stdin) == NULL)
					input_open = 0;
				else
					running = command(line);
			} else if (clients[map[i]].fd >= 0) {
				read_client(map[i]);
			}
		}
	}
	unlink(argv[1]);
	return 0;
}
