#ifndef DARLING_COREAUDIO_CATAPDESCRIPTION_H
#define DARLING_COREAUDIO_CATAPDESCRIPTION_H

#import <Foundation/Foundation.h>

// Describes a process tap.  Process tap creation is currently unsupported by
// Darling's audio backend, but callers can prepare and inspect a description.
@interface CATapDescription : NSObject {
@private
    NSString *_name;
    NSArray *_processes;
    NSUUID *_uuid;
    BOOL _private;
    BOOL _mixdown;
    BOOL _mono;
    BOOL _exclusive;
}
@property (copy) NSString *name;
@property (copy) NSArray *processes;
@property (readonly, retain) NSUUID *uuid;
@property (getter=isPrivate, setter=setPrivate:) BOOL tapPrivate;
@property (getter=isMixdown) BOOL mixdown;
@property (getter=isMono) BOOL mono;
@property (getter=isExclusive) BOOL exclusive;
@end

#endif
