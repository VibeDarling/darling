#define _GNU_SOURCE
#include <stdio.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
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
#include <sys/sendfile.h>
#include <assert.h>
#include "../../src/startup/container-shutdown.h"
static void report(int fd) { pid_t p=getpid(); assert(write(fd,&p,sizeof(p))==sizeof(p)); }
static void forever(void) { for (;;) pause(); }
static void copy(const char *from, const char *to) {
 int in=open(from,O_RDONLY), out=open(to,O_WRONLY|O_CREAT|O_TRUNC,0755); struct stat st;
 assert(in>=0 && out>=0 && fstat(in,&st)==0 && sendfile(out,in,NULL,st.st_size)==st.st_size);
 close(in); close(out);
}
static char owned[4096+64], other[4096+64];
static char *envOwned[]={owned,NULL}, *envOther[]={other,NULL}, *envNone[]={NULL};
static pid_t spawn(const char *exe, char **env, const char *mode, int fd) {
 pid_t c=fork(); assert(c>=0);
 if (!c) { char f[16]; snprintf(f,sizeof(f),"%d",fd); char *argv[]={"child",(char*)mode,f,NULL}; execve(exe,argv,env); _exit(99); }
 return c;
}
static pid_t readPid(int fd) { pid_t p; assert(read(fd,&p,sizeof(p))==sizeof(p)); return p; }
static bool alive(pid_t p) { char s[64]; snprintf(s,sizeof(s),"/proc/%d/stat",p); FILE *f=fopen(s,"r"); if(!f) return false; char b[512]; char *r=fgets(b,sizeof(b),f); fclose(f); char *e=r?strrchr(b,')'):NULL; return e && e[2]!='Z'; }
int main(int argc,char **argv) {
 // Direct children die with the test if it aborts; grandchildren do not, so they cannot mask a reaping bug.
 if (!strcmp(argv[0],"darlingserver")) { prctl(PR_SET_PDEATHSIG,SIGKILL); forever(); }
 if (argc==3) {
  int fd=atoi(argv[2]); signal(SIGTERM,SIG_IGN); prctl(PR_SET_PDEATHSIG,SIGKILL);
  if (!strcmp(argv[1],"grand")) { pid_t g=fork(); assert(g>=0); if (!g) { report(fd); forever(); } }
  report(fd); forever();
 }
 prctl(PR_SET_CHILD_SUBREAPER,1);
 const char *base=getenv("TMPDIR"); char tmpl[4096], dir[4096], self[4096];
 snprintf(tmpl,sizeof(tmpl),"%s/orphan-cleanup-XXXXXX",base?base:"/tmp");
 assert(mkdtemp(tmpl) && realpath(tmpl,dir));
 ssize_t n=readlink("/proc/self/exe",self,sizeof(self)-1); assert(n>0); self[n]=0;
 char a[4096+16], b[4096+16], dirA[4096+4], dirB[4096+4];
 snprintf(dirA,sizeof(dirA),"%s/a",dir); snprintf(dirB,sizeof(dirB),"%s/b",dir);
 assert(mkdir(dirA,0700)==0 && mkdir(dirB,0700)==0);
 snprintf(a,sizeof(a),"%s/mldr",dirA); snprintf(b,sizeof(b),"%s/mldr",dirB);
 copy(self,a); copy(self,b);
 const char *const mldr[2]={a,b};
 // The prefix is this run's own directory, so a leftover from another run cannot interfere.
 snprintf(owned,sizeof(owned),"__mldr_sockpath=%s/.darlingserver.sock",dir);
 snprintf(other,sizeof(other),"__mldr_sockpath=%s/other/.darlingserver.sock",dir);
 int p[2]; assert(pipe(p)==0);
 pid_t guests[3];
 spawn(a,envOwned,"grand",p[1]); guests[0]=readPid(p[0]); guests[1]=readPid(p[0]);
 spawn(b,envOwned,"plain",p[1]); guests[2]=readPid(p[0]);
 // Replace a/mldr on disk: the running processes' exe now ends in " (deleted)".
 assert(unlink(a)==0); copy(self,a);
 pid_t spared[3];
 spawn(self,envOwned,"plain",p[1]); spared[0]=readPid(p[0]);   // not an mldr binary
 spawn(a,envOther,"plain",p[1]); spared[1]=readPid(p[0]);      // another prefix
 spawn(a,envNone,"plain",p[1]); spared[2]=readPid(p[0]);       // no socket env
 close(p[1]); close(p[0]);
 pid_t server=fork(); assert(server>=0);
 if (!server) { execl(self,"darlingserver",dir,NULL); _exit(99); }
 for (int i=0;i<50 && shutdownServerMatches(server,dir) != 1;i++) usleep(20000);
 assert(shutdownServerMatches(server,dir) == 1);
 pid_t live=-1;
 assert(shutdownOrphans(dir,getuid(),mldr,&live)==0 && live==server);
 for(int i=0;i<3;i++) assert(alive(guests[i]) && alive(spared[i]));
 kill(server,SIGKILL); waitpid(server,NULL,0);
 assert(shutdownOrphans(dir,getuid(),mldr,&live)==3 && live==0);
 while (waitpid(-1,NULL,WNOHANG)>0) {}
 for(int i=0;i<3;i++) { assert(!alive(guests[i])); assert(alive(spared[i])); }
 assert(shutdownOrphans(dir,getuid(),mldr,&live)==0 && live==0);
 for(int i=0;i<3;i++) kill(spared[i],SIGKILL);
 while(wait(NULL)>0) {}
 unlink(a); unlink(b); rmdir(dirA); rmdir(dirB); rmdir(dir);
 puts("PASS: a live server blocks reaping; after it dies, this prefix's mldr guests (including a grandchild, a TERM-resistant child and a replaced binary) are stopped; non-mldr, other-prefix and env-less processes survive");
}
