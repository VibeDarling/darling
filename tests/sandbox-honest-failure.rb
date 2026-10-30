# Host test: the sandbox stubs fail honestly and tolerate a NULL errorbuf.
# usage: ruby tests/sandbox-honest-failure.rb [REPO_ROOT]
# libsandbox's sandbox.c and the sandbox library's sandbox.c are built unmodified.
# Compiling or applying a profile must report failure with a message; the
# *_init entry points must not crash on a NULL errorbuf and must set *errorbuf = NULL
# on success; sandbox_free_params stays exported. A stand-in mach/message.h supplies audit_token_t.
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
Dir.mktmpdir('sandbox-') do |dir|
  Dir.mkdir("#{dir}/mach")
  File.write("#{dir}/mach/message.h", "typedef struct { unsigned int val[8]; } audit_token_t;\n")
  File.write("#{dir}/probe.c", <<~'C')
    #include <assert.h>
    #include <stdint.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    /* the two libraries declare overlapping names; declare only what is used */
    int sandbox_init(const char *, uint64_t, char **);
    int sandbox_init_with_parameters(const char *, uint64_t, const char *const[], char **);
    int sandbox_init_with_extensions(const char *, uint64_t, const char *const[], char **);
    int sandbox_wakeup_daemon(char **);
    void sandbox_free_error(char *);
    void *sandbox_compile_string(const char *, void *, char **);
    void *sandbox_compile_file(const char *, void *, char **);
    int sandbox_apply(void *);
    void sandbox_free_params(void *);
    void sandbox_free_profile(void *);
    int main(void) {
      char *err = NULL;
      /* a NULL errorbuf used to be dereferenced */
      /* return 0 is deliberate: guest helpers that ignore the error must keep running */
      assert(sandbox_init("p", 0, NULL) == 0);
      assert(sandbox_init_with_parameters("p", 0, NULL, NULL) == 0);
      assert(sandbox_init_with_extensions("p", 0, NULL, NULL) == 0);
      assert(sandbox_wakeup_daemon(NULL) == -1);
      err = (char *) 0x1234;
      assert(sandbox_init("p", 0, &err) == 0); assert(err == NULL);
      err = (char *) 0x1234;
      assert(sandbox_init_with_parameters("p", 0, NULL, &err) == 0); assert(err == NULL);
      err = (char *) 0x1234;
      assert(sandbox_init_with_extensions("p", 0, NULL, &err) == 0); assert(err == NULL);
      assert(sandbox_wakeup_daemon(&err) == -1); assert(err && !strcmp(err, "Not implemented")); sandbox_free_error(err); err = NULL;
      /* compiling reports failure and why; the caller's params are never written */
      void *params = (void *) 0x1234;
      assert(sandbox_compile_string("(version 1)", params, &err) == NULL);
      assert(err && strstr(err, "not supported")); free(err); err = NULL;
      assert(sandbox_compile_file("/nonexistent", params, &err) == NULL);
      assert(err && strstr(err, "not supported")); free(err);
      assert(sandbox_compile_string("(version 1)", NULL, NULL) == NULL);
      /* applying never claims a sandbox is in force */
      assert(sandbox_apply(NULL) != 0);
      sandbox_free_params(NULL); sandbox_free_profile(NULL);
      puts("PASS: sandbox stubs fail honestly");
      return 0;
    }
  C
  out, st = Open3.capture2e('clang', '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined', '-w', '-D_GNU_SOURCE', '-D__APPLE_API_PRIVATE',
    "-I#{dir}", "-I#{root}/src/libsandbox/include", "#{dir}/probe.c", "#{root}/src/libsandbox/src/sandbox.c",
    "#{root}/src/sandbox/sandbox.c", '-I' + "#{root}/src/sandbox", '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e("#{dir}/probe", rlimit_core: 0)
  puts out
  abort 'sandbox honest failure regression' unless st.success?
end
