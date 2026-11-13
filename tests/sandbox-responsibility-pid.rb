# Host test: responsibility_get_pid_responsible_for_pid answers the pid itself
# usage: ruby tests/sandbox-responsibility-pid.rb [REPO_ROOT]
# src/sandbox/responsibility.c is built unmodified with ASan and UBSan. A stand-in mach/message.h supplies audit_token_t.
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
Dir.mktmpdir('sandbox-app-') do |dir|
  Dir.mkdir("#{dir}/mach")
  File.write("#{dir}/mach/message.h", "typedef struct { unsigned int val[8]; } audit_token_t;\n")
  File.write("#{dir}/probe.c", <<~'C')
    #include <errno.h>
    #include <stdint.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <sys/types.h>
    #include <unistd.h>
    #define assert(c) do { if (!(c)) { puts("assertion failed: " #c); fflush(stdout); exit(1); } } while (0)
    pid_t responsibility_get_pid_responsible_for_pid(pid_t pid);
    int main(void) {
      /* no responsibility chain: a process is responsible for itself */
      assert(responsibility_get_pid_responsible_for_pid(getpid()) == getpid());
      assert(responsibility_get_pid_responsible_for_pid(1) == 1);
      puts("PASS: responsibility_get_pid_responsible_for_pid answers the pid itself");
      return 0;
    }
  C
  sources = ["#{root}/src/sandbox/sandbox.c"]
  resp = "#{root}/src/sandbox/responsibility.c"
  sources << resp if File.exist?(resp)
  out, st = Open3.capture2e('clang', '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined', '-w', '-D_GNU_SOURCE', '-D__APPLE_API_PRIVATE',
    "-I#{dir}", "-I#{root}/src/sandbox", "#{dir}/probe.c", *sources, '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e("timeout", "60", "#{dir}/probe", rlimit_core: 0)
  puts out
  abort 'responsibility_get_pid_responsible_for_pid answers the pid itself regression' unless st.success?
end
