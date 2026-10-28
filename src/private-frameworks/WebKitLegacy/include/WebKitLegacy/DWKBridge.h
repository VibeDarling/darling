/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/*
 * Darling's iOS WebKit renders pages in a web engine outside Darling
 * (darling-webhost: WebKitGTK on Linux, the system WebView on Android).
 * Script access goes through its web process extension, which connects
 * back to the app over TCP; the protocol is in docs/darling-webhost.md.
 *
 * Messages are newline-terminated JSON objects.  Either side may send a
 * request ({"id":n,"op":...}) at any time and answers with {"re":n,"ok":v}
 * or {"re":n,"err":"..."}.  While waiting for an answer each side serves
 * the other's requests, so calls nest in both directions the way they do
 * between WebKit and an app on iOS.  The app side runs on the main thread.
 */

#ifndef WEBKITLEGACY_DWKBRIDGE_H
#define WEBKITLEGACY_DWKBRIDGE_H

#import <Foundation/Foundation.h>

@class DWKBridgeConnection, WebScriptObject;

/* Serves a page's request (op "clear" for a page's new window object). */
typedef id (^DWKBridgeRequestHandler)(DWKBridgeConnection *connection, NSDictionary *request);

@interface DWKBridge : NSObject
+ (DWKBridge *)sharedBridge;
/* The port the web processes connect to, listening once asked; 0 on failure. */
- (unsigned short)port;
/* Handles "clear" requests: { page, main, window }. */
@property (nonatomic, copy) DWKBridgeRequestHandler clearHandler;
/* The connection that last spoke for a page. */
- (DWKBridgeConnection *)connectionForPage:(unsigned long long)page;
@end

@interface DWKBridgeConnection : NSObject
/* Sends a request and waits for the answer, serving requests meanwhile.
 * Returns the decoded answer, or nil (and logs) on an error. */
- (id)sendRequest:(NSDictionary *)request;
/* Script values to JSON and back: handles for objects on either side. */
- (id)encode:(id)value;
- (id)decode:(id)json;
- (WebScriptObject *)windowObjectForPage:(unsigned long long)page;
@end

/* Internal to WebKit: a script object for a JS handle on a connection. */
@interface WebScriptObject (DWKBridge)
- (instancetype)initWithConnection:(DWKBridgeConnection *)connection handle:(long long)handle;
- (DWKBridgeConnection *)dwkConnection;
- (long long)dwkHandle;
@end

#endif
