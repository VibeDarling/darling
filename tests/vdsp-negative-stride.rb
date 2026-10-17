# Host test: vDSP kernels accept negative strides without pointer overflow.
# usage: ruby tests/vdsp-negative-stride.rb [REPO_ROOT]
# arith.c is built unmodified with UBSan (pointer-overflow) and ASan. An
# unsigned loop index times a negative stride wraps the offset; the values come
# out right but the pointer arithmetic is undefined, which UBSan reports.
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
vdsp = "#{root}/src/frameworks/Accelerate/vecLib/vDSP"
Dir.mktmpdir('vdsp-stride-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #include <assert.h>
    #include <math.h>
    #include <stdio.h>
    #include <vDSP/vDSP.h>
    int main(void) {
      float a[4] = {1, 2, 3, 4}, b[4] = {10, 20, 30, 40}, c[4];
      /* C[i] = A[3 - i] + B[i]: negative stride on A starts at the last element */
      vDSP_vadd(a + 3, -1, b, 1, c, 1, 4);
      assert(c[0] == 14 && c[1] == 23 && c[2] == 32 && c[3] == 41);
      vDSP_vsub(b, 1, a + 3, -1, c, 1, 4);              /* C = A - B, A reversed */
      assert(c[0] == -6 && c[1] == -17 && c[2] == -28 && c[3] == -39);
      vDSP_vmul(a, 1, b + 3, -1, c + 3, -1, 4);         /* output reversed too */
      assert(c[3] == 40 && c[2] == 60 && c[1] == 60 && c[0] == 40);
      float s = 2, d[4];
      vDSP_vsma(a + 3, -1, &s, b, 1, d, 1, 4);          /* D = A_rev * s + C */
      assert(d[0] == 18 && d[1] == 26 && d[2] == 34 && d[3] == 42);
      float e = 0; vDSP_svesq(a + 3, -1, &e, 4);
      assert(e == 30);
      /* convolution: F points at the last tap with IF = -1 */
      float x[6] = {1, 2, 3, 4, 5, 6}, f[3] = {1, 0, -1}, y[4];
      vDSP_conv(x, 1, f + 2, -1, y, 1, 4, 3);
      assert(y[0] == 2 && y[1] == 2 && y[2] == 2 && y[3] == 2);
      puts("PASS: negative strides are well-defined");
      return 0;
    }
  C
  out, st = Open3.capture2e('clang', '-O2', '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined', '-w',
    "-I#{vdsp}/include", "#{dir}/probe.c", "#{vdsp}/src/arith.c", '-lm', '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e("#{dir}/probe", rlimit_core: 0)
  puts out
  abort 'vDSP negative stride regression' unless st.success?
end
