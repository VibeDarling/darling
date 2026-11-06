@testable import Symbols

func discrete<T: SymbolEffect & DiscreteSymbolEffect>(_ effect: T) -> SymbolEffectConfiguration {
    effect.configuration
}
func indefinite<T: SymbolEffect & IndefiniteSymbolEffect>(_ effect: T) {}
func transition<T: SymbolEffect & ContentTransitionSymbolEffect>(_ effect: T) {}

let bounce = BounceSymbolEffect.bounce
precondition(bounce.down.wholeSymbol == bounce.wholeSymbol.down)
precondition(bounce.up != bounce.down)
precondition(bounce.down.up == bounce.up)
precondition(bounce.down.wholeSymbol.byLayer == bounce.down.byLayer)
precondition(bounce != bounce.down)
let choices = discrete(bounce.down.wholeSymbol).choices
precondition(choices.kind == .bounce && choices.direction == .down && choices.scope == .wholeSymbol)
precondition(bounce.configuration.choices.direction == nil)
indefinite(bounce)

let color = VariableColorSymbolEffect.variableColor
precondition(color.cumulative.dimInactiveLayers == color.dimInactiveLayers.cumulative)
precondition(color.cumulative.iterative == color.iterative)
precondition(color.iterative.cumulative == color.cumulative)
precondition(color.dimInactiveLayers.hideInactiveLayers == color.hideInactiveLayers)
let colors = discrete(color.cumulative.dimInactiveLayers).choices
precondition(colors.kind == .variableColor && colors.colorMode == .cumulative && colors.inactiveLayers == .dim)
indefinite(color)
transition(ReplaceSymbolEffect.replace.downUp)
transition(AutomaticSymbolEffect.automatic)
precondition(ReplaceSymbolEffect.replace.downUp.configuration.choices.direction == .downUp)
precondition(AutomaticSymbolEffect.automatic.configuration.choices.kind == .automatic)
precondition(SymbolEffectOptions.default != SymbolEffectOptions.nonRepeating)
precondition(Set([bounce.up, bounce.down, bounce.up]).count == 2)
print("PASS Symbols marker clients and composed configurations")
