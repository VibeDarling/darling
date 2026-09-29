# Test the actual segment skip/address block with controlled segment metadata.
# This does not exercise mmap, file parsing, or complete loader startup.
require 'tmpdir'
require 'open3'
root = File.realpath(ARGV.fetch(0))
source = File.read("#{root}/src/startup/mldr/loader.c")
block = source[/\t+\/\/ Skip zero-vmsize segments.*?(?=\n\t+const size_t host_ps)/m]
abort 'segment address block missing' unless block
Dir.mktmpdir('loader-segment-slide-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #include <stdint.h>
    #include <string.h>
    #include <assert.h>
    #include <stdio.h>
    struct segment { const char *segname; uintptr_t vmaddr, vmsize; };
    struct results { uintptr_t vm_addr_max; };
    static uintptr_t address(struct segment *seg, uintptr_t slide, int useprot) {
      struct results result={0}, *lr=&result;
      switch (1) { case 1: {
        #{block}
        return seg_addr;
      } }
      return UINTPTR_MAX; /* skipped, not an address sent to mmap */
    }
    int main(void) {
      struct segment s={"__TEXT",0,4096};
      assert(address(&s,0x200000000ULL,5)==0x200000000ULL);
      s.vmaddr=0x1000;
      assert(address(&s,0x200000000ULL,5)==0x200001000ULL);
      assert(address(&s,0,5)==0x1000);
      s.segname="__PAGEZERO"; s.vmaddr=0;
      assert(address(&s,0x200000000ULL,0)==UINTPTR_MAX);
      s.segname="__TEXT";
      assert(address(&s,0x200000000ULL,0)==UINTPTR_MAX);
      s.segname="__DWARF"; s.vmaddr=0x1000; s.vmsize=0;
      assert(address(&s,0x200000000ULL,1)==UINTPTR_MAX);
      puts("PASS zero/nonzero segment slides and unmapped segment exclusions");
    }
  C
  output,status=Open3.capture2e('clang','-O1','-fsanitize=address,undefined',"#{dir}/probe.c",'-o',"#{dir}/probe")
  abort output unless status.success?
  abort 'segment address regression failed' unless system("#{dir}/probe",rlimit_core:0)
end
