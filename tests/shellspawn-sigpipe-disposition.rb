# Host test: a shell started by shellspawn gets the default SIGPIPE.
# usage: ruby tests/shellspawn-sigpipe-disposition.rb [REPO_ROOT]
# shellspawn ignores SIGPIPE in its own process, and an ignored signal stays
# ignored across fork and exec. The harness takes the signal() call from main()
# and the whole child branch of spawnShell() (up to and including execv) from
# shellspawn.c, runs them as daemon -> fork -> fork -> exec of /bin/sh, and reads
# the SigIgn mask of the exec'd program from /proc. SIGPIPE (bit 13) must not
# be set, and `yes | head` must die silently from SIGPIPE (no "Broken pipe").
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
src = File.read("#{root}/src/shellspawn/shellspawn.c")
ignore = src[/^\tsignal\(SIGPIPE, SIG_IGN\);$/] or abort 'main() no longer ignores SIGPIPE'
child = src[/\tshell_pid = fork\(\);\n\tif \(shell_pid == 0\)\n\t\{\n(.*?execv\(alloc_exec[^;]*;)/m, 1] or abort 'spawnShell child branch not found'
Dir.mktmpdir('shellspawn-sigpipe-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #define _GNU_SOURCE
    #include <errno.h>
    #include <fcntl.h>
    #include <signal.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <sys/ioctl.h>
    #include <sys/wait.h>
    #include <unistd.h>
    int main(void) {
    #{ignore}
      int out[2], pipefd[2];
      if (pipe(out) || pipe(pipefd)) return 2;
      int shellfd[3] = { open("/dev/null", O_RDONLY), out[1], out[1] };
      int fd = open("/dev/null", O_RDONLY);
      char *alloc_exec = "/bin/sh";
      char *argv[] = { "sh", "-c", "grep '^SigIgn' /proc/self/status; yes | head -c1 >/dev/null; exit 0", NULL };
      int shell_pid;
      if (fork() == 0) {            /* the per-connection child */
    #{child}
        _exit(1);
      }
      close(out[1]);
      char buf[512] = {0};
      read(out[0], buf, sizeof(buf) - 1);
      wait(NULL);
      fputs(buf, stdout);
      unsigned long mask = 0;
      char *p = strstr(buf, "SigIgn:");
      if (!p || sscanf(p, "SigIgn: %lx", &mask) != 1) return 3;
      if (mask & (1UL << (SIGPIPE - 1))) { puts("FAIL: SIGPIPE is ignored in the shell"); return 1; }
      if (strstr(buf, "Broken pipe")) { puts("FAIL: yes reported a write error instead of dying from SIGPIPE"); return 1; }
      puts("PASS: the shell starts with the default SIGPIPE");
      return 0;
    }
  C
  out, st = Open3.capture2e('clang', '-w', "#{dir}/probe.c", '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e("#{dir}/probe")
  puts out
  abort 'shellspawn SIGPIPE regression' unless st.success?
end
