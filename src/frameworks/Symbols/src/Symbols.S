// Stand-ins for the parts of Apple's Symbols framework that apps bind to.
//
// Symbols (macOS 14+) is a Swift-native framework, so every symbol here is Swift-mangled and every
// type is resilient: apps see the effect types as address-only. Values come back through the
// indirect-result register (arm64 x8, x86_64 rax), `self` arrives by address (x20, r13) and is
// ignored, and the metadata accessors report MetadataState::Complete. Each type is given
// Builtin.NativeObject's value witnesses and every value produced holds the runtime's immortal
// empty-dictionary singleton, so copying or destroying one is a no-op. Same technique as
// src/external/swift/libswiftUniformTypeIdentifiers.S.
//
// This is a stub, not an implementation. It exists so dyld can bind the Symbols imports of apps
// that link the framework; the effect values it hands out carry no configuration and would not
// animate anything. Nothing in Darling renders SF Symbols effects today, so nothing consumes them.
//
// The exported set is exactly what the scanned macOS app corpus imports from Symbols.framework:
// Freeform (13 symbols), Journal (9), VoiceMemos (7) and the third-party AppZapper 3000 (5).
// When a new app needs more, add the symbol here rather than widening the surface speculatively.

// Every code block below is bracketed by the same two-architecture guard, so on any other
// architecture each would assemble to nothing and every label would silently alias the next
// function. Fail at build time instead.
#if !defined(__x86_64__) && !defined(__aarch64__)
#error "the Symbols stub supports x86_64 and arm64 only"
#endif

.data

module_name:
    .asciz "Symbols"
bounce_name:
    .asciz "BounceSymbolEffect"
replace_name:
    .asciz "ReplaceSymbolEffect"
automatic_name:
    .asciz "AutomaticSymbolEffect"
variable_color_name:
    .asciz "VariableColorSymbolEffect"
options_name:
    .asciz "SymbolEffectOptions"

.p2align 2
module_descriptor:
    .long 0x00000000   // Flags: Module
    .long 0   // Parent
    .long (module_name - .)   // Name (relative pointer)

.p2align 3
bounce_descriptor:
    .long 0x00000051   // Flags: Struct | IsUnique (not generic)
    .long (module_descriptor - .)   // Parent (relative pointer)
    .long (bounce_name - .)   // Name (relative pointer)
    .long (_$s7Symbols18BounceSymbolEffectVMa - .)   // Access function
    .long 0   // FieldDescriptor
    .long 0   // NumFields
    .long 0   // FieldOffsetVectorOffset

.p2align 3
replace_descriptor:
    .long 0x00000051   // Flags: Struct | IsUnique (not generic)
    .long (module_descriptor - .)   // Parent (relative pointer)
    .long (replace_name - .)   // Name (relative pointer)
    .long (_$s7Symbols19ReplaceSymbolEffectVMa - .)   // Access function
    .long 0   // FieldDescriptor
    .long 0   // NumFields
    .long 0   // FieldOffsetVectorOffset

.p2align 3
automatic_descriptor:
    .long 0x00000051   // Flags: Struct | IsUnique (not generic)
    .long (module_descriptor - .)   // Parent (relative pointer)
    .long (automatic_name - .)   // Name (relative pointer)
    .long (_$s7Symbols21AutomaticSymbolEffectVMa - .)   // Access function
    .long 0   // FieldDescriptor
    .long 0   // NumFields
    .long 0   // FieldOffsetVectorOffset

.p2align 3
variable_color_descriptor:
    .long 0x00000051   // Flags: Struct | IsUnique (not generic)
    .long (module_descriptor - .)   // Parent (relative pointer)
    .long (variable_color_name - .)   // Name (relative pointer)
    .long (_$s7Symbols25VariableColorSymbolEffectVMa - .)   // Access function
    .long 0   // FieldDescriptor
    .long 0   // NumFields
    .long 0   // FieldOffsetVectorOffset

.p2align 3
options_descriptor:
    .long 0x00000051   // Flags: Struct | IsUnique (not generic)
    .long (module_descriptor - .)   // Parent (relative pointer)
    .long (options_name - .)   // Name (relative pointer)
    .long (_$s7Symbols19SymbolEffectOptionsVMa - .)   // Access function
    .long 0   // FieldDescriptor
    .long 0   // NumFields
    .long 0   // FieldOffsetVectorOffset

// Conformances to SymbolEffect, a protocol that lives in this framework and is not stubbed, so there
// is no witness table to point at and every field is left zero.
//
// What makes that safe is that these records are never registered: nothing here emits a
// __TEXT,__swift5_proto section, so the Swift runtime never scans them. Do not move them into
// __swift5_proto without filling in a real witness table. Zero is not uniformly "absent" either:
// protocol and witnessTable are nullable relative pointers and do read back as null, but with
// flags == 0 typeRef is a non-nullable DirectTypeDescriptor whose zero offset resolves to the field
// itself, inside this zeroed record.
//
// A client that reaches one of these anyway, by handing it to swift_getWitnessTable the way IRGen
// does for a conformance to a resilient protocol, gets a null witness table and faults on the first
// witness call. That path needs the renderer, which Darling does not have.
.p2align 3
.globl _$s7Symbols18BounceSymbolEffectVAA0cD0AAMc
_$s7Symbols18BounceSymbolEffectVAA0cD0AAMc:
    .long 0   // protocol
    .long 0   // typeRef
    .long 0   // witnessTable
    .long 0   // flags

.p2align 3
.globl _$s7Symbols19ReplaceSymbolEffectVAA0cD0AAMc
_$s7Symbols19ReplaceSymbolEffectVAA0cD0AAMc:
    .long 0   // protocol
    .long 0   // typeRef
    .long 0   // witnessTable
    .long 0   // flags

.p2align 3
.globl _$s7Symbols21AutomaticSymbolEffectVAA0cD0AAMc
_$s7Symbols21AutomaticSymbolEffectVAA0cD0AAMc:
    .long 0   // protocol
    .long 0   // typeRef
    .long 0   // witnessTable
    .long 0   // flags

.p2align 3
.globl _$s7Symbols25VariableColorSymbolEffectVAA0dE0AAMc
_$s7Symbols25VariableColorSymbolEffectVAA0dE0AAMc:
    .long 0   // protocol
    .long 0   // typeRef
    .long 0   // witnessTable
    .long 0   // flags

// The type metadata labels name the kind word; the value witness table pointer sits just before it.
.p2align 3
    .quad _$sBOWV
bounce_metadata:
    .quad 0x200   // Struct kind
    .quad bounce_descriptor

.p2align 3
    .quad _$sBOWV
replace_metadata:
    .quad 0x200   // Struct kind
    .quad replace_descriptor

.p2align 3
    .quad _$sBOWV
automatic_metadata:
    .quad 0x200   // Struct kind
    .quad automatic_descriptor

.p2align 3
    .quad _$sBOWV
variable_color_metadata:
    .quad 0x200   // Struct kind
    .quad variable_color_descriptor

.p2align 3
    .quad _$sBOWV
options_metadata:
    .quad 0x200   // Struct kind
    .quad options_descriptor

.text
.p2align 2

// Every effect value is the same placeholder, so the initializers, the instance properties that
// return a configured copy of Self and the static SymbolEffectOptions properties all share one
// body. `self` and the metatype are ignored.
//
//   BounceSymbolEffect.init(), .down, .wholeSymbol
//   ReplaceSymbolEffect.init(), .downUp
//   AutomaticSymbolEffect.init()
//   VariableColorSymbolEffect.init(), .cumulative, .dimInactiveLayers, .iterative
//   SymbolEffectOptions.default, .nonRepeating
.globl _$s7Symbols18BounceSymbolEffectVACycfC
.globl _$s7Symbols18BounceSymbolEffectV4downACvg
.globl _$s7Symbols18BounceSymbolEffectV05wholeC0ACvg
.globl _$s7Symbols19ReplaceSymbolEffectVACycfC
.globl _$s7Symbols19ReplaceSymbolEffectV6downUpACvg
.globl _$s7Symbols21AutomaticSymbolEffectVACycfC
.globl _$s7Symbols25VariableColorSymbolEffectVACycfC
.globl _$s7Symbols25VariableColorSymbolEffectV10cumulativeACvg
.globl _$s7Symbols25VariableColorSymbolEffectV17dimInactiveLayersACvg
.globl _$s7Symbols25VariableColorSymbolEffectV9iterativeACvg
.globl _$s7Symbols19SymbolEffectOptionsV7defaultACvgZ
.globl _$s7Symbols19SymbolEffectOptionsV12nonRepeatingACvgZ
_$s7Symbols18BounceSymbolEffectVACycfC:
_$s7Symbols18BounceSymbolEffectV4downACvg:
_$s7Symbols18BounceSymbolEffectV05wholeC0ACvg:
_$s7Symbols19ReplaceSymbolEffectVACycfC:
_$s7Symbols19ReplaceSymbolEffectV6downUpACvg:
_$s7Symbols21AutomaticSymbolEffectVACycfC:
_$s7Symbols25VariableColorSymbolEffectVACycfC:
_$s7Symbols25VariableColorSymbolEffectV10cumulativeACvg:
_$s7Symbols25VariableColorSymbolEffectV17dimInactiveLayersACvg:
_$s7Symbols25VariableColorSymbolEffectV9iterativeACvg:
_$s7Symbols19SymbolEffectOptionsV7defaultACvgZ:
_$s7Symbols19SymbolEffectOptionsV12nonRepeatingACvgZ:
#if defined(__x86_64__)
    movq __swiftEmptyDictionarySingleton@GOTPCREL(%rip), %rcx
    movq %rcx, (%rax)
    ret
#elif defined(__aarch64__)
    adrp x9, __swiftEmptyDictionarySingleton@GOTPAGE
    ldr x9, [x9, __swiftEmptyDictionarySingleton@GOTPAGEOFF]
    str x9, [x8]
    ret
#endif

// SymbolEffect.configuration returns SymbolEffectConfiguration, the one type in the demanded surface
// that is not stubbed here: its metadata and value witnesses are Apple's, so there is no placeholder
// we could write into the caller's buffer that its value witnesses would survive. Apps bind the
// thunk, but reaching it needs that metadata, which this framework does not vend. Trap instead of
// corrupting the result buffer, so a call that does somehow get here is obvious.
.globl _$s7Symbols12SymbolEffectP13configurationAA0bC13ConfigurationVvgTj
_$s7Symbols12SymbolEffectP13configurationAA0bC13ConfigurationVvgTj:
#if defined(__x86_64__)
    ud2
#elif defined(__aarch64__)
    brk #0x1
#endif
.p2align 2

.globl _$s7Symbols18BounceSymbolEffectVMa
_$s7Symbols18BounceSymbolEffectVMa:
#if defined(__x86_64__)
    lea bounce_metadata(%rip), %rax
    xor %edx, %edx   // MetadataState::Complete
    ret
#elif defined(__aarch64__)
    adrp x0, bounce_metadata@PAGE
    add x0, x0, bounce_metadata@PAGEOFF
    mov x1, #0   // MetadataState::Complete
    ret
#endif

.globl _$s7Symbols19ReplaceSymbolEffectVMa
_$s7Symbols19ReplaceSymbolEffectVMa:
#if defined(__x86_64__)
    lea replace_metadata(%rip), %rax
    xor %edx, %edx   // MetadataState::Complete
    ret
#elif defined(__aarch64__)
    adrp x0, replace_metadata@PAGE
    add x0, x0, replace_metadata@PAGEOFF
    mov x1, #0   // MetadataState::Complete
    ret
#endif

.globl _$s7Symbols21AutomaticSymbolEffectVMa
_$s7Symbols21AutomaticSymbolEffectVMa:
#if defined(__x86_64__)
    lea automatic_metadata(%rip), %rax
    xor %edx, %edx   // MetadataState::Complete
    ret
#elif defined(__aarch64__)
    adrp x0, automatic_metadata@PAGE
    add x0, x0, automatic_metadata@PAGEOFF
    mov x1, #0   // MetadataState::Complete
    ret
#endif

.globl _$s7Symbols25VariableColorSymbolEffectVMa
_$s7Symbols25VariableColorSymbolEffectVMa:
#if defined(__x86_64__)
    lea variable_color_metadata(%rip), %rax
    xor %edx, %edx   // MetadataState::Complete
    ret
#elif defined(__aarch64__)
    adrp x0, variable_color_metadata@PAGE
    add x0, x0, variable_color_metadata@PAGEOFF
    mov x1, #0   // MetadataState::Complete
    ret
#endif

.globl _$s7Symbols19SymbolEffectOptionsVMa
_$s7Symbols19SymbolEffectOptionsVMa:
#if defined(__x86_64__)
    lea options_metadata(%rip), %rax
    xor %edx, %edx   // MetadataState::Complete
    ret
#elif defined(__aarch64__)
    adrp x0, options_metadata@PAGE
    add x0, x0, options_metadata@PAGEOFF
    mov x1, #0   // MetadataState::Complete
    ret
#endif
