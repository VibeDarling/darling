# Host test: CVTransferFunction string/code point mapping includes sRGB (code point 13).
# usage: ruby tests/corevideo-transfer-function-srgb.rb [REPO_ROOT]
# The two mapping functions are cut out of CVPixelBuffer.c and built with ASan/UBSan
# against a minimal CFString stand-in, so the file's own source is what is tested.
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
src = File.read("#{root}/src/frameworks/CoreVideo/src/CVPixelBuffer.c")
fns = src[/^CFStringRef CVTransferFunctionGetStringForIntegerCodePoint.*?^\}\n.*?^int32_t CVTransferFunctionGetIntegerCodePointForString.*?^\}\n/m] or abort 'transfer function mappers not found'
names = %w[ITU_R_709_2 SMPTE_240M_1995 Linear ITU_R_2020 SMPTE_ST_2084_PQ SMPTE_ST_428_1 ITU_R_2100_HLG sRGB]
Dir.mktmpdir('cv-tf-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #include <stdint.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    typedef const char *CFStringRef;
    #define CFEqual(a, b) (strcmp((a), (b)) == 0)
    #{names.map { |n| "static CFStringRef kCVImageBufferTransferFunction_#{n} = \"#{n}\";" }.join("\n")}
    #{fns}
    static void check(int ok, const char *what) { if (!ok) { printf("FAIL: %s\\n", what); fflush(stdout); exit(1); } }
    int main(void) {
      check(CVTransferFunctionGetStringForIntegerCodePoint(13) == kCVImageBufferTransferFunction_sRGB, "13 -> sRGB");
      check(CVTransferFunctionGetIntegerCodePointForString(kCVImageBufferTransferFunction_sRGB) == 13, "sRGB -> 13");
      check(CVTransferFunctionGetIntegerCodePointForString("sRGB") == 13, "sRGB by value");
      check(CVTransferFunctionGetStringForIntegerCodePoint(1) == kCVImageBufferTransferFunction_ITU_R_709_2, "1 unchanged");
      check(CVTransferFunctionGetStringForIntegerCodePoint(18) == kCVImageBufferTransferFunction_ITU_R_2100_HLG, "18 unchanged");
      check(CVTransferFunctionGetStringForIntegerCodePoint(12) == NULL, "12 still unmapped");
      check(CVTransferFunctionGetIntegerCodePointForString("other") == 2, "unknown string -> 2");
      puts("PASS: CV transfer function sRGB mapping");
      return 0;
    }
  C
  out, st = Open3.capture2e('clang', '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined', '-Wall', '-Wno-unused-variable',
    "#{dir}/probe.c", '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e({ 'ASAN_OPTIONS' => 'disable_coredump=1' }, 'timeout', '60', "#{dir}/probe", rlimit_core: 0)
  puts out
  abort 'CV transfer function sRGB mapping regression' unless st.success?
end
