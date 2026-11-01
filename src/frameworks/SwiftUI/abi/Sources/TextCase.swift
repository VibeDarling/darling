private struct TextCaseKey: EnvironmentKey { static let defaultValue: Text.Case? = nil }
extension Text {
    public enum Case: Hashable { case uppercase, lowercase }
}
extension EnvironmentValues {
    public var textCase: Text.Case? { get { self[TextCaseKey.self] } set { self[TextCaseKey.self] = newValue } }
}
extension View {
    @inlinable public func textCase(_ textCase: Text.Case?) -> some View { environment(\.textCase, textCase) }
}
func applyTextCase(_ textCase: Text.Case?, text: inout String, runs: inout [[String: Any]]) {
    guard let textCase = textCase else { return }
    func convert(_ text: String) -> String {
        if textCase == .uppercase { return text.uppercased() }
        // Swift Core exposes per-scalar lowercase mappings. Apply the Unicode
        // default final-sigma context across case-ignorable scalars as well.
        let scalars = Array(text.unicodeScalars)
        var following = Array(repeating: false, count: scalars.count), cased = false
        for i in scalars.indices.reversed() {
            following[i] = cased
            if !scalars[i].properties.isCaseIgnorable { cased = scalars[i].properties.isCased }
        }
        var result = "", preceding = false
        for i in scalars.indices {
            let scalar = scalars[i]
            if scalar.value == 0x03A3 && preceding && !following[i] { result += "ς" }
            else { result += String(scalar).lowercased() }
            if !scalar.properties.isCaseIgnorable { preceding = scalar.properties.isCased }
        }
        return result
    }
    let converted = convert(text)
    if !runs.isEmpty {
        // Use the whole string's case mapping for contextual rules (for example
        // final sigma). Scalar expansion lengths map its existing run endpoints.
        var offsets = [0: 0], source = 0, target = 0
        for scalar in text.unicodeScalars {
            let value = String(scalar)
            source += value.utf16.count; target += convert(value).utf16.count
            offsets[source] = target
        }
        precondition(target == converted.utf16.count, "SwiftUI: unsupported contextual case expansion")
        for index in runs.indices {
            guard let start = runs[index]["start"] as? Int, let end = runs[index]["end"] as? Int,
                  let newStart = offsets[start], let newEnd = offsets[end] else { preconditionFailure("invalid attributed case range") }
            runs[index]["start"] = newStart; runs[index]["end"] = newEnd
        }
    }
    text = converted
}
