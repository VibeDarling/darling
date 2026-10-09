// CFLAGS: -framework foundation -framework corefoundation

#import <Foundation/NSValue.h>
#include <stdio.h>

#define check(cond) do { int ok = (cond); printf("%s: %s\n", ok ? "Pass" : "FAIL", #cond); if (!ok) exitcode = 1; } while (0)

int main(void)
{
	int exitcode = 0;

	check([[NSNumber numberWithChar:5] charValue] == 5);
	check([[NSNumber numberWithChar:-56] charValue] == -56);
	check([[NSNumber numberWithInt:65] charValue] == 65);
	check([[NSNumber numberWithBool:YES] charValue] == 1);
	check([[NSNumber numberWithBool:NO] charValue] == 0);

	return exitcode;
}
