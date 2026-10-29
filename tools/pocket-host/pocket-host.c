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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <zlib.h>

#include "pocket-server.h"

static struct pocket_server *server;
static struct pocket_screen screen;
static uint8_t *framebuffer; // BGRA, like the apps' buffers

static void compose(void)
{
	pocket_server_compose(server, framebuffer, (size_t) screen.width * 4, 0);
}

static void log_line(void *context, const char *line)
{
	printf("%s\n", line);
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

static void touch(uint32_t phase, uint32_t finger, float x, float y)
{
	pocket_server_touch(server, phase, finger, x, y, pocket_server_now());
}

static void key(uint32_t code, const char *chars)
{
	size_t n = chars ? strlen(chars) : 0;
	pocket_server_key(server, 1, code, 0, chars, n);
	pocket_server_key(server, 0, code, 0, chars, n);
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
	pocket_server_set_screen(server, &screen);
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
		pocket_server_text(server, rest, strlen(rest));
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

	struct pocket_server_events events = {.log = log_line};
	server = pocket_server_listen(argv[1], &screen, &events);
	if (server == NULL) {
		fprintf(stderr, "pocket-host: cannot listen on %s: %s\n", argv[1], strerror(errno));
		return 1;
	}
	printf("listening %s %ux%u\n", argv[1], screen.width, screen.height);

	char line[2048];
	int running = 1, input = 0;
	while (running) {
		int ready = pocket_server_poll(server, input, -1);
		if (ready < 0)
			break;
		if (ready) {
			if (fgets(line, sizeof(line), stdin) == NULL)
				input = -1;
			else
				running = command(line);
		}
	}
	pocket_server_close(server);
	return 0;
}
