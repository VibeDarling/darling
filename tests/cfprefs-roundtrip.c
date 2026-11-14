// Guest test: Darling's own CF-Lite preferences (in-process, plist files under ~/Library/Preferences) round-trip a value.
// It is a regression guard for src/cfprefsd: the stand-in daemon must not change how plain Darling programs store preferences,
// so this passes with and without the daemon installed. Compile in the guest: clang tests/cfprefs-roundtrip.c -framework CoreFoundation
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

int main(void) {
	CFStringRef app = CFSTR("org.darlinghq.cfprefs-roundtrip-test"), key = CFSTR("roundtrip.key");
	CFPreferencesSetAppValue(key, CFSTR("stored"), app);
	if (!CFPreferencesAppSynchronize(app)) {
		printf("FAIL: synchronize returned false\n");
		return 1;
	}
	CFPreferencesAppSynchronize(app);
	CFTypeRef v = CFPreferencesCopyAppValue(key, app);
	char buf[32] = "";
	int ok = v && CFGetTypeID(v) == CFStringGetTypeID() && CFStringGetCString(v, buf, sizeof(buf), kCFStringEncodingUTF8) && !strcmp(buf, "stored");
	CFPreferencesSetAppValue(key, NULL, app);
	CFPreferencesAppSynchronize(app);
	if (!ok) {
		printf("FAIL: value not read back\n");
		return 1;
	}
	CFTypeRef gone = CFPreferencesCopyAppValue(key, app);
	if (gone) {
		printf("FAIL: value still present after removal\n");
		return 1;
	}
	printf("PASS: CF-Lite preferences round-trip\n");
	return 0;
}
