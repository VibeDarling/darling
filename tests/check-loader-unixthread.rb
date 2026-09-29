# Native test of the extracted ARM64 decoder, not the whole Mach-O parser.
require 'tmpdir'
require 'open3'
root=File.realpath(ARGV.fetch(0))
source=File.read("#{root}/src/startup/mldr/loader.c")
declarations=source[/#define MLDR_ARM_THREAD_STATE64 6.*?(?=\n#endif)/m]
decode=source[/case LC_UNIXTHREAD:.*?(?=case LC_LOAD_DYLINKER:)/m]
abort 'decode block missing' unless declarations && decode
Dir.mktmpdir('loader-unixthread-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #include <stdint.h>
    #include <stdlib.h>
    #include <stdio.h>
    #include <string.h>
    #undef __x86_64__
    #define __aarch64__ 1
    #define GEN_64BIT 1
    #define LC_UNIXTHREAD 5
    struct load_command { uint32_t cmd, cmdsize; };
    #{declarations}
    int main(int argc, char **argv) {
      struct { struct load_command lc; uint32_t flavor,count; struct mldr_arm_thread_state64 state; } fixture={0};
      fixture.lc.cmd=LC_UNIXTHREAD; fixture.lc.cmdsize=sizeof(fixture);
      fixture.flavor=MLDR_ARM_THREAD_STATE64; fixture.count=MLDR_ARM_THREAD_STATE64_COUNT;
      fixture.state.pc=0x123456789ULL;
      switch(atoi(argv[1])) {
        case 1: fixture.lc.cmdsize=8; break;
        case 2: fixture.flavor=1; break;
        case 3: fixture.count--; break;
        case 4: fixture.count++; break;
      }
      struct load_command *lc=&fixture.lc;
      uint64_t entryPoint=0, slide=0x1000;
      switch(lc->cmd) { #{decode} }
      return entryPoint==0x123457789ULL ? 0 : 2;
    }
  C
  out,status=Open3.capture2e('clang','-O1','-fsanitize=address,undefined',"#{dir}/probe.c",'-o',"#{dir}/probe")
  abort out unless status.success?
  5.times do |mode|
    out,status=Open3.capture2e("#{dir}/probe",mode.to_s)
    abort out unless status.exitstatus==(mode==0 ? 0 : 1)
  end
  puts 'PASS ARM64 LC_UNIXTHREAD entry/slide and four malformed-state cases'
end
