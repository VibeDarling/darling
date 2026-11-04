#import <UIKit/UICollectionViewCompositionalLayout.h>
#include <dlfcn.h>
#import <Foundation/NSException.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

static int deallocCount;
static void countingDealloc(__unsafe_unretained id self, SEL _cmd)
{
    deallocCount++;
    struct objc_super super = {self, class_getSuperclass(objc_getClass("CountingLayoutItem"))};
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&super, _cmd);
}
static BOOL raisesAndReleases(Class cls, SEL initializer, id argument)
{
    int before = deallocCount;
    BOOL raised = NO;
    @autoreleasepool {
        @try {
            id object = [cls alloc];
            if (argument != nil || initializer == @selector(initWithLayoutSize:))
                (void)((id (*)(id, SEL, id))objc_msgSend)(object, initializer, argument);
            else
                (void)((id (*)(id, SEL))objc_msgSend)(object, initializer);
        } @catch (NSException *exception) {
            raised = [[exception name] isEqualToString:NSInvalidArgumentException];
        }
    }
    return raised && deallocCount == before + 1;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        CHECK(argc == 2);
        void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
        Class itemClass = NSClassFromString(@"NSCollectionLayoutItem");
        CHECK(itemClass != Nil);
        Class sizeClass = NSClassFromString(@"NSCollectionLayoutSize");
        Class dimensionClass = NSClassFromString(@"NSCollectionLayoutDimension");
        Class spacingClass = NSClassFromString(@"NSCollectionLayoutSpacing");
        Class edgeClass = NSClassFromString(@"NSCollectionLayoutEdgeSpacing");
        NSCollectionLayoutItem *item;
        @autoreleasepool {
            NSCollectionLayoutSize *size = [sizeClass sizeWithWidthDimension:[dimensionClass fractionalWidthDimension:0.5]
                                                           heightDimension:[dimensionClass absoluteDimension:40]];
            item = [itemClass itemWithLayoutSize:size];
            item.edgeSpacing = [edgeClass spacingForLeading:[spacingClass fixedSpacing:6] top:nil trailing:nil bottom:nil];
            item.contentInsets = NSDirectionalEdgeInsetsMake(1, 2, 3, 4);
        }
        CHECK(item.layoutSize.widthDimension.dimension == 0.5);
        CHECK(item.layoutSize.heightDimension.dimension == 40);
        CHECK(item.edgeSpacing.leading.spacing == 6);
        NSCollectionLayoutItem *copy = [item copy];
        CHECK(copy != item);
        CHECK(copy.layoutSize.widthDimension.dimension == 0.5);
        CHECK(copy.edgeSpacing.leading.spacing == 6);
        NSDirectionalEdgeInsets insets = copy.contentInsets;
        CHECK(insets.top == 1 && insets.leading == 2 && insets.bottom == 3 && insets.trailing == 4);
        item.contentInsets = NSDirectionalEdgeInsetsMake(9, 8, 7, 6);
        item.edgeSpacing = nil;
        CHECK(copy.contentInsets.leading == 2 && copy.edgeSpacing.leading.spacing == 6);
        copy.contentInsets = NSDirectionalEdgeInsetsMake(5, 4, 3, 2);
        CHECK(item.contentInsets.top == 9 && item.edgeSpacing == nil);
        Class counting = objc_allocateClassPair(itemClass, "CountingLayoutItem", 0);
        CHECK(counting != Nil);
        class_addMethod(counting, sel_registerName("dealloc"), (IMP)countingDealloc, "v@:");
        objc_registerClassPair(counting);
        CHECK(raisesAndReleases(counting, @selector(init), nil));
        CHECK(raisesAndReleases(counting, @selector(initWithLayoutSize:), nil));
        BOOL factoryRaised = NO;
        @try { (void)((id (*)(Class, SEL, id))objc_msgSend)(itemClass, @selector(itemWithLayoutSize:), nil); }
        @catch (NSException *exception) { factoryRaised = [[exception name] isEqualToString:NSInvalidArgumentException]; }
        CHECK(factoryRaised);
        puts("PASS UIKit layout item size, ownership, insets, spacing, independent copies, and initializer raises that release self");
    }
    return 0;
}
