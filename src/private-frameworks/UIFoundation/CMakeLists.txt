project(UIFoundation)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "547.5.0")
set(FRAMEWORK_VERSION "A")

remove_sdk_framework(UIFoundation
    PRIVATE
)

generate_sdk_framework(UIFoundation
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/UIFoundation"
    PRIVATE
)

# The 27 text classes that AppKit used to define (NSFont, NSTextStorage, NSLayoutManager, ...) are real: they are built
# by src/external/cocotron/UIFoundation (the UIFoundation_text object library) and linked in here, and AppKit
# re-exports this framework. The remaining names are the no-op forwarders that were already here, except these, whose
# sources are no longer built because a name probe (NSClassFromString, objc_getClass, a weak class reference) would
# find a forwarder in every AppKit process instead of finding nothing:
#   NSCollectionViewFlowLayout NSCollectionViewLayout NSCollectionViewLayoutAttributes
#   NSCollectionViewLayoutInvalidationContext      (AppKit defines its own)
#   NSCTFont NSCTFontDescriptor NSMutableFontDescriptor    (CoreText bridges to a class of that name when it exists)
#   NSFontAssetRequest NSStringDrawingContext NSTextAlternatives NSTextAttachmentViewProvider NSTextLayoutFragment
#   NSTextLineFragment NSCollectionViewUpdateItem NSCollectionViewTransitionLayout
#   NSCollectionViewFlowLayoutInvalidationContext  (public API that apps probe to decide what is available)
#   NSConcreteTextStorage  (apps and frameworks bind it to AppKit, where it is missing today and fails loudly)
add_framework(UIFoundation
    FAT
    CURRENT_VERSION
    PRIVATE
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/UIFoundation.m
        src/NSCollectionViewData.m
        src/NSCoreTypesetter.m
        src/NSExtraLMData.m
        src/NSLayoutManagerTextBlockHelper.m
        src/NSLayoutManagerTextBlockRowArrayCache.m
        src/UINibCoderValue.m
        src/NSStorage.m
        src/_NSCachedAttributedString.m
        src/NSStringDrawingTextStorage.m
        src/NSStringDrawingTextStorageSettings.m
        src/NSZipTextReader.m
        src/_NSCollectionViewItemKey.m
        src/_UICollectionViewTrackedValueItem.m
        src/_UICollectionViewTrackedValue.m
        src/UICollectionViewAnimation.m
        src/UICollectionViewLayoutAttributesAuxiliary.m
        src/_NSCollectionViewCore.m
        src/UIViewAnimationContext.m
        src/_UIPointVector.m
        src/UIPointFIFO.m
        src/UIBoxcarFilterPointFIFO.m
        src/UIQuadCurvePointFIFO.m
        src/UICollectionViewIndexMapper.m
        src/NSCollectionViewUpdate.m
        src/NSConcreteNotifyingMutableAttributedString.m
        src/_NSTextStorageSideData.m
        src/_NSFlowLayoutItem.m
        src/_NSFlowLayoutSection.m
        src/_NSFlowLayoutRow.m
        src/_NSFlowLayoutInfo.m
        src/NSTextBlockLayoutHelper.m
        src/NSRTFReaderTableState.m
        src/NSRTFReader.m
        src/NSRTFWriter.m
        src/NSSubstituteWebResource.m
        src/NSHTMLWebDelegate.m
        src/NSHTMLReader.m
        src/NSHTMLWriter.m
        src/NSMutableIndexPath.m
        src/NSTempAttributeDictionary.m
        src/NSAttributeDictionary.m
        src/NSAttributeDictionaryEnumerator.m
        src/UINibStringIDTable.m
        src/__NSFontTypefaceInfo.m
        src/__NSSharedFontInstanceInfo.m
        src/NSParagraphArbitrator.m
        src/UINibDecoder.m
        src/NSIdentityGlyphInfo.m
        src/NSGlyphNameGlyphInfo.m
        src/NSCIDGlyphInfo.m
        src/NSCTGlyphInfo.m
        src/NSParagraphStyleExtraData.m
        src/NSOpenDocumentReader.m
        src/NSOpenDocumentWriter.m
        src/_NSUIAnimator.m
        src/NSRunStorage.m
        src/NSIdRunStorage.m
        src/NSInsertionPointHelper.m
        src/NSDocFormatReader.m
        src/NSDocFormatWriter.m
        src/_NSCollectionViewPrefetchingContext.m
        src/_UICollectionViewPrefetchItem.m
        src/UICollectionViewFlowLayoutAuxiliary.m
        src/_NSATSTypesetterGuts.m
        src/__NSATSStringSegment.m
        src/NSATSGlyphStorage.m
        src/NSATSLineFragment.m
        src/NSLineFragmentRenderingContext.m
        src/NSSingleLineTypesetter.m
        src/NSConcreteGlyphGenerator.m
        src/NSWordMLReader.m
        src/NSWordMLWriter.m

    OBJECTS
        $<TARGET_OBJECTS:UIFoundation_text>

    DEPENDENCIES
        system
        objc
        Foundation
        CoreFoundation
        CoreGraphics
        CoreText
        Onyx2D
)

# UIFoundation_text defines copies of 30 constants that AppKit defines itself (AppKit/NSTextSystemConstants.m); only
# AppKit's are exported, so apps bind to the same definition whichever UIFoundation is loaded.
set_property(TARGET UIFoundation APPEND_STRING PROPERTY LINK_FLAGS
    " -Wl,-unexported_symbols_list,${CMAKE_SOURCE_DIR}/src/external/cocotron/UIFoundation/unexported-symbols.txt")
