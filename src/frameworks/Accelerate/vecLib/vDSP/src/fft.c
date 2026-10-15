/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <vDSP/vDSP.h>
#include <stdlib.h>
#include <math.h>

// Setups are shared between threads, so only read-only twiddles live here.
struct OpaqueFFTSetup
{
	vDSP_Length log2n;
	float *cosine;
	float *sine;
};

FFTSetup vDSP_create_fftsetup(vDSP_Length __Log2n, FFTRadix __Radix)
{
	if (__Radix != kFFTRadix2 || __Log2n > 30)
		return NULL;

	const size_t n = (size_t) 1 << __Log2n;
	const size_t half = n > 1 ? n / 2 : 1;
	struct OpaqueFFTSetup *setup = malloc(sizeof(*setup) + 2 * half * sizeof(float));

	if (!setup)
		return NULL;
	setup->log2n = __Log2n;
	setup->cosine = (float *) (setup + 1);
	setup->sine = setup->cosine + half;
	for (size_t j = 0; j < half; j++)
	{
		const double angle = 2.0 * M_PI * (double) j / (double) n;
		setup->cosine[j] = cos(angle);
		setup->sine[j] = sin(angle);
	}
	return setup;
}

void vDSP_destroy_fftsetup(FFTSetup __setup)
{
	free(__setup);
}

// In-place radix-2 complex FFT of 2^log2m points, e^-i for forward and e^+i for inverse, unscaled.
static void complex_fft(const struct OpaqueFFTSetup *setup, float *re, float *im, vDSP_Stride stride, vDSP_Length log2m, int inverse)
{
	const size_t m = (size_t) 1 << log2m;
	const size_t full = (size_t) 1 << setup->log2n;

	for (size_t i = 1, j = 0; i < m; i++)
	{
		size_t bit = m >> 1;
		for (; j & bit; bit >>= 1)
			j ^= bit;
		j ^= bit;
		if (i < j)
		{
			float t = re[i * stride];
			re[i * stride] = re[j * stride];
			re[j * stride] = t;
			t = im[i * stride];
			im[i * stride] = im[j * stride];
			im[j * stride] = t;
		}
	}

	for (size_t len = 2; len <= m; len <<= 1)
	{
		const size_t half = len >> 1;
		const size_t step = full / len;

		for (size_t base = 0; base < m; base += len)
		{
			for (size_t k = 0; k < half; k++)
			{
				const float wr = setup->cosine[k * step];
				const float wi = inverse ? setup->sine[k * step] : -setup->sine[k * step];
				const size_t a = (base + k) * stride, b = (base + k + half) * stride;
				const float tr = re[b] * wr - im[b] * wi;
				const float ti = re[b] * wi + im[b] * wr;

				re[b] = re[a] - tr;
				im[b] = im[a] - ti;
				re[a] += tr;
				im[a] += ti;
			}
		}
	}
}

// Real FFT on N = 2^Log2N points packed as N/2 complex values (even samples real, odd imaginary).
// Forward returns twice the DFT with X[0] in realp[0] and X[N/2] in imagp[0]; inverse is unscaled,
// so a round trip multiplies by 2N, as on macOS.
void vDSP_fft_zrip(FFTSetup __Setup, const DSPSplitComplex *__C, vDSP_Stride __IC, vDSP_Length __Log2N, FFTDirection __Direction)
{
	if (!__Setup || __Log2N == 0 || __Log2N > __Setup->log2n)
		return;

	float *re = __C->realp, *im = __C->imagp;
	const vDSP_Stride s = __IC;
	const size_t m = (size_t) 1 << (__Log2N - 1);
	const size_t step = ((size_t) 1 << __Setup->log2n) >> __Log2N;

	if (__Direction != kFFTDirection_Inverse)
	{
		complex_fft(__Setup, re, im, s, __Log2N - 1, 0);

		const float z0r = re[0], z0i = im[0];
		re[0] = 2 * (z0r + z0i);
		im[0] = 2 * (z0r - z0i);

		for (size_t k = 1; k <= m / 2; k++)
		{
			const size_t j = m - k;
			const float c = __Setup->cosine[k * step], sn = __Setup->sine[k * step];
			const float ar = re[k * s], ai = im[k * s], br = re[j * s], bi = im[j * s];
			const float sr = ar + br, si = ai - bi, dr = ar - br, di = ai + bi;

			re[k * s] = sr + (c * di - sn * dr);
			im[k * s] = si - (c * dr + sn * di);
			re[j * s] = sr - (c * di - sn * dr);
			im[j * s] = -si - (c * dr + sn * di);
		}
	}
	else
	{
		const float p0r = re[0], p0i = im[0];
		re[0] = p0r + p0i;
		im[0] = p0r - p0i;

		for (size_t k = 1; k <= m / 2; k++)
		{
			const size_t j = m - k;
			const float c = __Setup->cosine[k * step], sn = __Setup->sine[k * step];
			const float ar = re[k * s], ai = im[k * s], br = re[j * s], bi = im[j * s];
			const float sr = ar + br, si = ai - bi, dr = ar - br, di = ai + bi;

			re[k * s] = sr - (c * di + sn * dr);
			im[k * s] = si + (c * dr - sn * di);
			re[j * s] = sr + (c * di + sn * dr);
			im[j * s] = -si + (c * dr - sn * di);
		}

		complex_fft(__Setup, re, im, s, __Log2N - 1, 1);
	}
}
