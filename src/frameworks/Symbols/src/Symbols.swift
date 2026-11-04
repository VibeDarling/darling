public struct SymbolEffectConfiguration {
    enum Kind: Hashable, Sendable { case automatic, bounce, replace, variableColor }
    enum Direction: Hashable, Sendable { case up, down, downUp }
    enum Scope: Hashable, Sendable { case byLayer, wholeSymbol }
    enum ColorMode: Hashable, Sendable { case cumulative, iterative }
    enum InactiveLayers: Hashable, Sendable { case dim, hide }
    struct Choices: Hashable, Sendable {
        var kind: Kind
        var direction: Direction?
        var scope: Scope?
        var colorMode: ColorMode?
        var inactiveLayers: InactiveLayers?
    }
    let choices: Choices
}

public protocol SymbolEffect: Hashable, Sendable {
    var configuration: SymbolEffectConfiguration { get }
}
public protocol DiscreteSymbolEffect {}
public protocol IndefiniteSymbolEffect {}
public protocol ContentTransitionSymbolEffect {}

public struct AutomaticSymbolEffect: SymbolEffect, ContentTransitionSymbolEffect {
    public init() {}
    public var configuration: SymbolEffectConfiguration {
        .init(choices: .init(kind: .automatic))
    }
}

public struct BounceSymbolEffect: SymbolEffect, DiscreteSymbolEffect, IndefiniteSymbolEffect {
    private var choices = SymbolEffectConfiguration.Choices(kind: .bounce)
    public init() {}
    public var up: Self { var result = self; result.choices.direction = .up; return result }
    public var down: Self { var result = self; result.choices.direction = .down; return result }
    public var byLayer: Self { var result = self; result.choices.scope = .byLayer; return result }
    public var wholeSymbol: Self { var result = self; result.choices.scope = .wholeSymbol; return result }
    public var configuration: SymbolEffectConfiguration { .init(choices: choices) }
}

public struct ReplaceSymbolEffect: SymbolEffect, ContentTransitionSymbolEffect {
    private var choices = SymbolEffectConfiguration.Choices(kind: .replace)
    public init() {}
    public var downUp: Self { var result = self; result.choices.direction = .downUp; return result }
    public var configuration: SymbolEffectConfiguration { .init(choices: choices) }
}

public struct VariableColorSymbolEffect: SymbolEffect, DiscreteSymbolEffect, IndefiniteSymbolEffect {
    private var choices = SymbolEffectConfiguration.Choices(kind: .variableColor)
    public init() {}
    public var cumulative: Self { var result = self; result.choices.colorMode = .cumulative; return result }
    public var iterative: Self { var result = self; result.choices.colorMode = .iterative; return result }
    public var dimInactiveLayers: Self { var result = self; result.choices.inactiveLayers = .dim; return result }
    public var hideInactiveLayers: Self { var result = self; result.choices.inactiveLayers = .hide; return result }
    public var configuration: SymbolEffectConfiguration { .init(choices: choices) }
}

public struct SymbolEffectOptions: Hashable, Sendable {
    private var repeats: Bool?
    private init(repeats: Bool?) { self.repeats = repeats }
    public static var `default`: Self { .init(repeats: nil) }
    public static var nonRepeating: Self { .init(repeats: false) }
}

extension SymbolEffect where Self == BounceSymbolEffect {
    public static var bounce: Self { .init() }
}
extension SymbolEffect where Self == ReplaceSymbolEffect {
    public static var replace: Self { .init() }
}
extension SymbolEffect where Self == AutomaticSymbolEffect {
    public static var automatic: Self { .init() }
}
extension SymbolEffect where Self == VariableColorSymbolEffect {
    public static var variableColor: Self { .init() }
}
