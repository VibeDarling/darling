// Guest test: the cfprefsd stand-in is registered under Darling and stores what a client writes.
// Compile in the guest: clang tests/cfprefsd-service.c -framework CoreFoundation -o /tmp/cfprefsd_service_test
// Prints "PASS: ..." and exits 0; on a prefix without the daemon the lookup fails and the test fails.
// Request and reply layouts are the ones in src/cfprefsd/cfprefsd.c (names and types); the client here is our own program.
#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <pwd.h>
#include <sys/mman.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <xpc/xpc.h>

#define SERVICE "com.apple.cfprefsd.daemon"
#define TEST_DOMAIN "org.darlinghq.cfprefsd-service-test"

static int failures = 0;
#define CHECK(cond, ...) do { if (!(cond)) { failures++; printf("FAIL: "); printf(__VA_ARGS__); printf("\n"); } } while (0)

static xpc_connection_t conn;

static xpc_object_t request(int64_t op, const char* domain, bool by_host) {
	xpc_object_t m = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_int64(m, "CFPreferencesOperation", op);
	if (domain) xpc_dictionary_set_string(m, "CFPreferencesDomain", domain);
	xpc_dictionary_set_string(m, "CFPreferencesUser", "kCFPreferencesCurrentUser");
	xpc_dictionary_set_string(m, "CFPreferencesHostBundleIdentifier", "cfprefsd-service-test");
	if (by_host) xpc_dictionary_set_bool(m, "CFPreferencesIsByHost", true);
	return m;
}

static xpc_object_t call(xpc_object_t m) {
	xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, m);
	xpc_release(m);
	return reply;
}

static bool is_error(xpc_object_t reply) {
	return xpc_get_type(reply) == XPC_TYPE_DICTIONARY && xpc_dictionary_get_string(reply, "darling-error") != NULL;
}

static void prefs_path(char* out, size_t n, const char* sub, const char* domain) {
	snprintf(out, n, "%s/Library/Preferences/%s%s.plist", getpwuid(getuid())->pw_dir, sub, domain);
}

static CFTypeRef file_value(const char* path, const char* key) {
	CFStringRef p = CFStringCreateWithCString(NULL, path, kCFStringEncodingUTF8);
	CFURLRef url = CFURLCreateWithFileSystemPath(NULL, p, kCFURLPOSIXPathStyle, false);
	CFDataRef data = NULL;
	CFTypeRef result = NULL;
	if (CFURLCreateDataAndPropertiesFromResource(NULL, url, &data, NULL, NULL, NULL) && data) {
		CFPropertyListRef plist = CFPropertyListCreateWithData(NULL, data, 0, NULL, NULL);
		if (plist && CFGetTypeID(plist) == CFDictionaryGetTypeID()) {
			CFStringRef k = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
			result = CFDictionaryGetValue(plist, k);
			if (result) CFRetain(result);
			CFRelease(k);
		}
		if (plist) CFRelease(plist);
		CFRelease(data);
	}
	CFRelease(url);
	CFRelease(p);
	return result;
}

static bool string_value_is(const char* path, const char* key, const char* want) {
	CFTypeRef v = file_value(path, key);
	char buf[256] = "";
	bool ok = v && CFGetTypeID(v) == CFStringGetTypeID() && CFStringGetCString(v, buf, sizeof(buf), kCFStringEncodingUTF8) && !strcmp(buf, want);
	if (v) CFRelease(v);
	return ok;
}

int main(void) {
	char path[1024], byhost_dir[1024], evil[1024];
	prefs_path(path, sizeof(path), "", TEST_DOMAIN);
	unlink(path);

	dispatch_queue_t q = dispatch_queue_create("test", NULL);
	conn = xpc_connection_create_mach_service(SERVICE, q, 0);
	xpc_connection_set_event_handler(conn, ^(xpc_object_t e) { (void)e; });
	xpc_connection_resume(conn);

	// operation 9: the plist path of the layer
	xpc_object_t r = call(request(9, TEST_DOMAIN, false));
	if (xpc_get_type(r) != XPC_TYPE_DICTIONARY) {
		printf("FAIL: no reply from " SERVICE " (not registered?)\n");
		return 1;
	}
	const char* got = xpc_dictionary_get_string(r, "CFPreferencesUncanonicalizedPath");
	CHECK(got && !strcmp(got, path), "op 9 path is '%s', expected '%s'", got ? got : "(none)", path);
	xpc_release(r);

	// operation 1 with Key and Value: a write
	xpc_object_t w = request(1, TEST_DOMAIN, false);
	xpc_dictionary_set_string(w, "Key", "test.string");
	xpc_dictionary_set_string(w, "Value", "first");
	r = call(w);
	CHECK(!is_error(r), "write replied with an error");
	CHECK(xpc_dictionary_get_string(r, "CFPreferencesShmemName") != NULL, "write reply has no shared-memory name");
	xpc_release(r);
	CHECK(string_value_is(path, "test.string", "first"), "value not in the plist at the op 9 path");

	// a second key keeps the first; types round-trip
	w = request(1, TEST_DOMAIN, false);
	xpc_dictionary_set_string(w, "Key", "test.int");
	xpc_dictionary_set_int64(w, "Value", 4242);
	xpc_release(call(w));
	CFTypeRef n = file_value(path, "test.int");
	int64_t num = 0;
	CHECK(n && CFGetTypeID(n) == CFNumberGetTypeID() && CFNumberGetValue(n, kCFNumberSInt64Type, &num) && num == 4242, "integer did not round-trip");
	if (n) CFRelease(n);
	CHECK(string_value_is(path, "test.string", "first"), "first key lost by the second write");

	// Darling's own CFPreferences (a different consumer of the same file) reads it
	CFStringRef app = CFStringCreateWithCString(NULL, TEST_DOMAIN, kCFStringEncodingUTF8), k = CFSTR("test.string");
	CFPreferencesAppSynchronize(app);
	CFTypeRef cf = CFPreferencesCopyAppValue(k, app);
	char buf[64] = "";
	CHECK(cf && CFStringGetCString(cf, buf, sizeof(buf), kCFStringEncodingUTF8) && !strcmp(buf, "first"), "CFPreferences does not see the daemon's write");
	if (cf) CFRelease(cf);

	// no Value removes the key
	w = request(1, TEST_DOMAIN, false);
	xpc_dictionary_set_string(w, "Key", "test.string");
	xpc_release(call(w));
	CFTypeRef gone = file_value(path, "test.string");
	CHECK(gone == NULL, "key still present after a write without a value");
	if (gone) CFRelease(gone);

	// batch: one reply per item, null stays null
	xpc_object_t items = xpc_array_create(NULL, 0);
	xpc_object_t item = request(9, TEST_DOMAIN, false);
	xpc_array_append_value(items, item); xpc_release(item);
	xpc_object_t nul = xpc_null_create(); xpc_array_append_value(items, nul); xpc_release(nul);
	item = request(1, TEST_DOMAIN, false);
	xpc_array_append_value(items, item); xpc_release(item);
	xpc_object_t b = request(5, TEST_DOMAIN, false);
	xpc_dictionary_set_value(b, "CFPreferencesMessages", items); xpc_release(items);
	r = call(b);
	xpc_object_t replies = xpc_dictionary_get_value(r, "CFPreferencesMessages");
	CHECK(replies && xpc_get_type(replies) == XPC_TYPE_ARRAY && xpc_array_get_count(replies) == 3, "batch reply is not an array of 3");
	if (replies && xpc_array_get_count(replies) == 3) {
		CHECK(xpc_dictionary_get_string(xpc_array_get_value(replies, 0), "CFPreferencesUncanonicalizedPath") != NULL, "batch item 0 has no path");
		CHECK(xpc_get_type(xpc_array_get_value(replies, 1)) == XPC_TYPE_NULL, "batch null item not answered with null");
		CHECK(xpc_dictionary_get_string(xpc_array_get_value(replies, 2), "CFPreferencesShmemName") != NULL, "batch item 2 has no shared-memory name");
	}
	xpc_release(r);

	// a domain that is not a plain name is refused, nothing is written outside the preferences directory
	const char* bad[] = { "../evil", "a/b", "..", ".", "" };
	for (size_t i = 0; i < sizeof(bad) / sizeof(bad[0]); i++) {
		xpc_object_t bw = request(1, bad[i], false);
		xpc_dictionary_set_string(bw, "Key", "x"); xpc_dictionary_set_string(bw, "Value", "y");
		r = call(bw);
		CHECK(is_error(r), "write for domain '%s' was not refused", bad[i]);
		xpc_release(r);
		r = call(request(9, bad[i], false));
		CHECK(is_error(r), "op 9 for domain '%s' was not refused", bad[i]);
		xpc_release(r);
	}
	snprintf(evil, sizeof(evil), "%s/Library/evil.plist", getpwuid(getuid())->pw_dir);
	CHECK(access(evil, F_OK) != 0, "a '../' domain wrote outside the preferences directory");

	// the daemon works as the client: a by-host directory the client itself cannot write is not writable through the daemon
	snprintf(byhost_dir, sizeof(byhost_dir), "%s/Library/Preferences/ByHost", getpwuid(getuid())->pw_dir);
	mkdir(byhost_dir, 0700);
	chmod(byhost_dir, 0500);
	if (getuid() != 0) {
		r = call(request(9, TEST_DOMAIN, true));
		CHECK(!is_error(r), "no by-host path (precondition of the next check)");
		xpc_release(r);
		w = request(1, TEST_DOMAIN, true);
		xpc_dictionary_set_string(w, "Key", "test.byhost"); xpc_dictionary_set_string(w, "Value", "no");
		r = call(w);
		CHECK(is_error(r), "a write into a directory the client cannot write was not refused");
		xpc_release(r);
	}
	chmod(byhost_dir, 0700);


	// a batch cannot contain a batch, and an oversized batch is refused (no unbounded recursion or work from one message)
	xpc_object_t inner_items = xpc_array_create(NULL, 0);
	xpc_object_t nested = request(5, TEST_DOMAIN, false);
	xpc_dictionary_set_value(nested, "CFPreferencesMessages", inner_items);
	xpc_release(inner_items);
	items = xpc_array_create(NULL, 0);
	xpc_array_append_value(items, nested); xpc_release(nested);
	b = request(5, TEST_DOMAIN, false);
	xpc_dictionary_set_value(b, "CFPreferencesMessages", items); xpc_release(items);
	r = call(b);
	replies = xpc_dictionary_get_value(r, "CFPreferencesMessages");
	CHECK(replies && xpc_array_get_count(replies) == 1 && is_error(xpc_array_get_value(replies, 0)), "a batch inside a batch was not refused");
	xpc_release(r);
	items = xpc_array_create(NULL, 0);
	for (int i = 0; i < 1000; i++) { xpc_object_t nul2 = xpc_null_create(); xpc_array_append_value(items, nul2); xpc_release(nul2); }
	b = request(5, TEST_DOMAIN, false);
	xpc_dictionary_set_value(b, "CFPreferencesMessages", items); xpc_release(items);
	r = call(b);
	CHECK(is_error(r), "a batch of 1000 items was not refused");
	xpc_release(r);
	r = call(request(9, TEST_DOMAIN, false));
	CHECK(!is_error(r), "the daemon stopped answering after the oversized and nested batches");
	xpc_release(r);

	// the any-user and managed layers are shared by every user: a non-root client may not write them
	if (getuid() != 0) {
		w = request(1, TEST_DOMAIN, false);
		xpc_dictionary_set_string(w, "Key", "test.shared"); xpc_dictionary_set_string(w, "Value", "no");
		xpc_dictionary_set_value(w, "CFPreferencesUser", NULL); // any-user layer: no user key
		r = call(w);
		CHECK(is_error(r), "an any-user write by a non-root client was not refused");
		xpc_release(r);
		w = request(1, TEST_DOMAIN, false);
		xpc_dictionary_set_string(w, "Key", "test.shared"); xpc_dictionary_set_string(w, "Value", "no");
		xpc_dictionary_set_bool(w, "CFPreferencesIsManaged", true);
		r = call(w);
		CHECK(is_error(r), "a managed-layer write by a non-root client was not refused");
		xpc_release(r);
	}

	// the identity the daemon holds for this caller (from the connection's audit trailer) is the caller's own, not a zeroed or forged field
	xpc_object_t who = request(9, TEST_DOMAIN, false);
	xpc_dictionary_set_bool(who, "darling-whoami", true);
	r = call(who);
	CHECK(xpc_dictionary_get_int64(r, "darling-caller-uid") == (int64_t)getuid(), "the daemon sees uid %lld, the client is uid %d", (long long)xpc_dictionary_get_int64(r, "darling-caller-uid"), (int)getuid());
	CHECK(xpc_dictionary_get_int64(r, "darling-caller-gid") == (int64_t)getgid(), "the daemon sees gid %lld, the client is gid %d", (long long)xpc_dictionary_get_int64(r, "darling-caller-gid"), (int)getgid());
	CHECK(xpc_dictionary_get_int64(r, "darling-caller-pid") == (int64_t)getpid(), "the daemon sees pid %lld, the client is pid %d", (long long)xpc_dictionary_get_int64(r, "darling-caller-pid"), (int)getpid());
	xpc_release(r);
	CHECK(getuid() != 0, "this test must run as a non-root user (it checks that the daemon does not see a zeroed uid)");

	// a client cannot talk its way into another identity: a forged uid key is not read, the file is the caller's own
	w = request(1, TEST_DOMAIN, false);
	xpc_dictionary_set_string(w, "Key", "test.forged"); xpc_dictionary_set_string(w, "Value", "mine");
	xpc_dictionary_set_int64(w, "uid", 0); xpc_dictionary_set_int64(w, "CFPreferencesUid", 0);
	xpc_release(call(w));
	CHECK(string_value_is(path, "test.forged", "mine"), "a write carrying forged uid keys did not land in the caller's own plist");
	struct stat fst;
	CHECK(stat(path, &fst) == 0 && fst.st_uid == getuid(), "the plist is not owned by the calling user");

	// the shared region is readable by clients but not writable by them (mode 0644, only the daemon writes it)
	int shm = shm_open("apple.cfprefs.daemonv1", O_RDONLY, 0);
	CHECK(shm >= 0, "the shared region apple.cfprefs.daemonv1 cannot be opened read-only");
	if (shm >= 0) {
		struct stat sst;
		CHECK(fstat(shm, &sst) == 0 && sst.st_size == 16384, "the shared region is not 16384 bytes");
		CHECK((sst.st_mode & 0022) == 0, "the shared region is writable by group or others (mode %o)", (unsigned)(sst.st_mode & 0777));
		close(shm);
	}

	// an unknown operation gets an explicit reply, not silence
	r = call(request(77, TEST_DOMAIN, false));
	CHECK(is_error(r), "unknown operation not answered with an error");
	xpc_release(r);

	unlink(path);
	if (failures) return 1;
	printf("PASS: cfprefsd stand-in answers operations 9, 1 and 5, stores writes, refuses bad domains and acts as the client\n");
	return 0;
}
