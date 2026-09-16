#define _GNU_SOURCE
#include <stdio.h>
#include <dirent.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdbool.h>
#include <sys/poll.h>
#include <sys/wait.h>
#include <sys/prctl.h>
#include <assert.h>
#include "../../src/startup/container-shutdown.h"
static void report(int fd) { pid_t p=getpid(); assert(write(fd,&p,sizeof(p))==sizeof(p)); }
static void forever(void) { for (;;) pause(); }
int main(int argc,char **argv) {
 if (argc==3) {
  int fd=atoi(argv[2]); signal(SIGTERM,SIG_IGN);
  pid_t c=fork(); assert(c>=0);
  if (!c) { report(fd); pid_t g=fork(); assert(g>=0); if (!g) { report(fd); forever(); } forever(); }
  report(fd); forever();
 }
 prctl(PR_SET_CHILD_SUBREAPER,1);
 int p[2]; assert(pipe(p)==0);
 pid_t unrelated=fork(); assert(unrelated>=0);
 if (!unrelated) { prctl(PR_SET_NAME,"darlingserver"); forever(); }
 pid_t external=fork(); assert(external>=0);
 if (!external) { signal(SIGTERM,SIG_IGN); forever(); }
 int externalHandle=shutdownHandle(external); assert(externalHandle>=0);
 pid_t server=fork(); assert(server>=0);
 if (!server) { char fd[32]; snprintf(fd,sizeof(fd),"%d",p[1]); execl("/proc/self/exe","darlingserver","/owned-test",fd,NULL); _exit(99); }
 close(p[1]); pid_t members[3];
 for(int i=0;i<3;i++) assert(read(p[0],&members[i],sizeof(pid_t))==sizeof(pid_t));
 close(p[0]);
 int handle=shutdownHandle(server); assert(handle>=0);
 assert(shutdownServerMatches(server,"/owned-test"));
 assert(!shutdownServerMatches(server,"/other-prefix"));
 int childhandles[3]; for(int i=0;i<3;i++) {childhandles[i]=shutdownHandle(members[i]); assert(childhandles[i]>=0);}
 assert(shutdownContainer(server,handle,external,externalHandle)); close(handle);
 struct pollfd externalPoll={.fd=externalHandle,.events=POLLIN};
 assert(poll(&externalPoll,1,2000)>0);close(externalHandle);
 assert(kill(unrelated,0)==0); assert(kill(getpid(),0)==0);
 for(int i=0;i<3;i++) { struct pollfd f={.fd=childhandles[i],.events=POLLIN}; assert(poll(&f,1,2000)>0); close(f.fd); }
 kill(unrelated,SIGTERM);
 while(wait(NULL)>0) {}
 puts("PASS: target descendants including TERM-resistant grandchildren stopped; unrelated named server and caller survived; wrong prefix rejected");
}
