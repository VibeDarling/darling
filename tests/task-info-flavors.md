# task_info flavor regression

Build task-info-flavors.c as a plain C executable for the guest and run it inside a throwaway prefix under a host-side timeout, for example `timeout 30 darling shell <path>/task-info-flavors`. Pass is the line `PASS` and exit status 0. The checks, in order:

- an unknown flavor returns KERN_INVALID_ARGUMENT;
- task_info(mach_thread_self(), MACH_TASK_BASIC_INFO) returns KERN_INVALID_ARGUMENT (the thread port converts to TASK_NULL on the server);
- MACH_TASK_BASIC_INFO afterwards returns KERN_SUCCESS with a non-zero resident size, so the server is still serving;
- TASK_BASIC_INFO returns KERN_SUCCESS with a non-zero resident size on both x86_64 (flavor 5) and arm64 (TASK_BASIC_INFO_64_2, flavor 18).

Before the darlingserver fix the unknown flavor aborts darlingserver (`stub (unsafe): task_info:unimplemented flavor`, SIGABRT) and the thread-port call crashes it on a NULL dereference (SIGSEGV); every other process in the prefix dies with the server and this process blocks waiting for a reply. The host-side timeout is what ends that run: a guest alarm() is not a reliable hang breaker here, because guest signal delivery goes through RPCs to darlingserver. Disable core dumps for the baseline run.

Scope: this fixes task_info only. The same abort-on-guest-input class is still open in thread_info's default case (duct-tape/src/thread.c), host_info's HOST_SCHED_INFO, HOST_RESOURCE_SIZES, HOST_CAN_HAS_DEBUGGER and HOST_VM_PURGABLE (duct-tape/src/host.c), mach_vm_region's default case (duct-tape/src/memory.c), and the MIG routines whose whole body is dtape_stub_unsafe().

Known limitations, tracked separately: the basic-info flavors report user_time and system_time as 0 and policy as 0 (xnu reports terminated-thread CPU time and POLICY_TIMESHARE), and this fixture does not check those fields. darlingserver's memory-info hook calls Process::memoryInfo(), which throws for a dead process with no try/catch and leaves the sizes uninitialized if /proc cannot be read.

Not yet run: written without a build.
