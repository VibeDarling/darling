/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/


#import <Foundation/Foundation.h>

/*
 * The constants apps compare against and pass to AVFoundation, with iOS's
 * values. Darling has no audio session or metadata reading behind them yet.
 */

NSString *const AVAudioSessionCategoryAmbient = @"AVAudioSessionCategoryAmbient";
NSString *const AVAudioSessionCategorySoloAmbient = @"AVAudioSessionCategorySoloAmbient";
NSString *const AVAudioSessionCategoryPlayback = @"AVAudioSessionCategoryPlayback";
NSString *const AVAudioSessionCategoryRecord = @"AVAudioSessionCategoryRecord";
NSString *const AVAudioSessionCategoryPlayAndRecord = @"AVAudioSessionCategoryPlayAndRecord";
NSString *const AVAudioSessionCategoryMultiRoute = @"AVAudioSessionCategoryMultiRoute";

NSString *const AVAudioSessionPortLineIn = @"LineIn";
NSString *const AVAudioSessionPortBuiltInMic = @"MicrophoneBuiltIn";
NSString *const AVAudioSessionPortHeadsetMic = @"MicrophoneWired";
NSString *const AVAudioSessionPortLineOut = @"LineOut";
NSString *const AVAudioSessionPortHeadphones = @"Headphones";
NSString *const AVAudioSessionPortBluetoothA2DP = @"BluetoothA2DPOutput";
NSString *const AVAudioSessionPortBuiltInReceiver = @"Receiver";
NSString *const AVAudioSessionPortBuiltInSpeaker = @"Speaker";
NSString *const AVAudioSessionPortHDMI = @"HDMIOutput";
NSString *const AVAudioSessionPortAirPlay = @"AirPlay";
NSString *const AVAudioSessionPortBluetoothLE = @"BluetoothLE";
NSString *const AVAudioSessionPortBluetoothHFP = @"BluetoothHFP";
NSString *const AVAudioSessionPortUSBAudio = @"USBAudio";
NSString *const AVAudioSessionPortCarAudio = @"CarAudio";

NSString *const AVMetadataKeySpaceCommon = @"comn";
NSString *const AVMetadataKeySpaceQuickTimeUserData = @"udta";
NSString *const AVMetadataKeySpaceQuickTimeMetadata = @"mdta";
NSString *const AVMetadataKeySpaceiTunes = @"itsk";
NSString *const AVMetadataKeySpaceID3 = @"org.id3";

NSString *const AVMetadataID3MetadataKeyAlbumTitle = @"TALB";
NSString *const AVMetadataID3MetadataKeyLyricist = @"TEXT";
NSString *const AVMetadataID3MetadataKeyOriginalArtist = @"TOPE";
NSString *const AVMetadataID3MetadataKeyTrackNumber = @"TRCK";
NSString *const AVMetadataID3MetadataKeyUnsynchronizedLyric = @"USLT";
NSString *const AVMetadataID3MetadataKeyYear = @"TYER";
NSString *const AVMetadataID3MetadataKeyLeadPerformer = @"TPE1";
NSString *const AVMetadataID3MetadataKeyTitleDescription = @"TIT2";

NSString *const AVMetadataiTunesMetadataKeyAlbum = @"©alb";
NSString *const AVMetadataiTunesMetadataKeyArtist = @"©ART";
NSString *const AVMetadataiTunesMetadataKeyLyrics = @"©lyr";
NSString *const AVMetadataiTunesMetadataKeySongName = @"©nam";
