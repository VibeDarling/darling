require 'tmpdir'
require 'open3'
root=File.realpath(ARGV.fetch(0))
Dir.mktmpdir('vchroot-arguments-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #define DARLING_DEBUG 1
    #define main vchroot_main
    #include "#{root}/src/vchroot/vchroot.c"
    #undef main
    #include <stdarg.h>
    int __darling_vchroot(int fd) { abort(); }
    void darling_kprintf(const char *format, ...) {
      va_list args; va_start(args, format); vfprintf(stderr, format, args); va_end(args);
    }
    int main(void) {
      const char *zero[] = {NULL};
      const char *one[] = {"vchroot", NULL};
      const char *two[] = {"vchroot", "/prefix", NULL};
      if(vchroot_main(0,zero)!=1 || vchroot_main(1,one)!=1 || vchroot_main(2,two)!=1) return 1;
      return 0;
    }
  C
  out,status=Open3.capture2e('clang','-O1','-fsanitize=address,undefined',"#{dir}/probe.c",'-o',"#{dir}/probe")
  abort out unless status.success?
  out,status=Open3.capture2e("#{dir}/probe")
  abort out unless status.success?
  puts 'PASS vchroot debug builds reject short argument arrays without out-of-bounds reads'
end
