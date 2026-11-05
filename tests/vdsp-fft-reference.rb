# Host test: vDSP_fft_zrip against a brute-force DFT of the real input.
# usage: ruby tests/vdsp-fft-reference.rb [REPO_ROOT]
# Forward returns 2x the DFT, X[0] in realp[0] and X[N/2] in imagp[0]; inverse is
# unscaled so a round trip multiplies by 2N. fft.c is built unmodified (ASan, UBSan).
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
vdsp = "#{root}/src/frameworks/Accelerate/vecLib/vDSP"
Dir.mktmpdir('vdsp-fft-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #include <math.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <vDSP/vDSP.h>
    #define assert(c) do { if (!(c)) { puts("assertion failed: " #c); fflush(stdout); exit(1); } } while (0)
    static void check(unsigned log2n, int stride, unsigned seed) {
      size_t n = (size_t)1 << log2n, h = n / 2;
      double *x = malloc(n * sizeof(double));
      float *re = calloc(h * (size_t)stride, sizeof(float)), *im = calloc(h * (size_t)stride, sizeof(float));
      srand(seed);
      for (size_t i = 0; i < n; i++) x[i] = (double)(rand() % 2001 - 1000) / 100.0;
      for (size_t i = 0; i < h; i++) { re[i * stride] = (float)x[2 * i]; im[i * stride] = (float)x[2 * i + 1]; }
      FFTSetup setup = vDSP_create_fftsetup(log2n, kFFTRadix2);
      assert(setup);
      DSPSplitComplex z = {re, im};
      vDSP_fft_zrip(setup, &z, stride, log2n, kFFTDirection_Forward);
      for (size_t k = 0; k <= h; k++) {
        double sr = 0, si = 0;
        for (size_t t = 0; t < n; t++) { sr += x[t] * cos(2 * M_PI * k * t / n); si -= x[t] * sin(2 * M_PI * k * t / n); }
        double gr, gi;
        if (k == 0) { gr = re[0]; gi = 0; }
        else if (k == h) { gr = im[0]; gi = 0; }
        else { gr = re[k * stride]; gi = im[k * stride]; }
        assert(fabs(gr - 2 * sr) < 1e-3 && fabs(gi - 2 * si) < 1e-3);
      }
      vDSP_fft_zrip(setup, &z, stride, log2n, kFFTDirection_Inverse);
      for (size_t i = 0; i < h; i++)
        assert(fabs(re[i * stride] - 2.0 * n * x[2 * i]) < 0.05 * n && fabs(im[i * stride] - 2.0 * n * x[2 * i + 1]) < 0.05 * n);
      vDSP_destroy_fftsetup(setup);
      free(x); free(re); free(im);
    }
    int main(void) {
      check(1, 1, 1); check(2, 1, 2); check(3, 1, 3); check(6, 1, 4); check(10, 2, 5);
      assert(vDSP_create_fftsetup(4, kFFTRadix3) == NULL && vDSP_create_fftsetup(4, kFFTRadix5) == NULL);
      puts("PASS: vDSP_fft_zrip matches a brute-force DFT");
      return 0;
    }
  C
  out, st = Open3.capture2e('clang', '-O2', '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined', '-w',
    "-I#{vdsp}/include", "#{dir}/probe.c", "#{vdsp}/src/fft.c", '-lm', '-o', "#{dir}/probe")
  abort out unless st.success?
  out, st = Open3.capture2e("timeout", "60", "#{dir}/probe", rlimit_core: 0)
  puts out
  abort 'vDSP fft reference mismatch' unless st.success?
end
