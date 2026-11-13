# Host test: sandbox_extension_issue_file fails honestly
# usage: ruby tests/sandbox-extension-issue-file.rb [REPO_ROOT]
# src/sandbox/sandbox.c is built unmodified with ASan and UBSan. A stand-in mach/message.h supplies audit_token_t.
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
    /* prototype as in WebKit's SandboxSPI.h; sandbox.h deliberately does not declare it */
    char *sandbox_extension_issue_file(const char *extension_class, const char *path, uint32_t flags);
    int main(void) {
      /* no extension can be issued: NULL and errno, never a token a caller would free() or consume */
      errno = 0;
      assert(sandbox_extension_issue_file("com.apple.app-sandbox.read", "/tmp", 0) == NULL);
      assert(errno == ENOTSUP);
      errno = 0;
      assert(sandbox_extension_issue_file(NULL, NULL, 0) == NULL && errno == ENOTSUP);
      puts("PASS: sandbox_extension_issue_file fails honestly");
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
  abort 'sandbox_extension_issue_file fails honestly regression' unless st.success?
end
