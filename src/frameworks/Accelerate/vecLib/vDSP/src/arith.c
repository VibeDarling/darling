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

#include <stddef.h>
#include <vDSP/vDSP.h>

// Loop indices are signed so that "i * stride" stays signed: vDSP strides may be
// negative, and an unsigned index would turn that product into pointer overflow.

void vDSP_vadd(const float *__A, vDSP_Stride __IA, const float *__B, vDSP_Stride __IB, float *__C, vDSP_Stride __IC, vDSP_Length __N)
{
	if (__IA == 1 && __IB == 1 && __IC == 1)
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i] = __A[i] + __B[i];
	}
	else
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i * __IC] = __A[i * __IA] + __B[i * __IB];
	}
}

// Apple's argument order: the subtrahend B comes first, C = A - B.
void vDSP_vsub(const float *__B, vDSP_Stride __IB, const float *__A, vDSP_Stride __IA, float *__C, vDSP_Stride __IC, vDSP_Length __N)
{
	if (__IA == 1 && __IB == 1 && __IC == 1)
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i] = __A[i] - __B[i];
	}
	else
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i * __IC] = __A[i * __IA] - __B[i * __IB];
	}
}

void vDSP_vmul(const float *__A, vDSP_Stride __IA, const float *__B, vDSP_Stride __IB, float *__C, vDSP_Stride __IC, vDSP_Length __N)
{
	if (__IA == 1 && __IB == 1 && __IC == 1)
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i] = __A[i] * __B[i];
	}
	else
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i * __IC] = __A[i * __IA] * __B[i * __IB];
	}
}

void vDSP_vsmul(const float *__A, vDSP_Stride __IA, const float *__B, float *__C, vDSP_Stride __IC, vDSP_Length __N)
{
	const float b = *__B;

	if (__IA == 1 && __IC == 1)
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i] = __A[i] * b;
	}
	else
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i * __IC] = __A[i * __IA] * b;
	}
}

void vDSP_vsadd(const float *__A, vDSP_Stride __IA, const float *__B, float *__C, vDSP_Stride __IC, vDSP_Length __N)
{
	const float b = *__B;

	if (__IA == 1 && __IC == 1)
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i] = __A[i] + b;
	}
	else
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__C[i * __IC] = __A[i * __IA] + b;
	}
}

void vDSP_vsma(const float *__A, vDSP_Stride __IA, const float *__B, const float *__C, vDSP_Stride __IC, float *__D, vDSP_Stride __ID, vDSP_Length __N)
{
	const float b = *__B;

	if (__IA == 1 && __IC == 1 && __ID == 1)
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__D[i] = __A[i] * b + __C[i];
	}
	else
	{
		for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
			__D[i * __ID] = __A[i * __IA] * b + __C[i * __IC];
	}
}

void vDSP_svesq(const float *__A, vDSP_Stride __IA, float *__C, vDSP_Length __N)
{
	float sum = 0;

	for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
		sum += __A[i * __IA] * __A[i * __IA];
	*__C = sum;
}

void vDSP_vclip(const float *__A, vDSP_Stride __IA, const float *__B, const float *__C, float *__D, vDSP_Stride __ID, vDSP_Length __N)
{
	const float low = *__B, high = *__C;

	for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
	{
		float v = __A[i * __IA];
		if (v < low)
			v = low;
		else if (v > high)
			v = high;
		__D[i * __ID] = v;
	}
}

// Correlation, or convolution when F points at the filter's last tap with a negative stride.
void vDSP_conv(const float *__A, vDSP_Stride __IA, const float *__F, vDSP_Stride __IF, float *__C, vDSP_Stride __IC, vDSP_Length __N, vDSP_Length __P)
{
	for (ptrdiff_t n = 0; n < (ptrdiff_t) __N; n++)
	{
		const float *a = __A + n * __IA;
		float sum = 0;

		for (ptrdiff_t p = 0; p < (ptrdiff_t) (__P); p++)
			sum += a[p * __IA] * __F[p * __IF];
		__C[n * __IC] = sum;
	}
}

// IC counts floats, so 2 is a contiguous DSPComplex array.
void vDSP_ctoz(const DSPComplex *__C, vDSP_Stride __IC, const DSPSplitComplex *__Z, vDSP_Stride __IZ, vDSP_Length __N)
{
	const float *c = (const float *) __C;

	for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
	{
		__Z->realp[i * __IZ] = c[i * __IC];
		__Z->imagp[i * __IZ] = c[i * __IC + 1];
	}
}

void vDSP_ztoc(const DSPSplitComplex *__Z, vDSP_Stride __IZ, DSPComplex *__C, vDSP_Stride __IC, vDSP_Length __N)
{
	float *c = (float *) __C;

	for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
	{
		c[i * __IC] = __Z->realp[i * __IZ];
		c[i * __IC + 1] = __Z->imagp[i * __IZ];
	}
}

// C may alias A or B. Conjugate is 1 for A * B and -1 for conj(A) * B.
void vDSP_zvmul(const DSPSplitComplex *__A, vDSP_Stride __IA, const DSPSplitComplex *__B, vDSP_Stride __IB, const DSPSplitComplex *__C, vDSP_Stride __IC, vDSP_Length __N, int __Conjugate)
{
	const float sign = __Conjugate == -1 ? -1.0f : 1.0f;

	for (ptrdiff_t i = 0; i < (ptrdiff_t) __N; i++)
	{
		const float ar = __A->realp[i * __IA], ai = sign * __A->imagp[i * __IA];
		const float br = __B->realp[i * __IB], bi = __B->imagp[i * __IB];

		__C->realp[i * __IC] = ar * br - ai * bi;
		__C->imagp[i * __IC] = ar * bi + ai * br;
	}
}

// Two-pole two-zero filter. A and C hold N + 2 elements; C[0] and C[1] are the initial outputs.
void vDSP_deq22D(const double *__A, vDSP_Stride __IA, const double *__B, double *__C, vDSP_Stride __IC, vDSP_Length __N)
{
	const double b0 = __B[0], b1 = __B[1], b2 = __B[2], a1 = __B[3], a2 = __B[4];
	double x1 = __A[__IA], x2 = __A[0];
	double y1 = __C[__IC], y2 = __C[0];

	for (ptrdiff_t n = 2; n < (ptrdiff_t) (__N + 2); n++)
	{
		const double x = __A[n * __IA];
		const double y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;

		__C[n * __IC] = y;
		x2 = x1;
		x1 = x;
		y2 = y1;
		y1 = y;
	}
}

void vDSP_deq22(const float *__A, vDSP_Stride __IA, const float *__B, float *__C, vDSP_Stride __IC, vDSP_Length __N)
{
	const float b0 = __B[0], b1 = __B[1], b2 = __B[2], a1 = __B[3], a2 = __B[4];
	float x1 = __A[__IA], x2 = __A[0];
	float y1 = __C[__IC], y2 = __C[0];

	for (ptrdiff_t n = 2; n < (ptrdiff_t) (__N + 2); n++)
	{
		const float x = __A[n * __IA];
		const float y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;

		__C[n * __IC] = y;
		x2 = x1;
		x1 = x;
		y2 = y1;
		y1 = y;
	}
}
