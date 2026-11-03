#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
static char checkpointPath[4096];
void authored_swift_disk_checkpoint(int value) {
    if (value<70 || value>116) _exit(49);
    char data[8]; int length=snprintf(data,sizeof(data),"%d\n",value);
    int descriptor=open(checkpointPath,O_WRONLY|O_CREAT|O_TRUNC,0600);
    if (descriptor<0 || write(descriptor,data,length)!=length || close(descriptor)!=0) _exit(48);
}
extern int authored_swift_disk_probe(const char *, const char *);
extern int authored_swift_disk_stage(void);
int main(int argc, const char **argv) {
    if (argc != 3) return 2;
    if (snprintf(checkpointPath,sizeof(checkpointPath),"%s.checkpoint",argv[2])>=(int)sizeof(checkpointPath)) return 2;
    authored_swift_disk_checkpoint(70);
    @autoreleasepool {
        @try { return authored_swift_disk_probe(argv[1], argv[2]); }
        @catch (id exception) {
            int stage=authored_swift_disk_stage();
            return stage>=70 && stage<=116 ? stage : 90;
        }
    }
}
