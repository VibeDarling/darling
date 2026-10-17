# Host regression test for mldr's socket bitmap shrink path.
# usage: ruby tests/mldr-socket-bitmap-shrink.rb [REPO_ROOT]
# The helpers are cut out of mldr.c and built with ASan and UBSan, so the test
# follows the real source. It fails before the fix (a live slot is handed out
# twice, then a double free after the last slot is released) and passes after.
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
loader = File.read("#{root}/src/startup/mldr/mldr.c")
types = loader[/typedef struct socket_bitmap \{.*?(?=void __mldr_socket_bitmap_prefork)/m] or abort 'bitmap types missing'
funcs = loader[/static int socket_bitmap_get.*?^static void socket_bitmap_put.*?^\};\n/m] or abort 'bitmap helpers missing'
Dir.mktmpdir('bitmap-shrink-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #define _GNU_SOURCE
    #include <assert.h>
    #include <pthread.h>
    #include <stdbool.h>
    #include <stddef.h>
    #include <stdint.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <sys/resource.h>
    #{types}
    #{funcs}
    static int slot[64];
    int main(void) {
      for (int i = 0; i < 24; i++) { slot[i] = socket_bitmap_get(&socket_bitmap); assert(slot[i] >= 0); }
      /* release slots 16..22 (not the last), then the last one: slots 0..15 stay live */
      for (int i = 16; i < 23; i++) socket_bitmap_put(&socket_bitmap, slot[i]);
      socket_bitmap_put(&socket_bitmap, slot[23]);
      assert(socket_bitmap.bit_length == 16);
      for (int i = 0; i < 12; i++) {
        int fd = socket_bitmap_get(&socket_bitmap);
        for (int j = 0; j < 16; j++) assert(fd != slot[j]); /* a live descriptor was handed out again */
        slot[16 + i] = fd;
      }
      for (int i = 0; i < 28; i++) socket_bitmap_put(&socket_bitmap, slot[i]);
      /* releasing every slot frees the block; it must not dangle */
      assert(socket_bitmap.bit_length == 0 && socket_bitmap.bits == NULL);
      int fd = socket_bitmap_get(&socket_bitmap); assert(fd >= 0); /* regrow after shrink to zero */
      socket_bitmap_put(&socket_bitmap, fd);
      puts("PASS: bitmap shrink keeps live slots and frees cleanly");
      return 0;
    }
  C
  out, status = Open3.capture2e('clang', '-pthread', '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined', '-w', "#{dir}/probe.c", '-o', "#{dir}/probe")
  abort out unless status.success?
  out, status = Open3.capture2e("#{dir}/probe", rlimit_core: 0)
  puts out
  abort 'socket bitmap shrink regression' unless status.success?
end
