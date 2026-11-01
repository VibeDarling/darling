public enum ColorScheme: CaseIterable, Hashable { case light, dark }
public enum ColorSchemeContrast: CaseIterable, Hashable { case standard, increased }
private struct ColorSchemeKey: EnvironmentKey { static let defaultValue = ColorScheme.light }
private struct ContrastKey: EnvironmentKey { static let defaultValue = ColorSchemeContrast.standard }
extension EnvironmentValues {
    public var colorScheme: ColorScheme {
        get { self[ColorSchemeKey.self] }
        set { self[ColorSchemeKey.self] = newValue }
    }
    public var colorSchemeContrast: ColorSchemeContrast { self[ContrastKey.self] }
    public var _colorSchemeContrast: ColorSchemeContrast {
        get { self[ContrastKey.self] }
        set { self[ContrastKey.self] = newValue }
    }
}
