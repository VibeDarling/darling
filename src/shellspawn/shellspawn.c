/*
This file is part of Darling.

Copyright (C) 2017 Lubos Dolezel

Darling is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Darling is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/poll.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/event.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <termios.h>
#if defined(__APPLE__) || defined(__DARLING__)
#include <util.h>
#else
#include <pty.h>
#endif
#include "shellspawn.h"
#include "duct_signals.h"

#define DBG 0

int g_serverSocket = -1;
struct sigaction sigchld_oldaction;

void setupSocket(void);
int listenForConnections(void);
void spawnShell(int fd);
void setupSigchild(void);
void restoreSigchild(void);
void reapAll(void);

int main(int argc, const char** argv)
{
	// Ignore SIGPIPE in shellspawn itself: the per-connection child reports the
	// shell's exit status to a client socket that may already be closed, and that
	// write should fail with EPIPE instead of killing the process. The ignore is
	// inherited across fork and exec, so the shell gets the default back below.
	signal(SIGPIPE, SIG_IGN);

	// shellspawn (daemon) --fork()--> shellspawn (child) --fork()--> exec /bin/bash
	// in order to read the exit status of the shell process,
	// we have to allow it to become a zombie, therefore we need to
	// restore the sigaction of SIGCHLD of the child shellspawn
	setupSigchild();
	setupSocket();
	int status = listenForConnections();

	if (g_serverSocket != -1)
		close(g_serverSocket);
	return status == 0 ? 0 : EXIT_FAILURE;
}

void setupSocket(void)
{
	struct sockaddr_un addr = {
		.sun_family = AF_UNIX,
		.sun_path = SHELLSPAWN_SOCKPATH
	};

	g_serverSocket = socket(AF_UNIX, SOCK_STREAM, 0);
	if (g_serverSocket == -1)
	{
		perror("Creating unix socket");
		exit(EXIT_FAILURE);
	}

	fcntl(g_serverSocket, F_SETFD, FD_CLOEXEC);
	unlink(SHELLSPAWN_SOCKPATH);

	if (bind(g_serverSocket, (struct sockaddr*) &addr, sizeof(addr)) == -1)
	{
		perror("Binding the unix socket");
		exit(EXIT_FAILURE);
	}

	chmod(addr.sun_path, 0600);

	if (listen(g_serverSocket, 16384) == -1)
	{
		perror("Listening on unix socket");
		exit(EXIT_FAILURE);
	}
}

int listenForConnections(void)
{
	int sock;
	struct sockaddr_un addr;
	socklen_t len = sizeof(addr);
	bool logged = false;

	while (true)
	{
		sock = accept(g_serverSocket, (struct sockaddr*) &addr, &len);
		if (sock == -1)
		{
			if (errno == EINTR || errno == EAGAIN || errno == ECONNABORTED)
				continue;
			if (errno == EMFILE || errno == ENFILE || errno == ENOBUFS || errno == ENOMEM)
			{
				// Transient resource shortage: keep the service, retry shortly.
				// Log once per streak of failures, not every retry.
				if (!logged)
				{
					perror("shellspawn: accept");
					logged = true;
				}
				usleep(100 * 1000);
				continue;
			}
			perror("shellspawn: accept");
			return -1;
		}
		logged = false;

		if (fork() == 0)
		{
			restoreSigchild();
			fcntl(sock, F_SETFD, FD_CLOEXEC);
			spawnShell(sock);
			exit(EXIT_SUCCESS);
		}
		else
		{
			close(sock);
		}
	}
}

void spawnShell(int fd)
{
	pid_t shell_pid = -1;
	int shellfd[3] = { -1, -1, -1 };
	int pipefd[2];
	int rv;
	struct pollfd pfd[2];
	char** argv = NULL;
	int argc = 2;
	struct msghdr msg;
	struct iovec iov;
	char cmsgbuf[CMSG_SPACE(sizeof(int)) * 3];
	int kq;
	int wstatus = 0;
#ifndef DBG
	static int _dbg_cached = -1;
	if (_dbg_cached == -1) _dbg_cached = (getenv("DARLING_SHELLSPAWN_DEBUG") != NULL);
#define DBG _dbg_cached
#endif

	bool read_cmds = true;

	argv = (char**) malloc(sizeof(char*) * 3);
	argv[0] = "/bin/zsh";
	argv[1] = "--login";

	char* alloc_exec = NULL;

	// Read commands from client
	while (read_cmds)
	{
		struct shellspawn_cmd cmd;
		char* param = NULL;

		memset(&msg, 0, sizeof(msg));
		msg.msg_control = cmsgbuf;
		msg.msg_controllen = sizeof(cmsgbuf);

		iov.iov_base = &cmd;
		iov.iov_len = sizeof(cmd);
		msg.msg_iov = &iov;
		msg.msg_iovlen = 1;

		if (recvmsg(fd, &msg, 0) != sizeof(cmd))
		{
			if (DBG) puts("bad recvmsg");
			goto err;
		}

		if (cmd.data_length != 0)
		{
			param = (char*) malloc(cmd.data_length + 1);
			if (read(fd, param, cmd.data_length) != cmd.data_length)
				goto err;
			param[cmd.data_length] = '\0';
		}

		switch (cmd.cmd)
		{
			case SHELLSPAWN_ADDARG:
			{
				if (param != NULL)
				{
					argv = (char**) realloc(argv, sizeof(char*) * (argc + 1));
					argv[argc] = param;
					if (DBG) printf("add arg: %s\n", param);
					argc++;
				}
				break;
			}
			case SHELLSPAWN_SETENV:
			{
				if (param != NULL)
				{
					if (param[0] != '\0' && strchr(param, '=') != NULL)
					{
						if (DBG) printf("set env: %s\n", param);
						putenv(param);
					}
					else
					{
						free(param);
					}
				}
				break;
			}
			case SHELLSPAWN_CHDIR:
			{
				if (param != NULL)
				{
					if (DBG) printf("chdir: %s\n", param);
					chdir(param);
					free(param);
				}
				break;
			}
			case SHELLSPAWN_GO:
			{
				struct cmsghdr *cmptr = CMSG_FIRSTHDR(&msg);

				if (cmptr == NULL)
				{
					if (DBG) puts("bad cmptr");
					goto err;
				}
				if (cmptr->cmsg_level != SOL_SOCKET
						|| cmptr->cmsg_type != SCM_RIGHTS)
				{
					if (DBG) puts("bad cmsg level/type");
					goto err;
				}
				if (cmptr->cmsg_len != CMSG_LEN(sizeof(int) * 3))
				{
					if (DBG) printf("bad cmsg_len: %d\n", cmptr->cmsg_len);
					goto err;
				}

				memcpy(shellfd, CMSG_DATA(cmptr), sizeof(int) * 3);

				if (DBG) printf("go, fds={ %d, %d, %d }\n", shellfd[0], shellfd[1], shellfd[2]);
				free(param);
				read_cmds = false;
				break;
			}
			case SHELLSPAWN_SETUIDGID:
			{
				int* ids = (int*) param;
				if (cmd.data_length < 2*sizeof(int))
				{
					free(param);
					break;
				}

				setuid(ids[0]);
				setgid(ids[1]);
				free(param);

				break;
			}
			case SHELLSPAWN_SETEXEC:
			{
				argc = 0;
				argv = realloc(argv, 0);
				alloc_exec = param;
				if (DBG) printf("setexec: %s\n", param);
				break;
			}
		}
	}

	// Add terminating NULL
	argv = (char**) realloc(argv, sizeof(char*) * (argc + 1));
	argv[argc] = NULL;

	int ctty_master = -1;
	int ctty_slave = -1;

	// If stdin is not a terminal (e.g. piped input, test suite, non-interactive),
	// allocate a fallback PTY to serve as the session's controlling terminal so
	// that open("/dev/tty") and terminal size queries succeed without hijacking
	// the standard input/output pipes.
	if (!isatty(shellfd[0]))
	{
		struct winsize ws = { .ws_row = 24, .ws_col = 80, .ws_xpixel = 0, .ws_ypixel = 0 };
		if (openpty(&ctty_master, &ctty_slave, NULL, NULL, &ws) == 0)
		{
			fcntl(ctty_master, F_SETFD, FD_CLOEXEC);
			fcntl(ctty_slave, F_SETFD, FD_CLOEXEC);
			fcntl(ctty_master, F_SETFL, fcntl(ctty_master, F_GETFL) | O_NONBLOCK);
		}
	}

	if (pipe(pipefd) == -1)
		goto err;

	shell_pid = fork();
	if (shell_pid == 0)
	{
		setsid();
		setpgrp();

		dup2(shellfd[0], STDIN_FILENO);
		dup2(shellfd[1], STDOUT_FILENO);
		dup2(shellfd[2], STDERR_FILENO);

		if (ctty_slave != -1)
		{
			ioctl(ctty_slave, TIOCSCTTY, 0);
		}
		else
		{
			ioctl(STDIN_FILENO, TIOCSCTTY, STDIN_FILENO);
		}

		if (ctty_slave != -1)
			close(ctty_slave);
		if (ctty_master != -1)
			close(ctty_master);

		close(fd);
		close(shellfd[0]);
		close(shellfd[1]);
		close(shellfd[2]);

		fcntl(pipefd[1], F_SETFD, FD_CLOEXEC);

		// An ignored signal stays ignored across exec; the shell and every program
		// started from it must see the default SIGPIPE, or `cmd | head` pipelines
		// print "Broken pipe" errors and writers that ignore errors spin.
		signal(SIGPIPE, SIG_DFL);

		// In future, we may support spawning something else than Zsh
		// and check the provided shell against /etc/shells
		execv(alloc_exec ? alloc_exec : "/bin/zsh", argv);

		rv = errno;
		write(pipefd[1], &rv, sizeof(rv));
		close(pipefd[1]);

		exit(EXIT_FAILURE);
	}

	if (ctty_slave != -1)
	{
		close(ctty_slave);
		ctty_slave = -1;
	}

	close(shellfd[0]);
	close(shellfd[1]);
	close(shellfd[2]);

	if (alloc_exec)
	{
		free(alloc_exec);
		alloc_exec = NULL;
	}

	// Check that exec succeeded
	close(pipefd[1]); // close the write end
	if (read(pipefd[0], &rv, sizeof(rv)) == sizeof(rv))
	{
		errno = rv;
		fprintf(stderr, "shellspawn: execv failed: %s (errno=%d)\n", strerror(errno), errno);
		goto err;
	}
	close(pipefd[0]);

	if (DBG) { puts("shellspawn: execv succeeded, entering poll loop"); fflush(stdout); }

	struct pollfd pfd_in[2];
	memset(pfd_in, 0, sizeof(pfd_in));
	pfd_in[0].fd = fd;
	pfd_in[0].events = POLLIN;
	pfd_in[1].fd = ctty_master;
	pfd_in[1].events = (ctty_master != -1) ? POLLIN : 0;
	int poll_cnt = (ctty_master != -1) ? 2 : 1;

	while (true)
	{
		int chk_wstatus = 0;
		pid_t wpid = waitpid(shell_pid, &chk_wstatus, WNOHANG);
		if (wpid == shell_pid)
		{
			wstatus = chk_wstatus;
			goto done_reaped;
		}
		else if (wpid < 0 && errno != EINTR)
		{
			wstatus = 0;
			goto done_reaped;
		}

		int pret = poll(pfd_in, poll_cnt, 50);
		if (pret < 0)
		{
			if (errno == EINTR)
				continue;
			break;
		}

		if (pret > 0 && ctty_master != -1 && (pfd_in[1].revents & (POLLIN | POLLHUP | POLLERR)))
		{
			char drain_buf[512];
			while (read(ctty_master, drain_buf, sizeof(drain_buf)) > 0);
			if (pfd_in[1].revents & (POLLHUP | POLLERR))
			{
				pfd_in[1].fd = -1;
				pfd_in[1].events = 0;
			}
		}

		if (pret > 0 && (pfd_in[0].revents & (POLLIN | POLLHUP | POLLERR)))
		{
			if (pfd_in[0].revents & POLLIN)
			{
				struct shellspawn_cmd cmd;

				if (read(fd, &cmd, sizeof(cmd)) != sizeof(cmd))
				{
					if (DBG) { puts("Cannot read cmd (EOF or error)"); fflush(stdout); }
					break;
				}

				switch (cmd.cmd)
				{
					case SHELLSPAWN_SIGNAL:
					{
						int linux_signal, darwin_signal;

						if (cmd.data_length != sizeof(int))
							goto err;

						if (read(fd, &linux_signal, sizeof(int)) != sizeof(int))
							goto err;

						// Convert Linux signal number to Darwin signal number
						darwin_signal = signum_linux_to_bsd(linux_signal);
						if (DBG) printf("rcvd signal %d -> %d\n", linux_signal, darwin_signal);

						if (darwin_signal != 0)
						{
							int fg_pid = tcgetpgrp(shellfd[0]);
							if (fg_pid != -1)
							{
								if (DBG) printf("fg_pid = %d\n", fg_pid);
								kill(fg_pid, darwin_signal);
							}
							else
								kill(-shell_pid, darwin_signal);
						}

						break;
					}
					default:
						goto err;
				}
			}
			else
			{
				// Client disconnected
				break;
			}
		}
	}

done:
	// Reap the child
	if (waitpid(shell_pid, &wstatus, 0) != shell_pid)
	{
		wstatus = 0;
	}

done_reaped:
	if (WIFEXITED(wstatus))
		wstatus = WEXITSTATUS(wstatus);
	else if (WIFSIGNALED(wstatus))
		wstatus = 128 + WTERMSIG(wstatus);
	else
		wstatus = 0;
	
	// Report exit code back to the client
	write(fd, &wstatus, sizeof(int));

	if (DBG) printf("Shell terminated with exit code %d\n", wstatus);
	close(fd);
	if (ctty_master != -1)
	{
		close(ctty_master);
		ctty_master = -1;
	}

	reapAll();
	return;
err:
	if (DBG) fprintf(stderr, "Error spawning shell: %s\n", strerror(errno));

	if (ctty_master != -1)
		close(ctty_master);
	if (ctty_slave != -1)
		close(ctty_slave);

	for (int i = 0; i < 3; i++)
	{
		if (shellfd[i] != -1)
			close(shellfd[i]);
	}

	if (shell_pid != -1)
		kill(shell_pid, SIGKILL);

	close(fd);
	reapAll();
}

void setupSigchild(void)
{
	struct sigaction sigchld_action = {
		.sa_handler = SIG_DFL,
		.sa_flags = SA_NOCLDWAIT
	};
	sigaction(SIGCHLD, &sigchld_action, &sigchld_oldaction);
}

void restoreSigchild(void)
{
	sigaction(SIGCHLD, &sigchld_oldaction, NULL);
}

void reapAll(void)
{
    while (waitpid((pid_t)(-1), 0, WNOHANG) > 0);
}
