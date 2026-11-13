# Host test: rootless_protected_volume fails loudly instead of answering with an invented value.
# usage: ruby tests/sandbox-rootless-protected-volume.rb [REPO_ROOT]
# src/sandbox/sandbox.c is built unmodified. A stand-in mach/message.h supplies audit_token_t.
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
Dir.mktmpdir('sandbox-app-') do |dir|
  Dir.mkdir("#{dir}/mach")
  File.write("#{dir}/mach/message.h", "typedef struct { unsigned int val[8]; } audit_token_t;\n")
  File.write("#{dir}/probe.c", <<~'C')
    #include <signal.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <sys/wait.h>
    #include <unistd.h>
    #define assert(c) do { if (!(c)) { puts("assertion failed: " #c); fflush(stdout); exit(1); } } while (0)
    int rootless_protected_volume(const char *path);
    int main(void) {
      fflush(stdout);
      pid_t child = fork();
      if (child == 0) {
        freopen("/dev/null", "w", stderr);
        rootless_protected_volume("/");
        _exit(0);
      }
      int status = 0;
      waitpid(child, &status, 0);
      /* a call aborts: neither 0 nor 1 is claimed for a volume */
      assert(WIFSIGNALED(status) && WTERMSIG(status) == SIGABRT);
      puts("PASS: rootless_protected_volume fails loudly");
      return 0;
    }
  C
  sources = ["#{root}/src/sandbox/sandbox.c"]
  resp = "#{root}/src/sandbox/responsibility.c"
  sources << resp if File.exist?(resp)
  out, st = Open3.capture2e('clang', '-w', '-D_GNU_SOURCE', '-D__APPLE_API_PRIVATE',
    "-I#{dir}", "-I#{root}/src/sandbox", "#{dir}/probe.c", *sources, '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e("timeout", "60", "#{dir}/probe", rlimit_core: 0)
  puts out
  abort 'rootless_protected_volume fail-loud regression' unless st.success?
end
