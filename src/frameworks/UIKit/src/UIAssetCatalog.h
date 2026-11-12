/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* A reader for compiled asset catalogs (Assets.car), the CoreUI files actool
   makes of an app's .xcassets: its named colors, and its images decoded to
   pixels. Plain C, so that it can be tested outside Darling. */

#ifndef UIASSETCATALOG_H
#define UIASSETCATALOG_H

#include <stddef.h>
#include <stdint.h>

typedef struct uiac_catalog uiac_catalog;

uiac_catalog *uiac_open(const char *path);
void uiac_close(uiac_catalog *catalog);

/* The color NAME, as red, green, blue and alpha. Returns 0 if the catalog has
   no such color. */
int uiac_color(uiac_catalog *catalog, const char *name, int dark, double rgba[4]);

enum {
	UIAC_BITMAP_BGRA, /* 4 bytes a pixel: blue, green, red, alpha; premultiplied */
	UIAC_BITMAP_GRAY, /* 2 bytes a pixel: gray, alpha; premultiplied */
	UIAC_ENCODED,     /* an image file's bytes (PNG, JPEG, HEIF, PDF, SVG) */
};

typedef struct {
	int kind;
	uint32_t width, height; /* pixels */
	double scale;
	size_t row_bytes;
	uint8_t *bytes; /* the pixels, or the encoded file */
	size_t length;
	int template_image;
	/* Cap insets from the image set's slicing, in pixels (top, left, bottom,
	   right); all zero if it has none. */
	uint32_t insets[4];
	int resizing_tile;
} uiac_image;

/* The image NAME's rendition best suited to SCALE, decoded. Returns 0 if the
   catalog has no such image or its rendition can't be decoded. Free what it
   fills with uiac_image_free. */
int uiac_image_named(uiac_catalog *catalog, const char *name, double scale, int dark, uiac_image *out);
void uiac_image_free(uiac_image *image);

/* Whether the catalog names NAME at all. */
int uiac_has_name(uiac_catalog *catalog, const char *name);

#endif
