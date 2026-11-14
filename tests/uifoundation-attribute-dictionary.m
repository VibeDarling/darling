// UIFoundation's NSAttributeDictionary must answer the two class methods that frameworks outside UIFoundation send it
// (+emptyAttributeDictionary, +newWithDictionary:) and behave as an NSDictionary, including the primitive initializer.
// Before this test, both class methods were "unrecognized selector" exceptions (Stickies, Terminal, Audio MIDI Setup,
// Digital Color Meter on the dyld-cache stage).
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>

static int failures;
static void expect(BOOL ok, const char *what)
{
    if (!ok) { fprintf(stderr, "FAIL: %s\n", what); failures++; }
}

int main(void)
{
    @autoreleasepool {
        void *h = dlopen("/System/Library/PrivateFrameworks/UIFoundation.framework/Versions/A/UIFoundation", RTLD_NOW);
        expect(h != NULL, "UIFoundation loads");
        Class c = NSClassFromString(@"NSAttributeDictionary");
        expect(c != Nil, "NSAttributeDictionary exists");
        if (c == Nil) return 1;
        expect([c respondsToSelector:@selector(emptyAttributeDictionary)], "+emptyAttributeDictionary is implemented");
        expect([c respondsToSelector:@selector(newWithDictionary:)], "+newWithDictionary: is implemented");
        if (failures) return 1;

        NSDictionary *empty = [c performSelector:@selector(emptyAttributeDictionary)];
        expect([empty isKindOfClass:[NSDictionary class]], "the empty instance is an NSDictionary");
        expect([empty count] == 0, "the empty instance is empty");
        expect([c performSelector:@selector(emptyAttributeDictionary)] == empty, "the empty instance is shared");

        NSDictionary *source = @{ @"NSFont": @"f", @"NSColor": @"c" };
        NSDictionary *made = [c performSelector:@selector(newWithDictionary:) withObject:source];
        expect([made isKindOfClass:[NSDictionary class]], "newWithDictionary: returns an NSDictionary");
        expect([made count] == 2, "newWithDictionary: keeps both entries");
        expect([[made objectForKey:@"NSFont"] isEqual:@"f"], "newWithDictionary: keeps the values");
        expect([made isEqualToDictionary:source], "newWithDictionary: equals its source");
        NSUInteger seen = 0;
        for (id key in made) { (void)key; seen++; }
        expect(seen == 2, "fast enumeration visits every key");
        id same = [made copy];
        expect(same == made, "copy returns the same immutable instance");
        [same release];
        [made release];
        NSMutableDictionary *mutableSource = [NSMutableDictionary dictionaryWithDictionary:source];
        NSDictionary *isolated = [c performSelector:@selector(newWithDictionary:) withObject:mutableSource];
        [mutableSource setObject:@"x" forKey:@"later"];
        expect([isolated count] == 2, "mutating the source after newWithDictionary: does not change the result");
        [isolated release];
        NSDictionary *none = [c performSelector:@selector(newWithDictionary:) withObject:nil];
        expect([none count] == 0, "newWithDictionary:nil gives an empty dictionary");
        [none release];

        // The NSDictionary primitive -initWithObjects:forKeys:count: must exist: these three paths funnel into it.
        NSDictionary *viaInit = [[c alloc] initWithDictionary:source];
        expect([viaInit isEqualToDictionary:source], "-initWithDictionary: copies the entries");
        [viaInit release];
        NSDictionary *viaFactory = [c dictionaryWithObject:@"v" forKey:@"k"];
        expect([viaFactory count] == 1 && [[viaFactory objectForKey:@"k"] isEqual:@"v"], "+dictionaryWithObject:forKey: works");
        NSDictionary *attrs = [c performSelector:@selector(newWithDictionary:) withObject:source];
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:attrs];
        NSDictionary *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
        expect([decoded isEqualToDictionary:source], "a keyed archive round trip keeps the entries");
        [attrs release];
    }
    if (failures) return 1;
    printf("PASS\n");
    return 0;
}
