#import <UIKit/UICollectionViewCompositionalLayout.h>
#include <dlfcn.h>
#include <stdio.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)

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
        puts("PASS UIKit layout item size, ownership, insets, spacing and independent copies");
    }
    return 0;
}
