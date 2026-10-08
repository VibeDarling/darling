#import <UIKit/UIGraphicsContext.h>
#import <AppKit/NSGraphicsContext.h>
#import <Foundation/Foundation.h>
#include <CoreGraphics/CGBitmapContext.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>

static void (*push)(CGContextRef);
static void (*pop)(void);
static CGContextRef (*current)(void);
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

static CGContextRef bitmap(void)
{
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 4, 4, 8, 16, color,
                                                kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(color);
    return context;
}

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t condition = PTHREAD_COND_INITIALIZER;
static unsigned ready;
static int proceed;
struct Worker { int failed; };
static void *worker(void *argument)
{
    struct Worker *result = argument;
    @autoreleasepool {
        CGContextRef outer = bitmap(), inner = bitmap();
        if (!outer || !inner || current() != NULL) result->failed = 1;
        push(outer);
        push(inner);
        if (current() != inner) result->failed = 1;
        pthread_mutex_lock(&mutex);
        ready++;
        pthread_cond_broadcast(&condition);
        while (!proceed) pthread_cond_wait(&condition, &mutex);
        pthread_mutex_unlock(&mutex);
        if (current() != inner) result->failed = 1;
        pop();
        if (current() != outer) result->failed = 1;
        pop();
        if (current() != NULL) result->failed = 1;
        CGContextRelease(inner);
        CGContextRelease(outer);
    }
    return NULL;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        push = dlsym(library, "UIGraphicsPushContext");
        pop = dlsym(library, "UIGraphicsPopContext");
        current = dlsym(library, "UIGraphicsGetCurrentContext");
        CHECK(push && pop && current);
        CHECK(current() == NULL);
        CGContextRef outer = bitmap(), inner = bitmap();
        CHECK(outer && inner);
        push(outer);
        CHECK(current() == outer);
        push(inner);
        CHECK(current() == inner);
        pop();
        CHECK(current() == outer);
        pop();
        CHECK(current() == NULL);

        NSGraphicsContext *existing = [NSGraphicsContext graphicsContextWithGraphicsPort:outer flipped:NO];
        [NSGraphicsContext setCurrentContext:existing];
        push(inner);
        CHECK(current() == inner);
        pop();
        CHECK([NSGraphicsContext currentContext] == existing);
        CHECK(current() == outer);
        [NSGraphicsContext setCurrentContext:nil];

        CGContextRef retained;
        @autoreleasepool {
            retained = bitmap();
            CHECK(retained);
            push(retained);
            CGContextRelease(retained);
        }
        CHECK(current() == retained);
        CHECK(CGBitmapContextGetWidth(current()) == 4);
        pop();
        CHECK(current() == NULL);

        push(outer);
        struct Worker results[2] = {{0}, {0}};
        pthread_t threads[2];
        CHECK(pthread_create(&threads[0], NULL, worker, &results[0]) == 0);
        CHECK(pthread_create(&threads[1], NULL, worker, &results[1]) == 0);
        pthread_mutex_lock(&mutex);
        while (ready != 2) pthread_cond_wait(&condition, &mutex);
        int independent = current() == outer;
        proceed = 1;
        pthread_cond_broadcast(&condition);
        pthread_mutex_unlock(&mutex);
        CHECK(pthread_join(threads[0], NULL) == 0);
        CHECK(pthread_join(threads[1], NULL) == 0);
        CHECK(independent && !results[0].failed && !results[1].failed);
        CHECK(current() == outer);
        pop();
        CHECK(current() == NULL);
        CGContextRelease(inner);
        CGContextRelease(outer);
        puts("PASS UIKit graphics contexts: nesting, AppKit restoration, retention, thread independence");
    }
    return 0;
}
