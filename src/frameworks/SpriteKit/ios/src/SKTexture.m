/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

#import "SKInternal.h"

/* SKView.m: textures in the views' shared OpenGL ES context. */
unsigned SKGLUploadImage(CGImageRef image);
void SKGLDeleteTexture(unsigned name);

@implementation SKTexture {
	/* A subtexture's parent, which has the pixels; nil for a whole one. */
	SKTexture *_parent;
	/* Loaded when first needed, from _imageName. */
	NSString *_imageName;
	CGImageRef _image;
	CGFloat _scale;
	BOOL _loaded;
	CGRect _rect;
	SKTextureFilteringMode _filteringMode;
	BOOL _usesMipmaps;
	unsigned _glName;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_rect = CGRectMake(0, 0, 1, 1);
		_scale = 1;
		_filteringMode = SKTextureFilteringLinear;
	}
	return self;
}

+ (instancetype)textureWithImageNamed:(NSString *)name
{
	SKTexture *texture = [self new];
	texture->_imageName = [name copy];
	return texture;
}

+ (instancetype)sk_textureWithImage:(CGImageRef)image scale:(CGFloat)scale
{
	SKTexture *texture = [self new];
	texture->_image = CGImageRetain(image);
	texture->_scale = scale > 0 ? scale : 1;
	texture->_loaded = YES;
	return texture;
}

+ (instancetype)textureWithCGImage:(CGImageRef)image
{
	return [self sk_textureWithImage:image scale:1];
}

+ (instancetype)textureWithImage:(UIImage *)image
{
	return [self sk_textureWithImage:[image CGImage] scale:[image scale]];
}

+ (instancetype)textureWithRect:(CGRect)rect inTexture:(SKTexture *)texture
{
	SKTexture *sub = [self new];
	SKTexture *root = texture->_parent ?: texture;
	CGRect parentRect = texture->_parent != nil ? texture->_rect : CGRectMake(0, 0, 1, 1);
	sub->_parent = root;
	sub->_rect = CGRectMake(parentRect.origin.x + rect.origin.x * parentRect.size.width,
		parentRect.origin.y + rect.origin.y * parentRect.size.height,
		rect.size.width * parentRect.size.width, rect.size.height * parentRect.size.height);
	sub->_filteringMode = texture->_filteringMode;
	return sub;
}

static CGImageRef SKImageFromPixels(NSData *data, CGSize size, BOOL flipped)
{
	size_t width = (size_t)size.width, height = (size_t)size.height;
	if (width == 0 || height == 0 || data.length < width * height * 4)
		return NULL;
	NSMutableData *pixels = [data mutableCopy];
	/* SpriteKit's pixel data is bottom row first, unless flipped. */
	if (!flipped) {
		uint8_t *bytes = pixels.mutableBytes;
		const uint8_t *source = data.bytes;
		for (size_t row = 0; row < height; row++)
			memcpy(bytes + row * width * 4, source + (height - 1 - row) * width * 4, width * 4);
	}
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGImageRef image = CGImageCreate(width, height, 8, 32, width * 4, space,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, provider, NULL, false, kCGRenderingIntentDefault);
	CGColorSpaceRelease(space);
	CGDataProviderRelease(provider);
	return image;
}

+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size
{
	return [self textureWithData:pixelData size:size flipped:NO];
}

+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size flipped:(BOOL)flipped
{
	CGImageRef image = SKImageFromPixels(pixelData, size, flipped);
	SKTexture *texture = [self sk_textureWithImage:image scale:1];
	CGImageRelease(image);
	return texture;
}

+ (instancetype)textureWithData:(NSData *)pixelData size:(CGSize)size rowLength:(unsigned int)rowLength alignment:(unsigned int)alignment
{
	return [self textureWithData:pixelData size:size flipped:NO];
}

- (void)dealloc
{
	if (_glName != 0)
		SKGLDeleteTexture(_glName);
	CGImageRelease(_image);
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if (_imageName != nil)
		[coder encodeObject:_imageName forKey:@"_imgName"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	if (self != nil)
		_imageName = [[coder decodeObjectForKey:@"_imgName"] copy];
	return self;
}

- (void)sk_load
{
	if (_loaded)
		return;
	_loaded = YES;
	UIImage *image = _imageName != nil ? [UIImage imageNamed:_imageName] : nil;
	if (image == nil) {
		NSLog(@"SKTexture: Error loading image resource: \"%@\"", _imageName);
		return;
	}
	_image = CGImageRetain([image CGImage]);
	_scale = [image scale] > 0 ? [image scale] : 1;
}

- (CGImageRef)sk_image
{
	if (_parent != nil)
		return [_parent sk_image];
	[self sk_load];
	return _image;
}

- (CGRect)sk_rect
{
	return _rect;
}

- (unsigned)sk_glTexture
{
	if (_parent != nil)
		return [_parent sk_glTexture];
	if (_glName == 0) {
		CGImageRef image = [self sk_image];
		if (image != NULL)
			_glName = SKGLUploadImage(image);
	}
	return _glName;
}

- (CGRect)textureRect
{
	return _rect;
}

- (CGSize)size
{
	SKTexture *root = _parent ?: self;
	CGImageRef image = [root sk_image];
	if (image == NULL)
		return _parent == nil && _imageName != nil ? CGSizeMake(128, 128) : CGSizeZero;
	CGFloat scale = root->_scale;
	return CGSizeMake(CGImageGetWidth(image) / scale * _rect.size.width, CGImageGetHeight(image) / scale * _rect.size.height);
}

- (SKTextureFilteringMode)filteringMode { return _filteringMode; }
- (void)setFilteringMode:(SKTextureFilteringMode)mode { _filteringMode = mode; }
- (BOOL)usesMipmaps { return _usesMipmaps; }
- (void)setUsesMipmaps:(BOOL)uses { _usesMipmaps = uses; }

- (CGImageRef)CGImage
{
	CGImageRef image = [self sk_image];
	if (image == NULL)
		return NULL;
	if (CGRectEqualToRect(_rect, CGRectMake(0, 0, 1, 1)))
		return CGImageRetain(image);
	size_t w = CGImageGetWidth(image), h = CGImageGetHeight(image);
	CGRect crop = CGRectMake(_rect.origin.x * w, (1 - _rect.origin.y - _rect.size.height) * h, _rect.size.width * w, _rect.size.height * h);
	return CGImageCreateWithImageInRect(image, CGRectIntegral(crop));
}

+ (void)preloadTextures:(NSArray<SKTexture *> *)textures withCompletionHandler:(void (^)(void))completionHandler
{
	for (SKTexture *texture in textures)
		[texture sk_image];
	if (completionHandler != nil)
		dispatch_async(dispatch_get_main_queue(), completionHandler);
}

- (void)preloadWithCompletionHandler:(void (^)(void))completionHandler
{
	[SKTexture preloadTextures:@[ self ] withCompletionHandler:completionHandler];
}

- (NSString *)description
{
	CGSize size = [self size];
	return [NSString stringWithFormat:@"<SKTexture> '%@' (%g x %g)", _imageName ?: [_parent description], size.width, size.height];
}

@end

#pragma mark Atlases

@implementation SKTextureAtlas {
	NSString *_name;
	/* Texture names, with and without their extension, to textures. */
	NSMutableDictionary<NSString *, SKTexture *> *_textures;
	NSArray<NSString *> *_textureNames;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

static CGRect SKRectFromString(NSString *string)
{
	CGFloat v[4] = { 0, 0, 0, 0 };
	NSScanner *scanner = [NSScanner scannerWithString:string];
	NSCharacterSet *skip = [NSCharacterSet characterSetWithCharactersInString:@"{}, "];
	for (int i = 0; i < 4; i++) {
		[scanner scanCharactersFromSet:skip intoString:NULL];
		double d = 0;
		if (![scanner scanDouble:&d])
			break;
		v[i] = d;
	}
	return CGRectMake(v[0], v[1], v[2], v[3]);
}

static NSString *SKTextureKey(NSString *name)
{
	NSString *base = [name stringByDeletingPathExtension];
	/* name@2x.png is name. */
	NSRange at = [base rangeOfString:@"@" options:NSBackwardsSearch];
	if (at.location != NSNotFound)
		base = [base substringToIndex:at.location];
	return base;
}

/* A compiled atlas, name.atlasc: name.plist lists each sheet and its sprites. */
- (BOOL)sk_loadCompiled:(NSString *)directory
{
	NSString *plist = nil;
	for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL])
		if ([[file pathExtension] isEqualToString:@"plist"])
			plist = [directory stringByAppendingPathComponent:file];
	NSDictionary *info = plist != nil ? [NSDictionary dictionaryWithContentsOfFile:plist] : nil;
	NSArray *sheets = info[@"images"];
	if (![sheets isKindOfClass:[NSArray class]])
		return NO;
	for (NSDictionary *sheet in sheets) {
		NSString *path = [directory stringByAppendingPathComponent:sheet[@"path"]];
		UIImage *image = [UIImage imageWithContentsOfFile:path];
		if (image == nil)
			continue;
		CGFloat scale = [sheet[@"path"] rangeOfString:@"@3x"].location != NSNotFound ? 3 : [sheet[@"path"] rangeOfString:@"@2x"].location != NSNotFound ? 2 : 1;
		SKTexture *whole = [SKTexture sk_textureWithImage:[image CGImage] scale:scale];
		CGFloat w = CGImageGetWidth([image CGImage]), h = CGImageGetHeight([image CGImage]);
		for (NSDictionary *sprite in sheet[@"subimages"]) {
			CGRect r = SKRectFromString(sprite[@"textureRect"]);
			/* Rotated sprites aren't turned back here. */
			if ([sprite[@"textureRotated"] boolValue])
				r.size = CGSizeMake(r.size.height, r.size.width);
			CGRect unit = CGRectMake(r.origin.x / w, 1 - (r.origin.y + r.size.height) / h, r.size.width / w, r.size.height / h);
			SKTexture *texture = [SKTexture textureWithRect:unit inTexture:whole];
			_textures[SKTextureKey(sprite[@"name"])] = texture;
		}
	}
	return YES;
}

/* An atlas left as a folder of images. */
- (void)sk_loadFolder:(NSString *)directory
{
	for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL]) {
		NSString *key = SKTextureKey(file);
		if (_textures[key] != nil)
			continue;
		UIImage *image = [UIImage imageWithContentsOfFile:[directory stringByAppendingPathComponent:file]];
		if (image != nil)
			_textures[key] = [SKTexture textureWithImage:image];
	}
}

+ (instancetype)atlasNamed:(NSString *)name
{
	SKTextureAtlas *atlas = [self new];
	atlas->_name = [name copy];
	atlas->_textures = [NSMutableDictionary dictionary];
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *compiled = [bundle pathForResource:name ofType:@"atlasc"];
	NSString *folder = [bundle pathForResource:name ofType:@"atlas"];
	if (compiled == nil || ![atlas sk_loadCompiled:compiled]) {
		if (folder != nil)
			[atlas sk_loadFolder:folder];
	}
	/* Otherwise its sprites are in the asset catalog, under their own
	   names, and are found when asked for. */
	atlas->_textureNames = [[atlas->_textures allKeys] sortedArrayUsingSelector:@selector(compare:)];
	return atlas;
}

+ (instancetype)atlasWithDictionary:(NSDictionary<NSString *, id> *)properties
{
	SKTextureAtlas *atlas = [self new];
	atlas->_textures = [NSMutableDictionary dictionary];
	[properties enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
		SKTexture *texture = nil;
		if ([value isKindOfClass:[UIImage class]])
			texture = [SKTexture textureWithImage:value];
		else if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSURL class]]) {
			NSString *path = [value isKindOfClass:[NSURL class]] ? [value path] : value;
			UIImage *image = [UIImage imageWithContentsOfFile:path];
			if (image != nil)
				texture = [SKTexture textureWithImage:image];
		}
		if (texture != nil)
			atlas->_textures[SKTextureKey(key)] = texture;
	}];
	atlas->_textureNames = [[atlas->_textures allKeys] sortedArrayUsingSelector:@selector(compare:)];
	return atlas;
}

- (SKTexture *)textureNamed:(NSString *)name
{
	NSString *key = SKTextureKey(name);
	SKTexture *texture = _textures[key];
	if (texture == nil) {
		texture = [SKTexture textureWithImageNamed:name];
		_textures[key] = texture;
	}
	return texture;
}

- (NSArray<NSString *> *)textureNames
{
	return _textureNames ?: @[];
}

+ (void)preloadTextureAtlases:(NSArray<SKTextureAtlas *> *)textureAtlases withCompletionHandler:(void (^)(void))completionHandler
{
	if (completionHandler != nil)
		dispatch_async(dispatch_get_main_queue(), completionHandler);
}

+ (void)preloadTextureAtlasesNamed:(NSArray<NSString *> *)atlasNames withCompletionHandler:(void (^)(NSError *, NSArray<SKTextureAtlas *> *))completionHandler
{
	NSMutableArray *atlases = [NSMutableArray array];
	for (NSString *name in atlasNames)
		[atlases addObject:[self atlasNamed:name]];
	if (completionHandler != nil)
		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(nil, atlases);
		});
}

- (void)preloadWithCompletionHandler:(void (^)(void))completionHandler
{
	[SKTextureAtlas preloadTextureAtlases:@[ self ] withCompletionHandler:completionHandler];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	return [self init];
}

@end
