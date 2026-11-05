# Host test: vDSP_create_fftsetup rejects a twiddle table that overflows size_t.
# usage: ruby tests/vdsp-fft-setup-size.rb [REPO_ROOT]
# A 32-bit size_t is simulated on the 64-bit host by building fft.c with SIZE_MAX
# forced to 0xFFFFFFFF, so no 4 GiB allocation is needed. Without the guard,
# Log2n 30 asks malloc for 2^32 + header bytes, which wraps to a tiny block on 32-bit.
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
vdsp = "#{root}/src/frameworks/Accelerate/vecLib/vDSP"
Dir.mktmpdir('vdsp-fftsize-') do |dir|
  File.write("#{dir}/size32.h", "#include <stdint.h>\n#undef SIZE_MAX\n#define SIZE_MAX 0xFFFFFFFFu\n")
  File.write("#{dir}/probe.c", <<~C)
    #include <stdio.h>
    #include <vDSP/vDSP.h>
    #include <stdlib.h>
    #define assert(c) do { if (!(c)) { puts("assertion failed: " #c); fflush(stdout); exit(1); } } while (0)
    int main(void) {
      assert(vDSP_create_fftsetup(31, kFFTRadix2) == NULL);   /* above the Log2n limit */
      assert(vDSP_create_fftsetup(30, kFFTRadix2) == NULL);   /* 2^32 bytes: overflow guard */
      FFTSetup s = vDSP_create_fftsetup(10, kFFTRadix2);      /* ordinary sizes still work */
      assert(s);
      vDSP_destroy_fftsetup(s);
      puts("PASS: oversized FFT setups are rejected");
      return 0;
    }
  C
  out, st = Open3.capture2e('clang', '-O2', '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined', '-w',
    '-include', "#{dir}/size32.h", "-I#{vdsp}/include", "#{dir}/probe.c", "#{vdsp}/src/fft.c", '-lm', '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e("timeout", "60", "#{dir}/probe", rlimit_core: 0)
  puts out
  abort 'vDSP fft setup size guard missing' unless st.success?
end
