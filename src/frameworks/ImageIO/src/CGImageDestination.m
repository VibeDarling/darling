#import <ImageIO/CGImageDestination.h>
#import <Onyx2D/O2ImageDestination.h>
#import <Onyx2D/O2ImageSource.h>

#include <CoreFoundation/CoreFoundation.h>

const CFStringRef kCGImageDestinationLossyCompressionQuality=(CFStringRef)@"kCGImageDestinationLossyCompressionQuality";
const CFStringRef kCGImageDestinationBackgroundColor=(CFStringRef)@"kCGImageDestinationBackgroundColor";
const CFStringRef kCGImageDestinationDPI=(CFStringRef)@"kCGImageDestinationDPI";

// Observed on a real Mac (macOS 26.1, probe line 10-12): the key's own name, like its siblings above.
// The options are accepted and have no effect: the destination reads no option
// except the ones above, so the image keeps its size and color space and no gain map is ever written.
const CFStringRef kCGImageDestinationImageMaxPixelSize = CFSTR("kCGImageDestinationImageMaxPixelSize");
const CFStringRef kCGImageDestinationOptimizeColorForSharing = CFSTR("kCGImageDestinationOptimizeColorForSharing");
const CFStringRef kCGImageDestinationPreserveGainMap = CFSTR("kCGImageDestinationPreserveGainMap");

CFTypeID CGImageDestinationGetTypeID(void) {
   return O2ImageDestinationGetTypeID();
}

CFArrayRef CGImageDestinationCopyTypeIdentifiers(void) {
   return O2ImageDestinationCopyTypeIdentifiers();
}

CGImageDestinationRef CGImageDestinationCreateWithData(CFMutableDataRef data,CFStringRef type,size_t imageCount,CFDictionaryRef options) {
   return (CGImageDestinationRef)O2ImageDestinationCreateWithData(data,type,imageCount,options);
}

CGImageDestinationRef CGImageDestinationCreateWithDataConsumer(CGDataConsumerRef dataConsumer,CFStringRef type,size_t imageCount,CFDictionaryRef options) {
   return (CGImageDestinationRef)O2ImageDestinationCreateWithDataConsumer((O2DataConsumerRef)dataConsumer,type,imageCount,options);
}

CGImageDestinationRef CGImageDestinationCreateWithURL(CFURLRef url,CFStringRef type,size_t imageCount,CFDictionaryRef options) {
   return (CGImageDestinationRef)O2ImageDestinationCreateWithURL(url,type,imageCount,options);
}

void CGImageDestinationSetProperties(CGImageDestinationRef self,CFDictionaryRef properties) {
   O2ImageDestinationSetProperties((O2ImageDestinationRef)self,properties);
}

void CGImageDestinationAddImage(CGImageDestinationRef self,CGImageRef image,CFDictionaryRef properties) {
   O2ImageDestinationAddImage((O2ImageDestinationRef)self,(O2ImageRef)image,properties);
}

void CGImageDestinationAddImageFromSource(CGImageDestinationRef self,CGImageSourceRef imageSource,size_t index,CFDictionaryRef properties) {
   O2ImageDestinationAddImageFromSource((O2ImageDestinationRef)self,(O2ImageSourceRef)imageSource,index,properties);
}


bool CGImageDestinationFinalize(CGImageDestinationRef self) {
   return O2ImageDestinationFinalize((O2ImageDestinationRef)self);
}

void CGImageDestinationAddImageAndMetadata(CGImageDestinationRef self, CGImageRef image, CGImageMetadataRef metadata, CFDictionaryRef properties) {
   CGImageDestinationAddImage(self, image, properties);
}

CGMutableImageMetadataRef CGImageMetadataCreateMutable(void) {
   return (CGMutableImageMetadataRef)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

CGImageMetadataTagRef CGImageMetadataTagCreate(CFStringRef xmlns, CFStringRef prefix, CFStringRef name, int type, CFTypeRef value) {
   return (CGImageMetadataTagRef)CFRetain(value ? value : (CFTypeRef)kCFNull);
}

bool CGImageMetadataSetTagWithPath(CGMutableImageMetadataRef metadata, CGImageMetadataTagRef parent, CFStringRef path, CGImageMetadataTagRef tag) {
   if (metadata && path && tag) {
      CFDictionarySetValue((CFMutableDictionaryRef)metadata, path, (const void*)tag);
      return true;
   }
   return false;
}
