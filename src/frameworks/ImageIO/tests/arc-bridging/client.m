#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
CGImageSourceRef authoredImageSource(NSURL *url, NSDictionary *options) {
 return CGImageSourceCreateWithURL((CFURLRef)url, (CFDictionaryRef)options);
}
