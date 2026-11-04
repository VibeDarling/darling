@testable import Symbols

func discrete<T: SymbolEffect & DiscreteSymbolEffect>(_ effect: T) -> SymbolEffectConfiguration {
    effect.configuration
}
func indefinite<T: SymbolEffect & IndefiniteSymbolEffect>(_ effect: T) {}
func transition<T: SymbolEffect & ContentTransitionSymbolEffect>(_ effect: T) {}

let bounce = BounceSymbolEffect.bounce
assert(bounce.down.wholeSymbol == bounce.wholeSymbol.down)
assert(bounce.up != bounce.down)
assert(bounce.down.up == bounce.up)
assert(bounce.down.wholeSymbol.byLayer == bounce.down.byLayer)
assert(bounce != bounce.down)
let choices = discrete(bounce.down.wholeSymbol).choices
assert(choices.kind == .bounce && choices.direction == .down && choices.scope == .wholeSymbol)
assert(bounce.configuration.choices.direction == nil)
indefinite(bounce)

let color = VariableColorSymbolEffect.variableColor
assert(color.cumulative.dimInactiveLayers == color.dimInactiveLayers.cumulative)
assert(color.cumulative.iterative == color.iterative)
assert(color.iterative.cumulative == color.cumulative)
assert(color.dimInactiveLayers.hideInactiveLayers == color.hideInactiveLayers)
let colors = discrete(color.cumulative.dimInactiveLayers).choices
assert(colors.kind == .variableColor && colors.colorMode == .cumulative && colors.inactiveLayers == .dim)
indefinite(color)
transition(ReplaceSymbolEffect.replace.downUp)
transition(AutomaticSymbolEffect.automatic)
assert(ReplaceSymbolEffect.replace.downUp.configuration.choices.direction == .downUp)
assert(AutomaticSymbolEffect.automatic.configuration.choices.kind == .automatic)
assert(SymbolEffectOptions.default != SymbolEffectOptions.nonRepeating)
assert(Set([bounce.up, bounce.down, bounce.up]).count == 2)
print("PASS Symbols marker clients and composed configurations")
