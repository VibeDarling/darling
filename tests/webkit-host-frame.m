#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include "../src/frameworks/WebKit/src/protocol.h"

@interface WKWebView (HostFrameRegression)
- (instancetype)initWithFrame:(NSRect)frame configuration:(WKWebViewConfiguration *)configuration;
@end

/* A 5x3 RGB frame with a padded stride, the shape a GdkPixbuf-backed host sends.
 * The first row differs so a flipped frame is caught. */
enum { FRAME_W = 5, FRAME_H = 3, FRAME_STRIDE = 16 };
static const unsigned char kTop[3] = { 0xc0, 0x20, 0x20 };
static const unsigned char kColour[3] = { 0x20, 0x60, 0xc0 };

static int read_all(int fd, void *buf, size_t len) {
    for (unsigned char *p = buf; len;) {
        ssize_t n = read(fd, p, len);
        if (n <= 0)
            return -1;
        p += n;
        len -= (size_t)n;
    }
    return 0;
}

static void reply(int fd, uint16_t type, const void *payload, uint32_t length) {
    dwb_header h = { DWB_MAGIC, DWB_PROTO_VERSION, type, length };
    write(fd, &h, sizeof(h));
    if (length)
        write(fd, payload, length);
}

/* Just enough of darling-webkit-host to hand the guest one raw frame: no shared
 * region, so the pixels arrive inline and are freed after presentation. */
static void *fake_host(void *arg) {
    struct sockaddr_un peer;
    socklen_t peer_len = sizeof(peer);
    int fd = accept(*(int *)arg, (struct sockaddr *)&peer, &peer_len);
    uint32_t seq = 0;
    dwb_header h;
    while (fd >= 0 && read_all(fd, &h, sizeof(h)) == 0) {
        char payload[4096];
        if (h.length > sizeof(payload) || read_all(fd, payload, h.length) != 0)
            break;
        if (h.type == DWB_MSG_HELLO) {
            const char *ack = "{\"backend\":\"test\",\"width\":5,\"height\":3}";
            reply(fd, DWB_MSG_HELLO_ACK, ack, (uint32_t)strlen(ack));
        } else if (h.type == DWB_MSG_SHM_ATTACH) {
            const char *no = "{\"name\":\"error\",\"detail\":\"test host sends frames inline\"}";
            reply(fd, DWB_MSG_EVENT, no, (uint32_t)strlen(no));
        } else if (h.type == DWB_MSG_FRAME) {
            unsigned char pixels[FRAME_STRIDE * FRAME_H];
            memset(pixels, 0xff, sizeof(pixels));
            for (int y = 0; y < FRAME_H; y++)
                for (int x = 0; x < FRAME_W; x++)
                    memcpy(pixels + y * FRAME_STRIDE + x * 3, y == 0 ? kTop : kColour, 3);
            dwb_frame_header fh = { DWB_FRAME_MAGIC, ++seq, FRAME_W, FRAME_H, FRAME_STRIDE,
                                    DWB_PIXEL_RGB, sizeof(pixels), 0 };
            reply(fd, DWB_MSG_FRAME, &fh, sizeof(fh));
            write(fd, pixels, sizeof(pixels));
        }
    }
    if (fd >= 0)
        close(fd);
    return NULL;
}

/* A frame pulled from the host must end up in the web view's own drawing. The
 * view is rendered into a bitmap the way AppKit renders it into a window, and the
 * centre pixel must be the colour the host sent. */
int main(void) {
    char path[64];
    snprintf(path, sizeof(path), "/tmp/dwb-frame-test-%d.sock", (int)getpid());
    struct sockaddr_un addr = { .sun_family = AF_UNIX };
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    int listener = socket(AF_UNIX, SOCK_STREAM, 0);
    unlink(path);
    if (listener < 0 || bind(listener, (struct sockaddr *)&addr, sizeof(addr)) != 0 || listen(listener, 1) != 0) {
        perror("fake host");
        return 2;
    }
    pthread_t thread;
    pthread_create(&thread, NULL, fake_host, &listener);
    setenv("DWB_WEBKIT_SOCKET", path, 1);

    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [NSApplication sharedApplication];
    WKWebView *view = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 40, 30)
                                         configuration:[[[WKWebViewConfiguration alloc] init] autorelease]];
    [view setNeedsDisplay:NO];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    BOOL invalidated = [view needsDisplay];

    NSBitmapImageRep *canvas = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:40 pixelsHigh:30 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:32] autorelease];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:canvas]];
    [view drawRect:[view bounds]];
    [NSGraphicsContext restoreGraphicsState];

    /* Read the bytes, top row first: -getPixel:atX:y: is not implemented here. */
    const unsigned char *top = [canvas bitmapData] + 2 * [canvas bytesPerRow] + 20 * 4;
    const unsigned char *px = [canvas bitmapData] + 25 * [canvas bytesPerRow] + 20 * 4;
    BOOL drawn = invalidated && NSEqualRects([view frame], NSMakeRect(0, 0, 40, 30)) && px[0] == kColour[0] && px[1] == kColour[1] && px[2] == kColour[2] && px[3] == 0xff &&
                 top[0] == kTop[0] && top[1] == kTop[1] && top[2] == kTop[2];
    fprintf(stderr, "%s host frame drawn by the web view (top %u,%u,%u bottom %u,%u,%u,%u)\n",
            drawn ? "PASS" : "FAIL", top[0], top[1], top[2], px[0], px[1], px[2], px[3]);
    [view release];
    [pool drain];
    unlink(path);
    return drawn ? 0 : 1;
}
