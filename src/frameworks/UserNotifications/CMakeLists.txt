project(UserNotifications)

remove_sdk_framework(UserNotifications)

set(DYLIB_COMPAT_VERSION "1.0.0")
set(DYLIB_CURRENT_VERSION "1.0.0")

set(FRAMEWORK_VERSION "A")

generate_sdk_framework(UserNotifications
    VERSION ${FRAMEWORK_VERSION}
    HEADER "include/UserNotifications"
)

set_source_files_properties(src/UNUserNotifications.m src/UNLite.m PROPERTIES COMPILE_FLAGS -fobjc-arc)

add_framework(UserNotifications
	FAT
	CURRENT_VERSION
	VERSION ${FRAMEWORK_VERSION}

	SOURCES
		src/UserNotifications.m
		src/UNUserNotifications.m
		src/UNLite.m
		src/UNLocalizedStringFactory.m
		src/UNLegacyNotificationTrigger.m
		src/UNLocationNotificationTrigger.m
		src/UNPushNotificationTrigger.m
		src/_UNNotificationServiceExtensionRemoteContext.m
		src/UNNotificationAction.m
		src/UNTextInputNotificationAction.m
		src/UNMutableNotificationSettings.m
		src/UNNotificationAttachmentOptions.m
		src/UNNotificationIcon.m
		src/UNMovieNotificationAttachmentOptions.m
		src/UNUserNotificationCenterDelegateConnectionListener.m
		src/UNSecurityScopedURL.m
		src/UNNotificationServiceExtension.m
		src/_UNNotificationServiceExtensionHostContext.m
		src/UNMutableNotificationSound.m
		src/_UNNotificationServiceExtensionContext.m
		src/UNAudioNotificationAttachmentOptions.m
		src/UNLocalizedString.m
		src/UNPushNotificationRequestBuilder.m
		src/UNImageNotificationAttachmentOptions.m
		src/UNNotificationAttachment.m
		src/UNUserNotificationService.m
		src/UNTextInputNotificationResponse.m
		src/UNUserNotificationCenterDelegateService.m
		src/UNNotificationCategory.m
		src/UNMutableNotificationCategory.m
		src/UNUserNotificationServiceConnection.m
		src/UNNotificationTopic.m
		src/UNNotificationTopicRequest.m

	DEPENDENCIES
		system
		objc
		Foundation
)
