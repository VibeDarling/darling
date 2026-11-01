/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* Assets.car is a BOMStore: big-endian blocks, and named B+ trees of them.
   CoreUI's own records in it are little-endian. FACETKEYS maps an asset's
   name to its identifier; RENDITIONS maps a rendition key (the values of the
   attributes KEYFORMAT lists: identifier, scale, idiom, appearance, ...) to a
   CSI record: a header, TLVs, then the payload, a compressed bitmap (CELM), a
   color (COLR) or a file (RAWD). Images may also be internal references
   (layout 1003) to a rectangle of a packed atlas (layout 1004).

   The Deepmap2 bitmap decoder follows carfile-go's
   (https://github.com/devcxm/carfile-go, MIT License, Copyright (c) 2026
   devcxm). */

#include "UIAssetCatalog.h"

#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include <lzfse.h>
#include "../../../external/lzfse/src/lzvn_decode_base.h"

enum {
	ATTR_APPEARANCE = 7,
	ATTR_DIM1 = 8,
	ATTR_SCALE = 12,
	ATTR_LOCALIZATION = 13,
	ATTR_IDIOM = 15,
	ATTR_SUBTYPE = 16,
	ATTR_IDENTIFIER = 17,
	ATTR_SIZE_CLASS_H = 20,
	ATTR_SIZE_CLASS_V = 21,
	ATTR_MEMORY_CLASS = 22,
	ATTR_GRAPHICS_CLASS = 23,
	ATTR_DISPLAY_GAMUT = 24,
	ATTR_DEPLOYMENT_TARGET = 25,
	ATTR_GLYPH_WEIGHT = 26,
	ATTR_GLYPH_SIZE = 27,
	ATTR_MAX = 32,
};

enum {
	LAYOUT_INTERNAL_REFERENCE = 1003,
	LAYOUT_PACKED_IMAGE = 1004,
	LAYOUT_COLOR = 1009,
	LAYOUT_MULTISIZE_IMAGE_SET = 1010,
};

enum {
	TLV_INTERNAL_LINK = 1010,
};

struct facet {
	const char *name; /* not terminated; name_length bytes */
	size_t name_length;
	uint16_t identifier;
};

struct rendition {
	uint16_t attrs[ATTR_MAX];
	const uint8_t *csi;
	size_t length;
};

struct uiac_catalog {
	const uint8_t *data;
	size_t size;
	uint32_t block_count;
	const uint8_t *index; /* block table */
	struct facet *facets;
	size_t facet_count;
	struct rendition *renditions;
	size_t rendition_count;
	uint16_t dark_appearance; /* 0 if the catalog has no dark appearance */
};

static uint32_t be32(const uint8_t *p) { return (uint32_t) p[0] << 24 | (uint32_t) p[1] << 16 | (uint32_t) p[2] << 8 | p[3]; }
static uint16_t be16(const uint8_t *p) { return (uint16_t) (p[0] << 8 | p[1]); }
static uint32_t le32(const uint8_t *p) { return (uint32_t) p[3] << 24 | (uint32_t) p[2] << 16 | (uint32_t) p[1] << 8 | p[0]; }
static uint16_t le16(const uint8_t *p) { return (uint16_t) (p[1] << 8 | p[0]); }
static uint64_t le64(const uint8_t *p) { return (uint64_t) le32(p + 4) << 32 | le32(p); }

/* Block I of the BOM, or NULL. */
static const uint8_t *bom_block(uiac_catalog *c, uint32_t i, size_t *length)
{
	if (i >= c->block_count)
		return NULL;
	uint32_t address = be32(c->index + 4 + 8 * i), size = be32(c->index + 8 + 8 * i);
	if ((uint64_t) address + size > c->size)
		return NULL;
	*length = size;
	return c->data + address;
}

static const uint8_t *bom_var(uiac_catalog *c, const char *name, size_t *length)
{
	uint32_t vars = be32(c->data + 24), vars_length = be32(c->data + 28);
	if ((uint64_t) vars + vars_length > c->size || vars_length < 4)
		return NULL;
	const uint8_t *p = c->data + vars, *end = p + vars_length;
	uint32_t count = be32(p);
	p += 4;
	size_t want = strlen(name);
	for (uint32_t i = 0; i < count && p + 5 <= end; i++) {
		uint32_t block = be32(p);
		uint8_t n = p[4];
		if (p + 5 + n > end)
			break;
		if (n == want && memcmp(p + 5, name, n) == 0)
			return bom_block(c, block, length);
		p += 5 + n;
	}
	return NULL;
}

typedef void (*tree_visitor)(uiac_catalog *c, const uint8_t *key, size_t key_length, const uint8_t *value, size_t value_length, void *context);

/* Every entry of the B+ tree NAME, in order. */
static int bom_tree(uiac_catalog *c, const char *name, tree_visitor visit, void *context)
{
	size_t length;
	const uint8_t *tree = bom_var(c, name, &length);
	if (tree == NULL || length < 21 || memcmp(tree, "tree", 4) != 0)
		return 0;
	uint32_t node = be32(tree + 8);
	const uint8_t *b;
	for (int depth = 0;; depth++) {
		if ((b = bom_block(c, node, &length)) == NULL || length < 12 || depth > 64)
			return 0;
		if (be16(b))
			break;
		if (length < 16)
			return 0;
		node = be32(b + 12);
	}
	for (size_t visited = 0; node != 0 && visited < c->block_count; visited++) {
		if ((b = bom_block(c, node, &length)) == NULL || length < 12)
			return 0;
		uint16_t count = be16(b + 2);
		if (12 + 8 * (size_t) count > length)
			return 0;
		for (uint16_t k = 0; k < count; k++) {
			size_t vl, kl;
			const uint8_t *v = bom_block(c, be32(b + 12 + 8 * k), &vl);
			const uint8_t *key = bom_block(c, be32(b + 16 + 8 * k), &kl);
			if (v != NULL && key != NULL)
				visit(c, key, kl, v, vl, context);
		}
		node = be32(b + 4);
	}
	return 1;
}

struct grow {
	void **items;
	size_t *count;
	size_t capacity;
	size_t item_size;
};

static void *grow_push(struct grow *g)
{
	if (*g->count == g->capacity) {
		size_t capacity = g->capacity ? g->capacity * 2 : 256;
		void *items = realloc(*g->items, capacity * g->item_size);
		if (items == NULL)
			return NULL;
		*g->items = items;
		g->capacity = capacity;
	}
	return (char *) *g->items + (*g->count)++ * g->item_size;
}

static void visit_facet(uiac_catalog *c, const uint8_t *key, size_t key_length, const uint8_t *v, size_t vl, void *context)
{
	if (vl < 6)
		return;
	uint16_t count = le16(v + 4);
	for (uint16_t i = 0; i < count && 10 + 4 * (size_t) i <= vl; i++) {
		if (le16(v + 6 + 4 * i) != ATTR_IDENTIFIER)
			continue;
		struct facet *f = grow_push(context);
		if (f != NULL)
			*f = (struct facet) { (const char *) key, key_length, le16(v + 8 + 4 * i) };
		return;
	}
}

struct rendition_context {
	struct grow grow;
	const uint32_t *keyformat;
	uint32_t key_count;
};

static void visit_rendition(uiac_catalog *c, const uint8_t *key, size_t key_length, const uint8_t *v, size_t vl, void *context)
{
	struct rendition_context *rc = context;
	if (vl < 184 || memcmp(v, "ISTC", 4) != 0)
		return;
	struct rendition *r = grow_push(&rc->grow);
	if (r == NULL)
		return;
	memset(r, 0, sizeof(*r));
	for (uint32_t i = 0; i < rc->key_count && 2 * (size_t) i + 2 <= key_length; i++)
		if (rc->keyformat[i] < ATTR_MAX)
			r->attrs[rc->keyformat[i]] = le16(key + 2 * i);
	r->csi = v;
	r->length = vl;
}

static void visit_appearance(uiac_catalog *c, const uint8_t *key, size_t key_length, const uint8_t *v, size_t vl, void *context)
{
	static const char *dark[] = { "UIAppearanceDark", "NSAppearanceNameDarkAqua" };
	for (size_t i = 0; i < sizeof(dark) / sizeof(*dark); i++)
		if (key_length == strlen(dark[i]) && memcmp(key, dark[i], key_length) == 0 && vl >= 2)
			c->dark_appearance = le16(v);
}

static int compare_facets(const void *a, const void *b)
{
	const struct facet *x = a, *y = b;
	size_t n = x->name_length < y->name_length ? x->name_length : y->name_length;
	int r = memcmp(x->name, y->name, n);
	return r != 0 ? r : (x->name_length > y->name_length) - (x->name_length < y->name_length);
}

static int compare_renditions(const void *a, const void *b)
{
	const struct rendition *x = a, *y = b;
	return (int) x->attrs[ATTR_IDENTIFIER] - (int) y->attrs[ATTR_IDENTIFIER];
}

uiac_catalog *uiac_open(const char *path)
{
	int fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return NULL;
	struct stat st;
	void *data = MAP_FAILED;
	if (fstat(fd, &st) == 0 && st.st_size >= 32)
		data = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	close(fd);
	if (data == MAP_FAILED)
		return NULL;

	uiac_catalog *c = calloc(1, sizeof(*c));
	c->data = data;
	c->size = st.st_size;
	uint32_t index = be32(c->data + 16);
	if (memcmp(data, "BOMStore", 8) != 0 || (uint64_t) index + 4 > c->size)
		goto fail;
	c->index = c->data + index;
	c->block_count = be32(c->index);
	if ((uint64_t) index + 4 + 8 * (uint64_t) c->block_count > c->size)
		goto fail;

	size_t length;
	const uint8_t *kf = bom_var(c, "KEYFORMAT", &length);
	if (kf == NULL || length < 12)
		goto fail;
	uint32_t keyformat[64];
	struct rendition_context rc = { { (void **) &c->renditions, &c->rendition_count, 0, sizeof(struct rendition) }, keyformat, le32(kf + 8) };
	if (rc.key_count > 64 || 12 + 4 * (size_t) rc.key_count > length)
		goto fail;
	for (uint32_t i = 0; i < rc.key_count; i++)
		keyformat[i] = le32(kf + 12 + 4 * i);

	struct grow facets = { (void **) &c->facets, &c->facet_count, 0, sizeof(struct facet) };
	bom_tree(c, "FACETKEYS", visit_facet, &facets);
	bom_tree(c, "RENDITIONS", visit_rendition, &rc);
	bom_tree(c, "APPEARANCEKEYS", visit_appearance, NULL);
	qsort(c->facets, c->facet_count, sizeof(struct facet), compare_facets);
	qsort(c->renditions, c->rendition_count, sizeof(struct rendition), compare_renditions);
	return c;

fail:
	uiac_close(c);
	return NULL;
}

void uiac_close(uiac_catalog *c)
{
	if (c == NULL)
		return;
	munmap((void *) c->data, c->size);
	free(c->facets);
	free(c->renditions);
	free(c);
}

static int identifier_for_name(uiac_catalog *c, const char *name, uint16_t *identifier)
{
	struct facet want = { name, strlen(name), 0 };
	struct facet *f = bsearch(&want, c->facets, c->facet_count, sizeof(struct facet), compare_facets);
	if (f == NULL)
		return 0;
	*identifier = f->identifier;
	return 1;
}

int uiac_has_name(uiac_catalog *c, const char *name)
{
	uint16_t identifier;
	return c != NULL && identifier_for_name(c, name, &identifier);
}

struct csi {
	uint32_t flags, width, height, scale;
	char pixel_format[5];
	uint16_t layout;
	const uint8_t *tlv, *payload;
	size_t tlv_length, payload_length;
};

static int parse_csi(const struct rendition *r, struct csi *out)
{
	const uint8_t *v = r->csi;
	out->flags = le32(v + 8);
	out->width = le32(v + 12);
	out->height = le32(v + 16);
	out->scale = le32(v + 20);
	uint32_t format = le32(v + 24);
	for (int i = 0; i < 4; i++)
		out->pixel_format[i] = (char) (format >> (24 - 8 * i));
	out->pixel_format[4] = 0;
	out->layout = le16(v + 36);
	uint32_t tlv_length = le32(v + 168);
	if (184 + (uint64_t) tlv_length > r->length)
		return 0;
	out->tlv = v + 184;
	out->tlv_length = tlv_length;
	out->payload = v + 184 + tlv_length;
	out->payload_length = r->length - 184 - tlv_length;
	return 1;
}

/* The TLV TYPE's value, or NULL. */
static const uint8_t *csi_tlv(const struct csi *csi, uint32_t type, size_t *length)
{
	const uint8_t *p = csi->tlv, *end = p + csi->tlv_length;
	while (end - p >= 8) {
		uint32_t t = le32(p), n = le32(p + 4);
		size_t left = end - p - 8;
		/* Newer catalogs sometimes record the whole record's size, or the
		   value's size shifted left by 11. */
		if (n > left && n >= 8 && n - 8 == left)
			n -= 8;
		if (n > left && (n & 0x7ff) == 0 && (n >> 11) <= left)
			n >>= 11;
		if (n > left)
			return NULL;
		if (t == type) {
			*length = n;
			return p + 8;
		}
		p += 8 + n;
	}
	return NULL;
}

/* How well rendition R suits the request: higher is better, negative unusable. */
static long score(uiac_catalog *c, const struct rendition *r, double scale, int dark)
{
	const uint16_t *a = r->attrs;
	if (a[ATTR_IDIOM] != 0 && a[ATTR_IDIOM] != 1) /* universal and phone */
		return -1;
	if (a[ATTR_SUBTYPE] != 0 || a[ATTR_SIZE_CLASS_H] != 0 || a[ATTR_SIZE_CLASS_V] != 0)
		return -1;
	long s = 0;
	if (dark && c->dark_appearance != 0 && a[ATTR_APPEARANCE] == c->dark_appearance)
		s += 1 << 24;
	else if (a[ATTR_APPEARANCE] != 0)
		return -1;
	if (a[ATTR_LOCALIZATION] == 0)
		s += 1 << 20;
	if (a[ATTR_IDIOM] == 1)
		s += 1 << 19;
	if (a[ATTR_DISPLAY_GAMUT] == 0)
		s += 1 << 18;
	/* The requested scale, else the nearest above, else the nearest below. */
	int want = (int) (scale + 0.5), have = a[ATTR_SCALE];
	if (have == want || have == 0)
		s += 1 << 16;
	else if (have > want)
		s += (1 << 15) - (have - want) * 16;
	else
		s += (1 << 14) - (want - have) * 16;
	s += a[ATTR_DEPLOYMENT_TARGET] & 0xff;
	return s;
}

static const struct rendition *best_rendition(uiac_catalog *c, const char *name, double scale, int dark, int color)
{
	uint16_t identifier;
	if (c == NULL || !identifier_for_name(c, name, &identifier))
		return NULL;
	struct rendition want = { .attrs = { [ATTR_IDENTIFIER] = identifier } };
	struct rendition *hit = bsearch(&want, c->renditions, c->rendition_count, sizeof(struct rendition), compare_renditions);
	if (hit == NULL)
		return NULL;
	struct rendition *first = hit, *end = c->renditions + c->rendition_count;
	while (first > c->renditions && first[-1].attrs[ATTR_IDENTIFIER] == identifier)
		first--;
	const struct rendition *best = NULL;
	long best_score = -1;
	for (struct rendition *r = first; r < end && r->attrs[ATTR_IDENTIFIER] == identifier; r++) {
		struct csi csi;
		if (!parse_csi(r, &csi))
			continue;
		if (color != (csi.layout == LAYOUT_COLOR) || csi.layout == LAYOUT_MULTISIZE_IMAGE_SET)
			continue;
		long s = score(c, r, scale, dark);
		/* A bitmap over the vector source it was rasterized from. */
		if (s >= 0 && (csi.flags & 4) == 0)
			s += 1 << 12;
		if (s > best_score)
			best = r, best_score = s;
	}
	return best;
}

int uiac_color(uiac_catalog *c, const char *name, int dark, double rgba[4])
{
	const struct rendition *r = best_rendition(c, name, 1, dark, 1);
	struct csi csi;
	if (r == NULL || !parse_csi(r, &csi) || csi.payload_length < 16 || memcmp(csi.payload, "RLOC", 4) != 0)
		return 0;
	uint32_t count = le32(csi.payload + 12);
	if (count == 0 || count > 4 || 16 + 8 * (size_t) count > csi.payload_length)
		return 0;
	double components[4];
	for (uint32_t i = 0; i < count; i++) {
		uint64_t bits = le64(csi.payload + 16 + 8 * i);
		memcpy(&components[i], &bits, sizeof(double));
	}
	if (count <= 2) { /* gray, alpha */
		rgba[0] = rgba[1] = rgba[2] = components[0];
		rgba[3] = count == 2 ? components[1] : 1;
	} else {
		memcpy(rgba, components, 3 * sizeof(double));
		rgba[3] = count == 4 ? components[3] : 1;
	}
	return 1;
}

/* Bitmap decoding. */

static uint8_t *lzfse_expand(const uint8_t *src, size_t length, size_t *out_length)
{
	size_t capacity = length * 8 + 4096;
	uint8_t *scratch = malloc(lzfse_decode_scratch_size());
	for (int tries = 0; tries < 8; tries++) {
		uint8_t *dst = malloc(capacity);
		if (dst == NULL)
			break;
		size_t n = lzfse_decode_buffer(dst, capacity, src, length, scratch);
		if (n != 0 && n < capacity) {
			free(scratch);
			*out_length = n;
			return dst;
		}
		free(dst);
		if (n == 0 && tries > 2)
			break;
		capacity *= 4;
	}
	free(scratch);
	return NULL;
}

/* A bare LZVN stream, which records no size: at most LIMIT bytes. */
static uint8_t *lzvn_expand(const uint8_t *src, size_t length, size_t limit, size_t *out_length)
{
	uint8_t *dst = malloc(limit + 64);
	if (dst == NULL)
		return NULL;
	lzvn_decoder_state state;
	memset(&state, 0, sizeof(state));
	state.src = src;
	state.src_end = src + length;
	state.dst = state.dst_begin = dst;
	state.dst_end = dst + limit + 64;
	lzvn_decode(&state);
	*out_length = state.dst - dst;
	if (!state.end_of_stream || *out_length > limit) {
		free(dst);
		return NULL;
	}
	return dst;
}

static int is_lzfse(const uint8_t *p, size_t length)
{
	return length >= 4 && p[0] == 'b' && p[1] == 'v' && p[2] == 'x' && (p[3] == '2' || p[3] == '-' || p[3] == 'n' || p[3] == '1');
}

static uint8_t *segment_expand(const uint8_t *src, size_t length, size_t limit, size_t *out_length)
{
	return is_lzfse(src, length) ? lzfse_expand(src, length, out_length) : lzvn_expand(src, length, limit, out_length);
}

struct dm_layout {
	int components, bytes_per_component, alpha;
};

static int dm_layout_for(uint8_t format, struct dm_layout *l)
{
	switch (format) {
	case 1: *l = (struct dm_layout) { 1, 1, 0 }; return 1;
	case 2: *l = (struct dm_layout) { 2, 1, 1 }; return 1;
	case 3: *l = (struct dm_layout) { 3, 1, 0 }; return 1;
	case 4: *l = (struct dm_layout) { 4, 1, 1 }; return 1;
	case 20: *l = (struct dm_layout) { 4, 2, 1 }; return 1;
	}
	return 0;
}

static int abs_int(int v) { return v < 0 ? -v : v; }

static void dm_unpredict_row(int16_t *row, const int16_t *previous, size_t n, uint8_t predictor)
{
	switch (predictor) {
	case 1:
		for (int k = 0; k < 3; k++)
			row[k] += previous[k];
		for (size_t i = 3; i < n; i += 3) {
			const int16_t *predict = row + i - 3;
			if (abs_int(previous[i] - previous[i - 3]) > abs_int(row[i - 3] - previous[i - 3]))
				predict = previous + i;
			for (int k = 0; k < 3; k++)
				row[i + k] += predict[k];
		}
		break;
	case 2:
		for (size_t i = 3; i < n; i++)
			row[i] += row[i - 3];
		break;
	case 3:
		for (size_t i = 0; i < n; i++)
			row[i] += previous[i];
		break;
	case 4:
		for (int k = 0; k < 3; k++)
			row[k] += previous[k];
		for (size_t i = 3; i < n; i++) {
			int32_t sum = (int32_t) row[i - 3] + previous[i] + 1;
			if (sum < 0)
				sum++;
			row[i] += (int16_t) (sum >> 1);
		}
		break;
	}
}

static uint16_t dm_scale_wide(int16_t v)
{
	return v < 0 ? 0 : v >= 512 ? 10000 : (uint16_t) (((uint32_t) v * 10000 + 256) / 512);
}

/* The "default" Deepmap encoding: per row a predictor, residuals in two byte
   planes (zigzag-signed), YCoCg-R colour, and alpha as its own plane. */
static int dm_default_pixels(const uint8_t *src, size_t length, int width, int height, struct dm_layout l, uint8_t *pixels)
{
	size_t count = (size_t) width * height;
	int residual = l.components - (l.alpha ? 1 : 0);
	size_t alpha_bytes = l.alpha ? count : 0;
	size_t needed = alpha_bytes + height + 2 * residual * count;
	if (length < needed || length - needed >= 16)
		return 0;
	const uint8_t *alpha = src, *predictors = src + alpha_bytes;
	const uint8_t *first = predictors + height, *second = first + residual * count;
	int16_t *previous = calloc(width * 3, sizeof(int16_t)), *current = calloc(width * 3, sizeof(int16_t));
	size_t bpp = l.components * l.bytes_per_component;
	for (int row = 0; row < height; row++) {
		memset(current, 0, width * 3 * sizeof(int16_t));
		for (int x = 0; x < width; x++)
			for (int k = 0; k < residual; k++) {
				size_t i = ((size_t) row * width + x) * residual + k;
				uint16_t encoded = second[i] | first[i] << 8;
				int16_t value = (int16_t) (encoded >> 1);
				current[x * 3 + k] = encoded & 1 ? -value : value;
			}
		dm_unpredict_row(current, previous, width * 3, predictors[row]);
		for (int x = 0; x < width; x++) {
			const int16_t *s = current + x * 3;
			uint8_t *d = pixels + ((size_t) row * width + x) * bpp;
			uint8_t a = l.alpha ? alpha[(size_t) row * width + x] : 255;
			if (residual == 1) {
				d[0] = (uint8_t) s[0];
				if (l.alpha)
					d[1] = a;
				continue;
			}
			int16_t y = s[0], co = (int16_t) ((uint16_t) s[1] << 1), cg = (int16_t) ((uint16_t) s[2] << 1);
			int16_t t = (int16_t) (y - cg / 2);
			int16_t c1 = (int16_t) (t + cg), c2 = (int16_t) (t - co / 2), c0 = (int16_t) (c2 + co);
			if (l.bytes_per_component == 1) {
				d[0] = (uint8_t) c0, d[1] = (uint8_t) c1, d[2] = (uint8_t) c2;
				if (l.alpha)
					d[3] = a;
			} else {
				uint16_t w[4] = { dm_scale_wide(c2), dm_scale_wide(c1), dm_scale_wide(c0), (uint16_t) (((uint32_t) a * 10000 + 127) / 255) };
				for (int k = 0; k < 4; k++)
					d[2 * k] = (uint8_t) w[k], d[2 * k + 1] = (uint8_t) (w[k] >> 8);
			}
		}
		int16_t *swap = previous;
		previous = current, current = swap;
	}
	free(previous);
	free(current);
	return 1;
}

struct bitmap {
	uint8_t format;
	struct dm_layout layout;
	int width, height;
	uint8_t *pixels;
	size_t length;
};

static int bitmap_append(struct bitmap *b, const uint8_t *pixels, size_t length, int rows)
{
	uint8_t *grown = realloc(b->pixels, b->length + length);
	if (grown == NULL)
		return 0;
	memcpy(grown + b->length, pixels, length);
	b->pixels = grown;
	b->length += length;
	b->height += rows;
	return 1;
}

static int dmp2_decode(const uint8_t *src, size_t length, struct bitmap *out);

static int dmp2_decode_kcbc(const uint8_t *src, size_t length, struct bitmap *out)
{
	memset(out, 0, sizeof(*out));
	size_t offset = 0;
	for (int segment = 0; offset < length; segment++) {
		if (length - offset < 20 || memcmp(src + offset, "KCBC", 4) != 0)
			return 0;
		uint32_t rows = le32(src + offset + 12), n = le32(src + offset + 16);
		if (n > length - offset - 20)
			return 0;
		struct bitmap part;
		if (!dmp2_decode(src + offset + 20, n, &part) || part.height != (int) rows)
			goto fail_part;
		if (segment == 0) {
			*out = part;
		} else {
			int ok = part.width == out->width && part.format == out->format && bitmap_append(out, part.pixels, part.length, part.height);
			free(part.pixels);
			if (!ok)
				return 0;
		}
		offset += 20 + n;
		continue;
	fail_part:
		free(part.pixels);
		return 0;
	}
	return out->pixels != NULL;
}

static int dmp2_decode(const uint8_t *src, size_t length, struct bitmap *out)
{
	memset(out, 0, sizeof(*out));
	if (length >= 4 && memcmp(src, "KCBC", 4) == 0)
		return dmp2_decode_kcbc(src, length, out);
	if (length < 28 || le32(src) != 1)
		return 0;
	uint64_t outer = le64(src + 8);
	if (outer > length - 16 || 16 + outer < 28 || memcmp(src + 16, "dmp2", 4) != 0 || src[21] != 1)
		return 0;
	size_t end = 16 + outer;
	uint8_t method = src[20];
	out->format = src[23];
	if (!dm_layout_for(out->format, &out->layout))
		return 0;
	out->width = le16(src + 24);
	int height = le16(src + 26);
	if (out->width == 0 || height == 0)
		return 0;
	struct dm_layout l = out->layout;
	size_t bpp = l.components * l.bytes_per_component;
	size_t pixel_bytes = (size_t) out->width * height * bpp;

	if (method == 1) { /* raw */
		if (end - 28 != pixel_bytes)
			return 0;
		out->pixels = malloc(pixel_bytes);
		memcpy(out->pixels, src + 28, pixel_bytes);
		out->length = pixel_bytes;
		out->height = height;
		return 1;
	}
	if (end < 32)
		return 0;
	uint32_t descriptor = le32(src + 28);
	const uint8_t *payload = src + 32;
	size_t payload_length = end - 32;

	if (method == 2 || method == 3) { /* default; lossless */
		/* Segments: the first one's length is the descriptor, each later
		   one's precedes it. */
		const uint8_t *p = payload, *stop = payload + payload_length;
		uint32_t n = descriptor;
		int residual = l.components - (l.alpha ? 1 : 0);
		size_t row_encoded = (l.alpha ? out->width : 0) + 1 + 2 * residual * (size_t) out->width;
		for (;;) {
			if (n == 0 || n > (size_t) (stop - p))
				goto fail;
			size_t limit = method == 2 ? ((row_encoded * height + 15) & ~(size_t) 15) : pixel_bytes - out->length;
			size_t decoded_length;
			uint8_t *decoded = segment_expand(p, n, limit, &decoded_length);
			if (decoded == NULL)
				goto fail;
			int ok;
			if (method == 2) {
				int rows = (int) (decoded_length / row_encoded);
				uint8_t *pixels = rows > 0 && decoded_length - rows * row_encoded < 16 ? malloc((size_t) out->width * rows * bpp) : NULL;
				ok = pixels != NULL && dm_default_pixels(decoded, decoded_length, out->width, rows, l, pixels)
					&& bitmap_append(out, pixels, (size_t) out->width * rows * bpp, rows);
				free(pixels);
			} else {
				size_t row_bytes = (size_t) out->width * bpp;
				ok = decoded_length % row_bytes == 0 && bitmap_append(out, decoded, decoded_length, (int) (decoded_length / row_bytes));
			}
			free(decoded);
			if (!ok)
				goto fail;
			p += n;
			if (p == stop)
				return 1;
			if (stop - p < 4)
				goto fail;
			n = le32(p);
			p += 4;
		}
	}
	if (method == 4) { /* palette */
		size_t colors = descriptor & 0xffff, palette_components = descriptor >> 16;
		if (colors == 0 || colors > 256 || palette_components == 0 || palette_components > (size_t) l.components)
			return 0;
		size_t palette_bytes = colors * bpp;
		if (palette_bytes + 4 > payload_length)
			return 0;
		uint32_t encoded = le32(payload + palette_bytes);
		if (encoded > payload_length - palette_bytes - 4)
			return 0;
		size_t count = (size_t) out->width * height;
		size_t separate = l.components - palette_components;
		size_t plane_bytes = count * separate * l.bytes_per_component;
		size_t decoded_length;
		uint8_t *decoded = segment_expand(payload + palette_bytes + 4, encoded, plane_bytes + count, &decoded_length);
		if (decoded == NULL || decoded_length != plane_bytes + count) {
			free(decoded);
			return 0;
		}
		out->pixels = malloc(count * bpp);
		const uint8_t *indices = decoded + plane_bytes;
		for (size_t i = 0; i < count; i++) {
			if (indices[i] >= colors) {
				free(decoded);
				goto fail;
			}
			memcpy(out->pixels + i * bpp, payload + indices[i] * bpp, bpp);
			for (size_t k = 0; k < separate; k++)
				memcpy(out->pixels + i * bpp + (palette_components + k) * l.bytes_per_component,
				       decoded + k * count * l.bytes_per_component + i * l.bytes_per_component, l.bytes_per_component);
		}
		free(decoded);
		out->length = count * bpp;
		out->height = height;
		return 1;
	}
fail:
	free(out->pixels);
	out->pixels = NULL;
	return 0;
}

static int bytes_per_pixel(const char *format)
{
	if (strcmp(format, "ARGB") == 0)
		return 4;
	if (strcmp(format, "GA8 ") == 0)
		return 2;
	if (strcmp(format, "RGBW") == 0)
		return 8;
	return 0;
}

/* PIXELS (tightly packed, in the CSI's pixel format) as the 8-bit pixels
   uiac_image describes. Takes PIXELS. */
static int finish_bitmap(uiac_image *out, const struct csi *csi, uint8_t *pixels, uint32_t width, uint32_t height)
{
	out->width = width;
	out->height = height;
	out->scale = csi->scale ? csi->scale / 100.0 : 1;
	out->template_image = 0;
	if (strcmp(csi->pixel_format, "GA8 ") == 0) {
		out->kind = UIAC_BITMAP_GRAY;
		out->row_bytes = (size_t) width * 2;
		out->bytes = pixels;
	} else if (strcmp(csi->pixel_format, "ARGB") == 0) {
		out->kind = UIAC_BITMAP_BGRA;
		out->row_bytes = (size_t) width * 4;
		out->bytes = pixels;
	} else { /* RGBW: 16-bit extended-range components, 10000 = 1.0 */
		size_t count = (size_t) width * height;
		uint8_t *narrow = malloc(count * 4);
		for (size_t i = 0; i < count * 4; i++) {
			uint16_t v = le16(pixels + 2 * i);
			narrow[i] = v >= 10000 ? 255 : (uint8_t) (((uint32_t) v * 255 + 5000) / 10000);
		}
		free(pixels);
		out->kind = UIAC_BITMAP_BGRA;
		out->row_bytes = (size_t) width * 4;
		out->bytes = narrow;
	}
	out->length = out->row_bytes * height;
	return 1;
}

/* Rows of ROW bytes, possibly padded, as tight rows of TIGHT bytes. */
static uint8_t *strip_padding(uint8_t *pixels, size_t length, uint32_t height, size_t tight)
{
	if (length == tight * height)
		return pixels;
	if (height == 0 || length % height != 0 || length / height < tight) {
		free(pixels);
		return NULL;
	}
	size_t row = length / height;
	for (uint32_t y = 0; y < height; y++)
		memmove(pixels + y * tight, pixels + y * row, tight);
	return pixels;
}

static int decode_celm(const struct csi *csi, uiac_image *out)
{
	const uint8_t *p = csi->payload;
	if (csi->payload_length < 16 || memcmp(p, "MLEC", 4) != 0)
		return 0;
	uint32_t compression = le32(p + 8);
	const uint8_t *data = p + 16;
	size_t length = csi->payload_length - 16;
	int bpp = bytes_per_pixel(csi->pixel_format);
	if (bpp == 0 || csi->width == 0 || csi->height == 0)
		return 0;
	size_t tight = (size_t) csi->width * bpp;

	if (compression == 11 || compression == 10) {
		struct bitmap b;
		if (compression == 10 || !dmp2_decode(data, length, &b))
			return 0;
		int want = bpp == 4 ? 4 : bpp == 2 ? 2 : 20;
		if (b.format != want || (uint32_t) b.width != csi->width || (uint32_t) b.height != csi->height) {
			free(b.pixels);
			return 0;
		}
		return finish_bitmap(out, csi, b.pixels, csi->width, csi->height);
	}
	if (compression == 0) {
		uint8_t *pixels = malloc(length);
		memcpy(pixels, data, length);
		pixels = strip_padding(pixels, length, csi->height, tight);
		return pixels != NULL && finish_bitmap(out, csi, pixels, csi->width, csi->height);
	}
	if (compression == 4) {
		if (length >= 4 && memcmp(data, "KCBC", 4) == 0) {
			uint8_t *pixels = malloc(tight * csi->height);
			size_t offset = 0;
			uint32_t rows = 0;
			while (rows < csi->height) {
				if (length - offset < 20 || memcmp(data + offset, "KCBC", 4) != 0)
					goto kcbc_fail;
				uint32_t chunk = le32(data + offset + 12), n = le32(data + offset + 16);
				if (chunk == 0 || chunk > csi->height - rows || n > length - offset - 20)
					goto kcbc_fail;
				size_t decoded_length;
				uint8_t *decoded = lzfse_expand(data + offset + 20, n, &decoded_length);
				if (decoded == NULL || decoded_length % chunk != 0 || decoded_length / chunk < tight) {
					free(decoded);
					goto kcbc_fail;
				}
				size_t row = decoded_length / chunk;
				for (uint32_t y = 0; y < chunk; y++)
					memcpy(pixels + (rows + y) * tight, decoded + y * row, tight);
				free(decoded);
				rows += chunk;
				offset += 20 + n;
			}
			return finish_bitmap(out, csi, pixels, csi->width, csi->height);
		kcbc_fail:
			free(pixels);
			return 0;
		}
		size_t decoded_length;
		uint8_t *pixels = lzfse_expand(data, length, &decoded_length);
		if (pixels == NULL)
			return 0;
		pixels = strip_padding(pixels, decoded_length, csi->height, tight);
		return pixels != NULL && finish_bitmap(out, csi, pixels, csi->width, csi->height);
	}
	return 0;
}

static int decode_rendition(uiac_catalog *c, const struct rendition *r, uiac_image *out, int depth)
{
	struct csi csi;
	if (!parse_csi(r, &csi))
		return 0;
	memset(out, 0, sizeof(*out));
	if (csi.layout == LAYOUT_INTERNAL_REFERENCE && depth == 0) {
		/* A rectangle of a packed atlas: the link names its rendition key. */
		size_t n;
		const uint8_t *link = csi_tlv(&csi, TLV_INTERNAL_LINK, &n);
		if (link == NULL || n < 30)
			return 0;
		uint32_t x = le32(link + 8), y = le32(link + 12), w = le32(link + 16), h = le32(link + 20);
		uint32_t key_length = le32(link + 26);
		if (key_length > n - 30)
			return 0;
		struct rendition want = { 0 };
		for (uint32_t i = 0; i + 4 <= key_length; i += 4) {
			uint16_t attr = le16(link + 30 + i), value = le16(link + 32 + i);
			if (attr == 0 && value == 0)
				break;
			if (attr < ATTR_MAX)
				want.attrs[attr] = value;
		}
		struct rendition *hit = bsearch(&want, c->renditions, c->rendition_count, sizeof(struct rendition), compare_renditions);
		if (hit == NULL)
			return 0;
		while (hit > c->renditions && hit[-1].attrs[ATTR_IDENTIFIER] == want.attrs[ATTR_IDENTIFIER])
			hit--;
		for (; hit < c->renditions + c->rendition_count && hit->attrs[ATTR_IDENTIFIER] == want.attrs[ATTR_IDENTIFIER]; hit++) {
			if (memcmp(hit->attrs, want.attrs, sizeof(want.attrs)) != 0)
				continue;
			uiac_image atlas;
			if (!decode_rendition(c, hit, &atlas, depth + 1))
				return 0;
			int bpp = atlas.kind == UIAC_BITMAP_GRAY ? 2 : 4;
			if (atlas.kind == UIAC_ENCODED || x + w > atlas.width || y + h > atlas.height || w == 0 || h == 0) {
				uiac_image_free(&atlas);
				return 0;
			}
			/* The rectangle is in the atlas's flipped (bottom-up) coordinates. */
			y = atlas.height - y - h;
			*out = atlas;
			out->width = w;
			out->height = h;
			out->row_bytes = (size_t) w * bpp;
			out->length = out->row_bytes * h;
			out->bytes = malloc(out->length);
			for (uint32_t row = 0; row < h; row++)
				memcpy(out->bytes + row * out->row_bytes, atlas.bytes + (y + row) * atlas.row_bytes + (size_t) x * bpp, out->row_bytes);
			out->scale = csi.scale ? csi.scale / 100.0 : atlas.scale;
			uiac_image_free(&atlas);
			return 1;
		}
		return 0;
	}
	if (csi.payload_length >= 12 && memcmp(csi.payload, "DWAR", 4) == 0) {
		/* A file: PNG, JPEG, HEIF, PDF or SVG. */
		uint32_t n = le32(csi.payload + 8);
		if (n > csi.payload_length - 12)
			return 0;
		out->kind = UIAC_ENCODED;
		out->bytes = malloc(n);
		memcpy(out->bytes, csi.payload + 12, n);
		out->length = n;
		out->width = csi.width;
		out->height = csi.height;
		out->scale = csi.scale ? csi.scale / 100.0 : 1;
		return 1;
	}
	return decode_celm(&csi, out);
}

int uiac_image_named(uiac_catalog *c, const char *name, double scale, int dark, uiac_image *out)
{
	const struct rendition *r = best_rendition(c, name, scale, dark, 0);
	return r != NULL && decode_rendition(c, r, out, 0);
}

void uiac_image_free(uiac_image *image)
{
	free(image->bytes);
	image->bytes = NULL;
}
