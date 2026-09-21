/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

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

// Link-time stands-ins for the CryptoKit symbols that Swift apps bind. This satisfies the dynamic
// linker; it implements no cryptography. Every entry point aborts.
//
// Aborting is deliberate. A stub that returned a plausible-looking SHA-256 digest or HMAC would hand
// callers a silently wrong value on a security path, which is worse than the framework being absent.
//
// Apps compile against the resilient (library-evolution) CryptoKit, so they reach these types through
// metadata accessors and protocol dispatch thunks rather than direct calls. That gives a single
// chokepoint: every path into this framework needs SHA256's type metadata first, so the abort fires in
// $s9CryptoKit6SHA256VMa before the runtime walks any descriptor here.
//
// The data symbols below exist because the app's __DATA binds pointers to them. They are shaped like
// the descriptors swiftc emits for the same declarations, so nothing masquerades as code, but the
// runtime never gets far enough to read them.

.section __TEXT,__const
.p2align 2
l_module_name:
    .asciz "CryptoKit"
l_sha256_name:
    .asciz "SHA256"
l_hac_name:
    .asciz "HashedAuthenticationCode"

.p2align 2
l_module_descriptor:
    .long 0x00000000                    // Flags: Module
    .long 0                             // Parent
    .long (l_module_name - .)           // Name

// struct SHA256 -- ContextDescriptorKind::Struct (0x11) | IsUnique (0x40)
.p2align 2
.globl _$s9CryptoKit6SHA256VMn
_$s9CryptoKit6SHA256VMn:
    .long 0x00000051
    .long (l_module_descriptor - .)     // Parent
    .long (l_sha256_name - .)           // Name
    .long (_$s9CryptoKit6SHA256VMa - .) // Access function
    .long 0                             // FieldDescriptor
    .long 0                             // NumFields
    .long 0                             // FieldOffsetVectorOffset

// struct HashedAuthenticationCode<H> -- Struct | IsUnique | IsGeneric (0x80)
.p2align 2
.globl _$s9CryptoKit24HashedAuthenticationCodeVMn
_$s9CryptoKit24HashedAuthenticationCodeVMn:
    .long 0x000000d1
    .long (l_module_descriptor - .)     // Parent
    .long (l_hac_name - .)              // Name
    .long (l_unavailable - .)           // Access function
    .long 0                             // FieldDescriptor
    .long 0                             // NumFields
    .long 0                             // FieldOffsetVectorOffset
    .long 0                             // MetadataInstantiationCache
    .long 0                             // MetadataPattern
    // GenericContextDescriptorHeader
    .short 1                            // NumParams
    .short 0                            // NumRequirements
    .short 1                            // NumKeyArguments
    .short 0                            // NumExtraArguments
    // GenericParamDescriptor[1], padded to 4 bytes
    .byte 0x80                          // Kind: type, key argument
    .byte 0
    .byte 0
    .byte 0

// Conformance descriptors. Null relative pointers: reaching these means the SHA256VMa abort above did
// not fire, which cannot happen for any caller that reached this framework through the Swift runtime.
.p2align 2
.globl _$s9CryptoKit6SHA256VAA12HashFunctionAAMc
_$s9CryptoKit6SHA256VAA12HashFunctionAAMc:
    .long 0                             // Protocol
    .long 0                             // TypeRef
    .long 0                             // WitnessTablePattern
    .long 0                             // Flags

.p2align 2
.globl _$s9CryptoKit12SHA256DigestVSTAAMc
_$s9CryptoKit12SHA256DigestVSTAAMc:
    .long 0
    .long 0
    .long 0
    .long 0

.p2align 2
.globl _$s9CryptoKit24HashedAuthenticationCodeVyxGSTAAMc
_$s9CryptoKit24HashedAuthenticationCodeVyxGSTAAMc:
    .long 0
    .long 0
    .long 0
    .long 0

.text
.p2align 2

// Metadata accessors and the entry points reached through them. All abort.
.globl _$s9CryptoKit6SHA256VMa
.globl _$s9CryptoKit12SHA256DigestVMa
.globl _$s9CryptoKit12SymmetricKeyVMa
.globl _$s9CryptoKit12HashFunctionPxycfCTj
.globl _$s9CryptoKit12HashFunctionP6update13bufferPointerySW_tFTj
.globl _$s9CryptoKit12HashFunctionP8finalize6DigestQzyFTj
.globl _$s9CryptoKit12SymmetricKeyV4dataACx_tc10Foundation15ContiguousBytesRzlufC
.globl _$s9CryptoKit4HMACV18authenticationCode3for5usingAA020HashedAuthenticationE0VyxGqd___AA12SymmetricKeyVt10Foundation12DataProtocolRd__lFZ
_$s9CryptoKit6SHA256VMa:
_$s9CryptoKit12SHA256DigestVMa:
_$s9CryptoKit12SymmetricKeyVMa:
_$s9CryptoKit12HashFunctionPxycfCTj:
_$s9CryptoKit12HashFunctionP6update13bufferPointerySW_tFTj:
_$s9CryptoKit12HashFunctionP8finalize6DigestQzyFTj:
_$s9CryptoKit12SymmetricKeyV4dataACx_tc10Foundation15ContiguousBytesRzlufC:
_$s9CryptoKit4HMACV18authenticationCode3for5usingAA020HashedAuthenticationE0VyxGqd___AA12SymmetricKeyVt10Foundation12DataProtocolRd__lFZ:
l_unavailable:
#if defined(__x86_64__)
    jmp _darling_cryptokit_unavailable
#elif defined(__aarch64__)
    b _darling_cryptokit_unavailable
#else
    // Without a branch here the entry points would assemble to nothing and fall through.
    #error "CryptoKit stub: unsupported architecture (Swift on macOS is 64-bit only)"
#endif
