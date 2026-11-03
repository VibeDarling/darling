#import <Foundation/Foundation.h>
extern int authored_swift_disk_probe(const char *, const char *);
extern int authored_swift_disk_stage(void);
int main(int argc, const char **argv) {
    if (argc != 3) return 2;
    @autoreleasepool {
        @try { return authored_swift_disk_probe(argv[1], argv[2]); }
        @catch (id exception) {
            int stage=authored_swift_disk_stage();
            return stage>=70 && stage<=81 ? stage : 90;
        }
    }
}
