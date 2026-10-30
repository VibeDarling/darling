# Host test: Accelerate vImageScale_ARGB8888 parameter validation and resampling.
# usage: ruby tests/vimage-scale-argb8888.rb [REPO_ROOT]
# Built with ASan and UBSan to ensure memory safety and absence of undefined behaviour.
require 'tmpdir'
require 'open3'

root = ARGV.fetch(0, File.expand_path('..', __dir__))
accel_inc = "#{root}/src/frameworks/Accelerate/include"
accel_src = "#{root}/src/frameworks/Accelerate/src/Accelerate.c"

Dir.mktmpdir('vimage-scale-') do |dir|
  File.write("#{dir}/probe.c", <<~C)
    #include <assert.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <math.h>
    #include <limits.h>
    #include <Accelerate/Accelerate.h>

    static void test_parameter_validation(void) {
      vImage_Buffer src, dest;
      uint8_t sdata[64] = {0}, ddata[64] = {0};

      src.data = sdata; src.width = 4; src.height = 4; src.rowBytes = 16;
      dest.data = ddata; dest.width = 4; dest.height = 4; dest.rowBytes = 16;

      /* NULL buffers */
      assert(vImageScale_ARGB8888(NULL, &dest, NULL, kvImageNoFlags) == kvImageNullPointerErr);
      assert(vImageScale_ARGB8888(&src, NULL, NULL, kvImageNoFlags) == kvImageNullPointerErr);

      /* Zero dimensions */
      src.width = 0;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageInvalidParameter);
      src.width = 4; src.height = 0;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageInvalidParameter);
      src.height = 4; dest.width = 0;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageInvalidParameter);
      dest.width = 4; dest.height = 0;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageInvalidParameter);
      dest.height = 4;

      /* Row bytes smaller than width * 4 */
      src.width = (vImagePixelCount)INT_MAX + 1;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageInvalidParameter);
      src.width = 4;
      src.rowBytes = 15;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageInvalidRowBytes);
      src.rowBytes = 16; dest.rowBytes = 15;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageInvalidRowBytes);
      dest.rowBytes = 16;

      /* Unknown flags */
      assert(vImageScale_ARGB8888(&src, &dest, NULL, 0x80000000) == kvImageUnknownFlagsBit);
      assert(vImageScale_ARGB8888(&src, &dest, NULL, 0x00000400) == kvImageUnknownFlagsBit);

      /* kvImageGetTempBufferSize query returns 0 even with NULL data */
      src.data = NULL; dest.data = NULL;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageGetTempBufferSize) == 0);

      /* NULL data buffers during actual scale */
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageNullPointerErr);
      src.data = sdata;
      assert(vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags) == kvImageNullPointerErr);
    }

    static void test_scale_1to1_with_padding(void) {
      uint8_t sdata[4 * 32], ddata[4 * 32];
      memset(sdata, 0xAA, sizeof(sdata));
      memset(ddata, 0x00, sizeof(ddata));

      vImage_Buffer src = { .data = sdata, .width = 4, .height = 4, .rowBytes = 32 };
      vImage_Buffer dest = { .data = ddata, .width = 4, .height = 4, .rowBytes = 32 };

      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          sdata[y * 32 + x * 4 + 0] = 10;
          sdata[y * 32 + x * 4 + 1] = 20 + x;
          sdata[y * 32 + x * 4 + 2] = 30 + y;
          sdata[y * 32 + x * 4 + 3] = 40 + x + y;
        }
      }

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags);
      assert(err == kvImageNoError);

      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          assert(ddata[y * 32 + x * 4 + 0] == 10);
          assert(ddata[y * 32 + x * 4 + 1] == 20 + x);
          assert(ddata[y * 32 + x * 4 + 2] == 30 + y);
          assert(ddata[y * 32 + x * 4 + 3] == 40 + x + y);
        }
      }
    }

    static void test_1to1_leave_alpha_unchanged(void) {
      uint8_t sdata[2 * 8], ddata[2 * 8];
      for (int i = 0; i < 4; i++) {
        sdata[i * 4 + 0] = 200;
        sdata[i * 4 + 1] = 10;
        sdata[i * 4 + 2] = 20;
        sdata[i * 4 + 3] = 30;
      }
      for (int i = 0; i < 4; i++) {
        ddata[i * 4 + 0] = 0x77;
        ddata[i * 4 + 1] = 0;
        ddata[i * 4 + 2] = 0;
        ddata[i * 4 + 3] = 0;
      }

      vImage_Buffer src = { .data = sdata, .width = 2, .height = 2, .rowBytes = 8 };
      vImage_Buffer dest = { .data = ddata, .width = 2, .height = 2, .rowBytes = 8 };

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageLeaveAlphaUnchanged);
      assert(err == kvImageNoError);

      for (int i = 0; i < 4; i++) {
        assert(ddata[i * 4 + 0] == 0x77);
        assert(ddata[i * 4 + 1] == 10);
        assert(ddata[i * 4 + 2] == 20);
        assert(ddata[i * 4 + 3] == 30);
      }
    }

    static void test_rowbytes_sentinel_padding(void) {
      uint8_t sdata[2 * 64];
      uint8_t ddata[4 * 64];
      memset(sdata, 0xDE, sizeof(sdata));
      memset(ddata, 0x00, sizeof(ddata));

      for (int y = 0; y < 2; y++) {
        for (int x = 0; x < 2; x++) {
          sdata[y * 64 + x * 4 + 0] = 255;
          sdata[y * 64 + x * 4 + 1] = 50;
          sdata[y * 64 + x * 4 + 2] = 50;
          sdata[y * 64 + x * 4 + 3] = 50;
        }
      }

      vImage_Buffer src = { .data = sdata, .width = 2, .height = 2, .rowBytes = 64 };
      vImage_Buffer dest = { .data = ddata, .width = 4, .height = 4, .rowBytes = 64 };

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags);
      assert(err == kvImageNoError);

      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          assert(ddata[y * 64 + x * 4 + 0] == 255);
          assert(ddata[y * 64 + x * 4 + 1] == 50);
          assert(ddata[y * 64 + x * 4 + 2] == 50);
          assert(ddata[y * 64 + x * 4 + 3] == 50);
        }
        for (int p = 16; p < 64; p++) {
          assert(ddata[y * 64 + p] == 0x00);
        }
      }
    }

    static void test_leave_alpha_unchanged(void) {
      uint8_t sdata[4 * 16], ddata[4 * 16];
      memset(sdata, 0xFF, sizeof(sdata));
      memset(ddata, 0x33, sizeof(ddata));

      vImage_Buffer src = { .data = sdata, .width = 4, .height = 4, .rowBytes = 16 };
      vImage_Buffer dest = { .data = ddata, .width = 2, .height = 2, .rowBytes = 16 };

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageLeaveAlphaUnchanged);
      assert(err == kvImageNoError);

      for (int y = 0; y < 2; y++) {
        for (int x = 0; x < 2; x++) {
          /* Alpha channel must be preserved as 0x33 */
          assert(ddata[y * 16 + x * 4 + 0] == 0x33);
          /* RGB channels must be resampled from source (0xFF) */
          assert(ddata[y * 16 + x * 4 + 1] == 0xFF);
          assert(ddata[y * 16 + x * 4 + 2] == 0xFF);
          assert(ddata[y * 16 + x * 4 + 3] == 0xFF);
        }
      }
    }

    static void test_upscale_2x(void) {
      /* Source: 2x2 image */
      uint8_t sdata[2 * 8];
      /* (0,0): 255, 100, 0, 0 */
      sdata[0] = 255; sdata[1] = 100; sdata[2] = 0; sdata[3] = 0;
      /* (1,0): 255, 200, 0, 0 */
      sdata[4] = 255; sdata[5] = 200; sdata[6] = 0; sdata[7] = 0;
      /* (0,1): 255, 100, 0, 0 */
      sdata[8] = 255; sdata[9] = 100; sdata[10] = 0; sdata[11] = 0;
      /* (1,1): 255, 200, 0, 0 */
      sdata[12] = 255; sdata[13] = 200; sdata[14] = 0; sdata[15] = 0;

      /* Dest: 4x4 image */
      uint8_t ddata[4 * 16];
      memset(ddata, 0, sizeof(ddata));

      vImage_Buffer src = { .data = sdata, .width = 2, .height = 2, .rowBytes = 8 };
      vImage_Buffer dest = { .data = ddata, .width = 4, .height = 4, .rowBytes = 16 };

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageHighQualityResampling);
      assert(err == kvImageNoError);

      /* Leftmost column (x=0) should be 100 */
      assert(ddata[0 * 16 + 0 * 4 + 1] == 100);
      /* Rightmost column (x=3) should be 200 */
      assert(ddata[0 * 16 + 3 * 4 + 1] == 200);
      /* Middle columns should be interpolated: x=1 -> 125, x=2 -> 175 */
      assert(abs(ddata[0 * 16 + 1 * 4 + 1] - 125) <= 1);
      assert(abs(ddata[0 * 16 + 2 * 4 + 1] - 175) <= 1);
    }

    static void test_downscale_2x(void) {
      /* Source: 4x4 image */
      uint8_t sdata[4 * 32]; /* With 32-byte stride */
      memset(sdata, 0, sizeof(sdata));
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          sdata[y * 32 + x * 4 + 0] = 255;
          sdata[y * 32 + x * 4 + 1] = (uint8_t)(y * 40 + x * 10);
          sdata[y * 32 + x * 4 + 2] = 128;
          sdata[y * 32 + x * 4 + 3] = 64;
        }
      }

      /* Dest: 2x2 image */
      uint8_t ddata[2 * 16];
      memset(ddata, 0, sizeof(ddata));

      vImage_Buffer src = { .data = sdata, .width = 4, .height = 4, .rowBytes = 32 };
      vImage_Buffer dest = { .data = ddata, .width = 2, .height = 2, .rowBytes = 16 };

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags);
      assert(err == kvImageNoError);

      /* Check that all destination pixels have alpha=255, g=128, b=64 */
      for (int y = 0; y < 2; y++) {
        for (int x = 0; x < 2; x++) {
          assert(ddata[y * 16 + x * 4 + 0] == 255);
          assert(ddata[y * 16 + x * 4 + 2] == 128);
          assert(ddata[y * 16 + x * 4 + 3] == 64);
        }
      }
    }

    static void test_1x1_upscale(void) {
      /* 1x1 image scaled up to 3x5 */
      uint8_t sdata[4] = { 200, 10, 20, 30 };
      uint8_t ddata[5 * 3 * 4];
      memset(ddata, 0, sizeof(ddata));

      vImage_Buffer src = { .data = sdata, .width = 1, .height = 1, .rowBytes = 4 };
      vImage_Buffer dest = { .data = ddata, .width = 3, .height = 5, .rowBytes = 12 };

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageNoFlags);
      assert(err == kvImageNoError);

      for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 3; x++) {
          assert(ddata[y * 12 + x * 4 + 0] == 200);
          assert(ddata[y * 12 + x * 4 + 1] == 10);
          assert(ddata[y * 12 + x * 4 + 2] == 20);
          assert(ddata[y * 12 + x * 4 + 3] == 30);
        }
      }
    }

    static void test_asymmetric_dimensions(void) {
      /* Scale 3x2 to 7x5 with irregular strides */
      uint8_t sdata[2 * 20];
      uint8_t ddata[5 * 40];
      memset(sdata, 0x55, sizeof(sdata));
      memset(ddata, 0, sizeof(ddata));

      vImage_Buffer src = { .data = sdata, .width = 3, .height = 2, .rowBytes = 20 };
      vImage_Buffer dest = { .data = ddata, .width = 7, .height = 5, .rowBytes = 40 };

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageEdgeExtend | kvImageDoNotTile);
      assert(err == kvImageNoError);

      for (int y = 0; y < 5; y++) {
        for (int x = 0; x < 7; x++) {
          assert(ddata[y * 40 + x * 4 + 0] == 0x55);
          assert(ddata[y * 40 + x * 4 + 1] == 0x55);
          assert(ddata[y * 40 + x * 4 + 2] == 0x55);
          assert(ddata[y * 40 + x * 4 + 3] == 0x55);
        }
      }
    }

    static void test_1to1_inplace(void) {
      uint8_t buffer[4 * 16];
      for (int i = 0; i < 16; i++) {
        buffer[i * 4 + 0] = 255;
        buffer[i * 4 + 1] = i * 10;
        buffer[i * 4 + 2] = 50;
        buffer[i * 4 + 3] = 100;
      }

      vImage_Buffer buf = { .data = buffer, .width = 4, .height = 4, .rowBytes = 16 };
      vImage_Error err = vImageScale_ARGB8888(&buf, &buf, NULL, kvImageNoFlags);
      assert(err == kvImageNoError);

      for (int i = 0; i < 16; i++) {
        assert(buffer[i * 4 + 0] == 255);
        assert(buffer[i * 4 + 1] == (uint8_t)(i * 10));
        assert(buffer[i * 4 + 2] == 50);
        assert(buffer[i * 4 + 3] == 100);
      }
    }

    static void test_dynamic_malloc_large_width(void) {
      int src_w = 4, src_h = 4;
      int dst_w = 512, dst_h = 4;

      uint8_t *sdata = malloc(src_h * src_w * 4);
      uint8_t *ddata = malloc(dst_h * dst_w * 4);
      assert(sdata && ddata);
      memset(sdata, 0x44, src_h * src_w * 4);
      memset(ddata, 0x00, dst_h * dst_w * 4);

      vImage_Buffer src = { .data = sdata, .width = src_w, .height = src_h, .rowBytes = src_w * 4 };
      vImage_Buffer dest = { .data = ddata, .width = dst_w, .height = dst_h, .rowBytes = dst_w * 4 };

      vImage_Error err = vImageScale_ARGB8888(&src, &dest, NULL, kvImageHighQualityResampling);
      assert(err == kvImageNoError);

      for (int y = 0; y < dst_h; y++) {
        for (int x = 0; x < dst_w; x++) {
          assert(ddata[y * (dst_w * 4) + x * 4 + 0] == 0x44);
          assert(ddata[y * (dst_w * 4) + x * 4 + 1] == 0x44);
          assert(ddata[y * (dst_w * 4) + x * 4 + 2] == 0x44);
          assert(ddata[y * (dst_w * 4) + x * 4 + 3] == 0x44);
        }
      }

      free(sdata);
      free(ddata);
    }

    int main(void) {
      test_parameter_validation();
      test_scale_1to1_with_padding();
      test_1to1_leave_alpha_unchanged();
      test_1to1_inplace();
      test_rowbytes_sentinel_padding();
      test_leave_alpha_unchanged();
      test_upscale_2x();
      test_downscale_2x();
      test_1x1_upscale();
      test_asymmetric_dimensions();
      test_dynamic_malloc_large_width();
      puts("PASS: vImageScale_ARGB8888 validates parameters and resamples accurately");
      return 0;
    }
  C

  out, st = Open3.capture2e(
    'clang', '-O2',
    '-fsanitize=address,undefined', '-fno-sanitize-recover=undefined',
    '-w',
    "-I#{accel_inc}",
    "#{dir}/probe.c",
    accel_src,
    '-lm',
    '-o', "#{dir}/probe"
  )
  abort out unless st.success?

  out, st = Open3.capture2e("#{dir}/probe", rlimit_core: 0)
  puts out
  abort "vImageScale_ARGB8888 test failed" unless st.success?
end
