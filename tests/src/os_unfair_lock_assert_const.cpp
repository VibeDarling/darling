// os_unfair_lock_assert_owner/_not_owner take `const os_unfair_lock *` in Apple's os/lock.h;
// C++ callers holding a const pointer (e.g. OpenCombine's lock_private.h) do not compile otherwise.
#include <os/lock.h>
#include <stdio.h>

static void assert_owner(const os_unfair_lock *lock)
{
	os_unfair_lock_assert_owner(lock);
}

static void assert_not_owner(const os_unfair_lock *lock)
{
	os_unfair_lock_assert_not_owner(lock);
}

int main()
{
	os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

	assert_not_owner(&lock);
	os_unfair_lock_lock(&lock);
	assert_owner(&lock);
	os_unfair_lock_unlock(&lock);
	assert_not_owner(&lock);

	printf("PASS: os_unfair_lock asserts accept const os_unfair_lock *\n");
	return 0;
}
