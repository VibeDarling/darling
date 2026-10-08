#include <CoreFoundation/CoreFoundation.h>
#include <Security/SecTask.h>
#include <stdio.h>

int main(void)
{
    setbuf(stdout, NULL);
    puts("BEGIN: unsigned SecTask self/absent-entitlement probe");
    SecTaskRef task = SecTaskCreateFromSelf(NULL);
    if (!task) {
        puts("UNAVAILABLE: SecTaskCreateFromSelf returned NULL");
        return 77;
    }
    puts("OK: SecTaskCreateFromSelf returned a task");

    CFStringRef name = CFSTR("org.darling.synthetic.sectask.absent-20261008");
    CFErrorRef error = NULL;
    puts("CALL: SecTaskCopyValueForEntitlement with error output");
    CFTypeRef value = SecTaskCopyValueForEntitlement(task, name, &error);
    if (value) {
        puts("FAIL: unsigned fixture returned an invented entitlement value");
        CFRelease(value);
        if (error)
            CFRelease(error);
        CFRelease(task);
        return 1;
    }
    int unavailable = error != NULL;
    if (error) {
        char domain[256];
        if (!CFStringGetCString(CFErrorGetDomain(error), domain,
                                sizeof(domain), kCFStringEncodingUTF8)) {
            puts("FAIL: cannot render backend error domain");
            CFRelease(error);
            CFRelease(task);
            return 1;
        }
        printf("UNAVAILABLE: entitlement retrieval domain=%s code=%ld\n",
               domain, (long)CFErrorGetCode(error));
        CFRelease(error);
    } else {
        puts("OK: absent entitlement returned NULL without error");
    }

    puts("CALL: SecTaskCopyValueForEntitlement without error output");
    value = SecTaskCopyValueForEntitlement(task, name, NULL);
    if (value) {
        puts("FAIL: optional-error query returned an invented entitlement value");
        CFRelease(value);
        CFRelease(task);
        return 1;
    }
    CFRelease(task);
    if (unavailable)
        return 77;
    puts("PASS: unsigned SecTask self and absent entitlement");
    return 0;
}
