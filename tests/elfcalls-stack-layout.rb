# Exercise the complete production 64-bit stack constructor with controlled
# callback initialization. This is not a loader/guest startup test.
require 'tmpdir'
require 'open3'
root=File.realpath(ENV.fetch('PROBE_ROOT',File.expand_path('..',__dir__)))
Dir.mktmpdir('elfcalls-stack-') do |dir|
  File.write("#{dir}/darling-config.h", "#define SYSTEM_ROOT \"/Volumes/SystemRoot\"\n")
  code=<<~C
    #include <assert.h>
    #include <stdint.h>
    #define GEN_64BIT
    #include "#{root}/src/startup/mldr/stack.c"
    void elfcalls_make(struct elf_calls *calls) { memset(calls, 0, sizeof(*calls)); }
    int main(void) {
      size_t lengths[] = {0, 1, 31, 255, 4095};
      for (size_t n=0; n<5; ++n) for (size_t argc=0; argc<4; ++argc)
      for (size_t envc=0; envc<4; ++envc) {
        char path[4096]; memset(path, 'a', lengths[n]); path[lengths[n]]=0;
        char *av[]={"probe", "one", "two", NULL};
        char *ev[]={"A=1", "B=2", "C=3", NULL};
        unsigned char *memory=malloc(16384); assert(memory);
        memset(memory, 0x55, 16384);
        uintptr_t top=(uintptr_t)(memory+16384);
        struct load_results lr={.mh=0x1234, .stack_top=top,
          .argc=argc, .envc=envc, .argv=av, .envp=ev, .kernfd=7};
        setup_stack64(path,&lr);
        assert(lr.stack_top >= (uintptr_t)memory && lr.stack_top < top);
        uintptr_t *p=(uintptr_t *)lr.stack_top;
        assert(*p++==0x1234); assert(*p++==argc);
        for(size_t i=0;i<argc;++i) assert(*p++==(uintptr_t)av[i]);
        assert(*p++==0);
        for(size_t i=0;i<envc;++i) assert(*p++==(uintptr_t)ev[i]);
        assert(*p++==0);
        const char **apple=(const char **)p;
        uintptr_t lowest=top;
        for(size_t i=0;i<4;++i) {
          uintptr_t address=(uintptr_t)apple[i];
          assert(address>=(uintptr_t)(p+5) && address<top);
          assert(memchr(apple[i],0,top-address));
          if(address<lowest) lowest=address;
        }
        assert(apple[4]==NULL);
        assert(strncmp(apple[0],"executable_path=",16)==0);
        assert(strcmp(apple[0]+16,path)==0);
        assert(strcmp(apple[1],"kernfd=7")==0);
        assert(strncmp(apple[2],"elf_calls=",10)==0);
        assert(strtoull(apple[2]+10,NULL,16)==(uintptr_t)&_elfcalls);
        assert(strncmp(apple[3],"elf_calls_size=",15)==0);
        assert(strtoull(apple[3]+15,NULL,16)==sizeof(_elfcalls));
        assert((uintptr_t)(p+5)<=lowest);
        for(unsigned i=0;i<64;++i) assert(memory[i]==0x55);
        free(memory);
      }
      puts("PASS: 80 complete stack layouts, argv/envp, metadata and nonoverlap");
    }
  C
  File.write("#{dir}/probe.c",code)
  out,status=Open3.capture2e('clang','-fsanitize=address,undefined',"-I#{dir}","#{dir}/probe.c",'-o',"#{dir}/probe")
  abort out unless status.success?
  out,status=Open3.capture2e("#{dir}/probe")
  puts out
  abort 'stack layout test failed' unless status.success?
end
