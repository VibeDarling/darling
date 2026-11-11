#import <Foundation/Foundation.h>

typedef NSString * AVMetadataKey NS_TYPED_EXTENSIBLE_ENUM;

extern const AVMetadataKey AVMetadataCommonKeyAlbumName;
extern const AVMetadataKey AVMetadataCommonKeyArtist;
extern const AVMetadataKey AVMetadataCommonKeyArtwork;
extern const AVMetadataKey AVMetadataCommonKeyDescription;
extern const AVMetadataKey AVMetadataCommonKeyTitle;

extern const AVMetadataKey AVMetadataID3MetadataKeyUserURL;

typedef NSString * AVMediaType NS_TYPED_ENUM;
typedef NSString * AVFileType NS_TYPED_EXTENSIBLE_ENUM;

extern const AVMediaType AVMediaTypeAudio;
extern const AVMediaType AVMediaTypeMuxed;
extern const AVMediaType AVMediaTypeVideo;

extern const AVFileType AVFileTypeMPEG4;
extern const AVFileType AVFileTypeQuickTimeMovie;
