#include <sys/types.h>

// GUESS: the argument is a pid and the result is the pid of the process responsible for it (the process
// the system holds accountable for its actions, for example to attribute privacy permissions).
// Darling has no launchd responsibility chain, so every process is responsible for itself.
pid_t responsibility_get_pid_responsible_for_pid(pid_t pid)
{
	return pid;
}
