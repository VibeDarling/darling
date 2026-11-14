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
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
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
	return xpc_get_type(reply) == XPC_TYPE_DICTIONARY && xpc_dictionary_get_string(reply, "CFPreferencesErrorDescription") != NULL &&
		xpc_dictionary_get_value(reply, "CFPreferencesErrorType") != NULL && xpc_get_type(xpc_dictionary_get_value(reply, "CFPreferencesErrorType")) == XPC_TYPE_INT64;
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


// writes ~/Library/Preferences/<domain>.plist holding one data value of the given size (a binary plist of about that size)
static void write_blob_plist(const char* domain, size_t bytes) {
	char p[1024];
	prefs_path(p, sizeof(p), "", domain);
	unsigned char* blob = calloc(bytes, 1);
	CFDataRef data = CFDataCreate(NULL, blob, (CFIndex)bytes);
	CFStringRef k = CFSTR("blob");
	CFDictionaryRef dict = CFDictionaryCreate(NULL, (const void**)&k, (const void**)&data, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFDataRef out = CFPropertyListCreateData(NULL, dict, kCFPropertyListBinaryFormat_v1_0, 0, NULL);
	FILE* f = fopen(p, "wb");
	if (f) { fwrite(CFDataGetBytePtr(out), 1, (size_t)CFDataGetLength(out), f); fclose(f); }
	CFRelease(out); CFRelease(dict); CFRelease(data); free(blob);
}

// A bplist00 whose top object is an array of depth `depth`: each level is an array holding the level below TWICE (by reference), the
// bottom is the integer 0. It is 8 + 2 + 3 * depth + depth + 1 + 32 bytes and expands to 2^(depth + 1) - 1 objects.
static CFDataRef dag_bplist(int depth) {
	unsigned char b[512];
	size_t n = 0;
	memcpy(b, "bplist00", 8); n = 8;
	unsigned char offsets[130];
	offsets[0] = (unsigned char)n; b[n++] = 0x10; b[n++] = 0x00;
	for (int level = 1; level <= depth; level++) {
		offsets[level] = (unsigned char)n;
		b[n++] = 0xA2; b[n++] = (unsigned char)(level - 1); b[n++] = (unsigned char)(level - 1);
	}
	size_t table = n;
	memcpy(b + n, offsets, (size_t)depth + 1); n += (size_t)depth + 1;
	memset(b + n, 0, 32);
	unsigned char* t = b + n;
	t[6] = 1; t[7] = 1; t[15] = (unsigned char)(depth + 1); t[23] = (unsigned char)depth; t[30] = (unsigned char)(table >> 8); t[31] = (unsigned char)table;
	n += 32;
	return CFDataCreate(NULL, b, (CFIndex)n);
}

static xpc_object_t write_data_value(const char* key, CFDataRef bytes) {
	xpc_object_t w = request(1, TEST_DOMAIN, false);
	xpc_dictionary_set_string(w, "Key", key);
	xpc_dictionary_set_data(w, "Value", CFDataGetBytePtr(bytes), (size_t)CFDataGetLength(bytes));
	return call(w);
}

static double seconds_since(struct timespec start) {
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);
	return (double)(now.tv_sec - start.tv_sec) + (double)(now.tv_nsec - start.tv_nsec) / 1e9;
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
	// a value that is not a string or a boolean arrives as xpc data holding a bplist00 whose top object is the value (observed): write it that way
	int64_t forty_two = 4242;
	CFNumberRef number = CFNumberCreate(NULL, kCFNumberSInt64Type, &forty_two);
	CFDataRef number_plist = CFPropertyListCreateData(NULL, number, kCFPropertyListBinaryFormat_v1_0, 0, NULL);
	r = write_data_value("test.int", number_plist);
	CHECK(!is_error(r), "a bplist00 data value was refused");
	xpc_release(r);
	CFRelease(number_plist); CFRelease(number);
	CFTypeRef n = file_value(path, "test.int");
	int64_t num = 0;
	CHECK(n && CFGetTypeID(n) == CFNumberGetTypeID() && CFNumberGetValue(n, kCFNumberSInt64Type, &num) && num == 4242, "integer did not round-trip");
	if (n) CFRelease(n);
	CHECK(string_value_is(path, "test.string", "first"), "first key lost by the second write");

	// a rewrite keeps the file's mode: a new file is 0600, and a file made 0644 stays 0644
	struct stat mode_st;
	CHECK(stat(path, &mode_st) == 0 && (mode_st.st_mode & 0777) == 0600, "a new preferences file is not mode 0600 (%o)", (unsigned)(mode_st.st_mode & 0777));
	chmod(path, 0644);
	w = request(1, TEST_DOMAIN, false);
	xpc_dictionary_set_string(w, "Key", "test.mode"); xpc_dictionary_set_string(w, "Value", "kept");
	xpc_release(call(w));
	CHECK(stat(path, &mode_st) == 0 && (mode_st.st_mode & 0777) == 0644, "a rewrite changed the file mode 0644 to %o", (unsigned)(mode_st.st_mode & 0777));

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


	// operation 1 without Key reads the layer: the reply carries the layer dictionary as a bplist00 in CFPreferencesPropertyList, and
	// CFPreferencesShmemState is the uint32 in the layer's slot of the shared region, which goes up on every write to the layer
	r = call(request(1, TEST_DOMAIN, false));
	xpc_object_t pl = xpc_dictionary_get_value(r, "CFPreferencesPropertyList");
	CHECK(pl && xpc_get_type(pl) == XPC_TYPE_DATA && xpc_data_get_length(pl) > 8 && !memcmp(xpc_data_get_bytes_ptr(pl), "bplist00", 8), "operation 1 read has no bplist00 CFPreferencesPropertyList");
	if (pl && xpc_get_type(pl) == XPC_TYPE_DATA) {
		CFDataRef d = CFDataCreate(NULL, xpc_data_get_bytes_ptr(pl), (CFIndex)xpc_data_get_length(pl));
		CFPropertyListRef dict = CFPropertyListCreateWithData(NULL, d, 0, NULL, NULL);
		CFStringRef kk = CFSTR("test.int");
		CHECK(dict && CFGetTypeID(dict) == CFDictionaryGetTypeID() && CFDictionaryGetValue(dict, kk) != NULL, "the delivered plist lacks the key written earlier");
		if (dict) CFRelease(dict);
		CFRelease(d);
	}
	int64_t slot_idx = xpc_dictionary_get_int64(r, "CFPreferencesShmemIndex");
	uint64_t state1 = xpc_dictionary_get_uint64(r, "CFPreferencesShmemState");
	xpc_release(r);
	int sfd = shm_open("apple.cfprefs.daemonv1", O_RDONLY, 0);
	uint32_t slot_now = 0xdeadbeef;
	if (sfd >= 0) {
		uint32_t* region = mmap(NULL, 16384, PROT_READ, MAP_SHARED, sfd, 0);
		if (region != MAP_FAILED && slot_idx >= 0 && slot_idx < 4096) { slot_now = region[slot_idx]; munmap(region, 16384); }
		close(sfd);
	}
	CHECK(slot_now == (uint32_t)state1, "the reply state %llu is not the slot value %u", (unsigned long long)state1, slot_now);
	CHECK(state1 > 0, "a layer that was written has state 0");
	w = request(1, TEST_DOMAIN, false);
	xpc_dictionary_set_string(w, "Key", "test.slot"); xpc_dictionary_set_string(w, "Value", "bump");
	xpc_release(call(w));
	r = call(request(1, TEST_DOMAIN, false));
	CHECK(xpc_dictionary_get_uint64(r, "CFPreferencesShmemState") == state1 + 1, "the state did not go up by one after one write (%llu -> %llu)", (unsigned long long)state1, (unsigned long long)xpc_dictionary_get_uint64(r, "CFPreferencesShmemState"));
	xpc_release(r);
	// a layer with no file gets the triple only
	xpc_object_t nofile = request(1, "org.darlinghq.cfprefsd-service-test.nofile", false);
	r = call(nofile);
	CHECK(xpc_dictionary_get_string(r, "CFPreferencesShmemName") != NULL && xpc_dictionary_get_value(r, "CFPreferencesPropertyList") == NULL, "a layer without a file did not get the bare triple");
	xpc_release(r);
	// batch items are read the same way
	items = xpc_array_create(NULL, 0);
	item = request(1, TEST_DOMAIN, false);
	xpc_array_append_value(items, item); xpc_release(item);
	b = request(5, TEST_DOMAIN, false);
	xpc_dictionary_set_value(b, "CFPreferencesMessages", items); xpc_release(items);
	r = call(b);
	replies = xpc_dictionary_get_value(r, "CFPreferencesMessages");
	CHECK(replies && xpc_array_get_count(replies) == 1 && xpc_dictionary_get_value(xpc_array_get_value(replies, 0), "CFPreferencesPropertyList") != NULL, "a batch item read has no CFPreferencesPropertyList");
	xpc_release(r);


	// a reply carries a bounded number of layer bytes: a layer that is too large is not delivered (no CFPreferencesPropertyList, the
	// bare triple), and in a batch the bytes are budgeted across the items (8 MiB per request): of three 3.5 MB layers the third is left out
	write_blob_plist("org.darlinghq.cfprefsd-service-test.huge", 9u * 1024 * 1024);
	r = call(request(1, "org.darlinghq.cfprefsd-service-test.huge", false));
	CHECK(xpc_dictionary_get_string(r, "CFPreferencesShmemName") != NULL && xpc_dictionary_get_value(r, "CFPreferencesPropertyList") == NULL, "a 9 MB layer was delivered or not answered");
	xpc_release(r);
	const char* bigs[3] = { "org.darlinghq.cfprefsd-service-test.big1", "org.darlinghq.cfprefsd-service-test.big2", "org.darlinghq.cfprefsd-service-test.big3" };
	items = xpc_array_create(NULL, 0);
	for (int i = 0; i < 3; i++) {
		write_blob_plist(bigs[i], 3584u * 1024);
		item = request(1, bigs[i], false);
		xpc_array_append_value(items, item); xpc_release(item);
	}
	b = request(5, TEST_DOMAIN, false);
	xpc_dictionary_set_value(b, "CFPreferencesMessages", items); xpc_release(items);
	r = call(b);
	replies = xpc_dictionary_get_value(r, "CFPreferencesMessages");
	if (replies && xpc_array_get_count(replies) == 3) {
		CHECK(xpc_dictionary_get_value(xpc_array_get_value(replies, 0), "CFPreferencesPropertyList") != NULL, "batch budget: item 0 (3.5 MB) was not delivered");
		CHECK(xpc_dictionary_get_value(xpc_array_get_value(replies, 1), "CFPreferencesPropertyList") != NULL, "batch budget: item 1 (7 MB in total) was not delivered");
		CHECK(xpc_dictionary_get_value(xpc_array_get_value(replies, 2), "CFPreferencesPropertyList") == NULL, "batch budget: item 2 (10.5 MB in total) was delivered");
		CHECK(xpc_dictionary_get_string(xpc_array_get_value(replies, 2), "CFPreferencesShmemName") != NULL, "batch budget: item 2 lost its triple");
	} else {
		CHECK(0, "the budget batch was not answered with 3 items");
	}
	xpc_release(r);
	{
		const char* gone[4] = { "huge", "big1", "big2", "big3" };
		for (int i = 0; i < 4; i++) { char gp[1024]; char dn[128]; snprintf(dn, sizeof(dn), "org.darlinghq.cfprefsd-service-test.%s", gone[i]); prefs_path(gp, sizeof(gp), "", dn); unlink(gp); }
	}


	// a few bytes must not expand into a huge write: a bplist whose objects refer to the level below twice (depth 22 is 8 million
	// objects when read) is refused quickly and nothing of it is written; the same shape at depth 10 (2047 objects) is accepted
	CFDataRef shallow = dag_bplist(10);
	r = write_data_value("test.dag.ok", shallow);
	CHECK(!is_error(r), "a shared-reference plist of 2047 objects was refused");
	xpc_release(r);
	CFRelease(shallow);
	CFDataRef bomb = dag_bplist(22);
	struct timespec started;
	clock_gettime(CLOCK_MONOTONIC, &started);
	r = write_data_value("test.dag.bomb", bomb);
	double took = seconds_since(started);
	CHECK(is_error(r), "a plist of 8 million objects in %zd bytes was not refused", (ssize_t)CFDataGetLength(bomb));
	CHECK(took < 3.0, "refusing the 8 million object plist took %.1f s (it must be refused before it is read)", took);
	xpc_release(r);
	CFRelease(bomb);
	CFTypeRef bombed = file_value(path, "test.dag.bomb");
	CHECK(bombed == NULL, "the oversized plist was written");
	if (bombed) CFRelease(bombed);
	CFTypeRef bomb_ok = file_value(path, "test.dag.ok");
	CHECK(bomb_ok != NULL, "the accepted shared-reference plist is not in the file");
	if (bomb_ok) CFRelease(bomb_ok);
	// a value larger than a layer may be (8 MiB) is refused too, and a plist that was already refused leaves the daemon answering
	{
		size_t big_bytes = 9u * 1024 * 1024;
		unsigned char* zeros = calloc(big_bytes, 1);
		CFDataRef blob = CFDataCreate(NULL, zeros, (CFIndex)big_bytes);
		CFDataRef big_plist = CFPropertyListCreateData(NULL, blob, kCFPropertyListBinaryFormat_v1_0, 0, NULL);
		r = write_data_value("test.big", big_plist);
		CHECK(is_error(r), "a 9 MiB value was not refused");
		xpc_release(r);
		CFRelease(big_plist); CFRelease(blob); free(zeros);
	}
	r = call(request(9, TEST_DOMAIN, false));
	CHECK(!is_error(r), "the daemon stopped answering after the oversized values");
	xpc_release(r);

	// a refused write looks like the real daemon's refusal: the triple (so the client keeps its slot) plus the error type and description, no invented keys
	w = request(1, TEST_DOMAIN, false);
	xpc_dictionary_set_string(w, "Key", "test.shared"); xpc_dictionary_set_string(w, "Value", "no");
	xpc_dictionary_set_value(w, "CFPreferencesUser", NULL);
	r = call(w);
	if (getuid() != 0) {
		CHECK(is_error(r), "a refused write has no CFPreferencesErrorType and CFPreferencesErrorDescription");
		CHECK(xpc_dictionary_get_string(r, "CFPreferencesShmemName") != NULL && xpc_dictionary_get_value(r, "CFPreferencesShmemIndex") != NULL, "a refused write lost the slot triple");
		CHECK(xpc_dictionary_get_value(r, "darling-error") == NULL, "a refused write still carries the invented darling-error key");
	}
	xpc_release(r);

	// the CFPreferencesUser value must be the current user (or the caller's own name): another name is refused, not served as the caller's layer
	{
		const char* names[] = { "root", "nobody-such-user", "" };
		for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
			w = request(1, TEST_DOMAIN, false);
			xpc_dictionary_set_string(w, "Key", "test.otheruser"); xpc_dictionary_set_string(w, "Value", "no");
			xpc_dictionary_set_string(w, "CFPreferencesUser", names[i]);
			r = call(w);
			CHECK(is_error(r), "a write for the user name '%s' was not refused", names[i]);
			xpc_release(r);
		}
		w = request(1, TEST_DOMAIN, false);
		xpc_dictionary_set_string(w, "Key", "test.ownname"); xpc_dictionary_set_string(w, "Value", "yes");
		xpc_dictionary_set_string(w, "CFPreferencesUser", getpwuid(getuid())->pw_name);
		r = call(w);
		CHECK(!is_error(r), "a write for the caller's own user name was refused");
		xpc_release(r);
		CFTypeRef other = file_value(path, "test.otheruser");
		CHECK(other == NULL, "a write for another user's name landed in the caller's plist");
		if (other) CFRelease(other);
	}

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
		CHECK(xpc_dictionary_get_string(r, "CFPreferencesShmemName") != NULL && xpc_dictionary_get_value(r, "CFPreferencesShmemIndex") != NULL, "a write that failed in the store lost the slot triple");
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
	// the switch itself: while it works for the caller the daemon holds the caller's ids, which differ from its own (as root, it can switch)
	CHECK(xpc_dictionary_get_int64(r, "darling-daemon-uid") != (int64_t)getuid(), "the daemon runs as the client's uid, so a missing identity switch would not show");
	CHECK(xpc_dictionary_get_int64(r, "darling-acting-uid") == (int64_t)getuid(), "the daemon acts as uid %lld for a client of uid %d", (long long)xpc_dictionary_get_int64(r, "darling-acting-uid"), (int)getuid());
	CHECK(xpc_dictionary_get_int64(r, "darling-acting-gid") == (int64_t)getgid(), "the daemon acts as gid %lld for a client of gid %d", (long long)xpc_dictionary_get_int64(r, "darling-acting-gid"), (int)getgid());
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
