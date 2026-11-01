project(StoreKit)

remove_sdk_framework(StoreKit)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "379.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(StoreKit
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/StoreKit"
)

add_framework(StoreKit
    IOSSUPPORT_ALIAS
    FAT
    CURRENT_VERSION
    VERSION ${FRAMEWORK_VERSION}

    SOURCES
        src/StoreKit.m
        src/SKConstants.m
        src/SKServiceProxy.m
        src/SKPaymentQueueClient.m
        src/SKProductSubscriptionPeriodInternal.m
        src/SKProductSubscriptionPeriod.m
        src/SKProduct.m
        src/SKProductInternal.m
        src/SKXPCConnection.m
        src/SKStoreReviewController.m
        src/SKProductsRequest.m
        src/SKProductsResponse.m
        src/SKProductsRequestInternal.m
        src/SKProductsResponseInternal.m
        src/SKPayment.m
        src/SKMutablePayment.m
        src/SKPaymentInternal.m
        src/SKDownloadInternal.m
        src/SKDownload.m
        src/SKDownloadChangeset.m
        src/SKPaymentTransaction.m
        src/SKPaymentTransactionInternal.m
        src/SKPaymentQueue.m
        src/SKPaymentQueueInternal.m
        src/SKRequest.m
        src/SKRequestInternal.m
        src/SKProductDiscountInternal.m
        src/SKProductDiscount.m
        src/SKReceiptRefreshRequest.m
        src/SKHandleInvalidReceiptRequest.m
        src/SKServiceClient.m
        src/SKPaymentDiscountInternal.m
        src/SKPaymentDiscount.m

    DEPENDENCIES
        system
        objc
        Foundation
)

# Apple's StoreKit carries its Swift API (StoreKit 2) in the same image. Darling builds it apart,
# as an arm64 iOS Swift library (swift/build.sh); given its path, StoreKit installs it and
# re-exports it, so apps find Product, Transaction and the rest in StoreKit.
set(DARLING_STOREKIT_SWIFT_DYLIB "" CACHE FILEPATH "StoreKit's Swift API, built by src/frameworks/StoreKit/swift/build.sh")
if (DARLING_STOREKIT_SWIFT_DYLIB)
	if (NOT EXISTS "${DARLING_STOREKIT_SWIFT_DYLIB}")
		message(FATAL_ERROR "StoreKit Swift library does not exist: ${DARLING_STOREKIT_SWIFT_DYLIB}")
	endif()
	set_property(TARGET StoreKit APPEND_STRING PROPERTY
		LINK_FLAGS " -Wl,-reexport_library,${DARLING_STOREKIT_SWIFT_DYLIB}")
	set_property(TARGET StoreKit APPEND PROPERTY LINK_DEPENDS "${DARLING_STOREKIT_SWIFT_DYLIB}")
	install(PROGRAMS "${DARLING_STOREKIT_SWIFT_DYLIB}"
		DESTINATION libexec/darling/System/Library/Frameworks/StoreKit.framework/Versions/A
		RENAME StoreKitSwift)
endif()
