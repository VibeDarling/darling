# Host test: a shell started by shellspawn gets the default SIGPIPE.
# usage: ruby tests/shellspawn-sigpipe-disposition.rb [REPO_ROOT]
# shellspawn ignores SIGPIPE in its own process, and an ignored signal stays
# ignored across fork and exec. The harness takes the signal() call from main()
# and the child branch of spawnShell() (up to and including execv) from
# shellspawn.c, runs them as daemon -> fork -> exec of /bin/sh, and reads
# the SigIgn mask of the exec'd program from /proc. SIGPIPE (bit 13) must not
# be set, SIGPIPE must not be blocked either (SigBlk), and `yes | head` must die
# silently from SIGPIPE (no "Broken pipe"). It runs twice: with an explicit shell
# (alloc_exec set) and with the default shell path (alloc_exec NULL, "/bin/zsh"
# replaced by /bin/sh because zsh may not exist on the host).
require 'tmpdir'
require 'open3'

root = ARGV.fetch(0, File.expand_path('..', __dir__))

unless File.exist?('/proc/self/status')
  puts 'SKIP: /proc/self/status not available on this host'
  exit 0
end

src = File.read("#{root}/src/shellspawn/shellspawn.c")
ignore = src[/^\s*signal\(SIGPIPE, SIG_IGN\);$/]&.strip or abort 'main() no longer ignores SIGPIPE'
child = src[/\tshell_pid = fork\(\);\n\tif \(shell_pid == 0\)\n\t\{\n(.*?execv\(alloc_exec[^;]*;)/m, 1] or abort 'spawnShell child branch not found'

cc = ENV.fetch('CC', 'clang')

['explicit', 'default'].each do |mode|
Dir.mktmpdir('shellspawn-sigpipe-') do |dir|
  probe_child = mode == 'default' ? child.gsub('"/bin/zsh"', '"/bin/sh"') : child
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
      int shellfd[3] = { open("/dev/null", O_RDONLY), out[1], dup(out[1]) };
      int fd = open("/dev/null", O_RDONLY);
      int ctty_master = -1, ctty_slave = -1;
      char *alloc_exec = #{mode == 'default' ? 'NULL' : '"/bin/sh"'};
      char *argv[] = { "sh", "-c", "grep '^Sig[IB][gl][nk]' /proc/self/status; yes | head -c1 >/dev/null; exit 0", NULL };
      if (fork() == 0) {            /* the per-connection child */
    #{probe_child}
        _exit(1);
      }
      close(out[1]);
      close(shellfd[0]);
      close(shellfd[2]);
      close(fd);
      close(pipefd[0]);
      close(pipefd[1]);

      char buf[512] = {0};
      size_t total = 0;
      ssize_t n;
      while ((n = read(out[0], buf + total, sizeof(buf) - 1 - total)) > 0) {
        total += (size_t)n;
      }
      close(out[0]);
      wait(NULL);

      fputs(buf, stdout);
      unsigned long mask = 0;
      char *p = strstr(buf, "SigIgn:");
      if (!p || sscanf(p, "SigIgn: %lx", &mask) != 1) return 3;
      if (mask & (1UL << (SIGPIPE - 1))) { puts("FAIL: SIGPIPE is ignored in the shell"); return 1; }
      unsigned long blk = 0;
      p = strstr(buf, "SigBlk:");
      if (!p || sscanf(p, "SigBlk: %lx", &blk) != 1) return 3;
      if (blk & (1UL << (SIGPIPE - 1))) { puts("FAIL: SIGPIPE is blocked in the shell"); return 1; }
      if (strstr(buf, "Broken pipe")) { puts("FAIL: yes reported a write error instead of dying from SIGPIPE"); return 1; }
      puts("PASS: the shell starts with the default SIGPIPE");
      return 0;
    }
  C
  out, st = Open3.capture2e(cc, '-Wall', "#{dir}/probe.c", '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e("#{dir}/probe")
  puts "[#{mode}] #{out}"
  abort "shellspawn SIGPIPE regression (#{mode})" unless st.success?
end
end
