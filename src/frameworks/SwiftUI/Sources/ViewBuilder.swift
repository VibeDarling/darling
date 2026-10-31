// This file is part of Darling.
//
// Copyright (C) 2026 Darling Developers
//
// Darling is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// Fixed-arity buildBlock overloads (up to ten views, like SwiftUI before
// parameter packs): packs in generic types need an iOS 17 runtime to deploy
// to, and apps here target iOS 14.

@resultBuilder
public enum ViewBuilder {
	public static func buildExpression<Content: View>(_ content: Content) -> Content { content }

	public static func buildBlock() -> EmptyView { EmptyView() }

	public static func buildBlock<Content: View>(_ content: Content) -> Content { content }

	public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }

	public static func buildOptional<Content: View>(_ content: Content?) -> Content? { content }

	public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
		_ConditionalContent(storage: .trueContent(first))
	}

	public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
		_ConditionalContent(storage: .falseContent(second))
	}

	public static func buildLimitedAvailability<Content: View>(_ content: Content) -> AnyView { AnyView(content) }
}

private func child<V: View>(_ view: V) -> (ResolveContext) -> [Node] {
	{ _makeNodes(view, $0) }
}

extension ViewBuilder {
	public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)> {
		TupleView((c0, c1), children: [child(c0), child(c1)])
	}

	public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<(C0, C1, C2)> {
		TupleView((c0, c1, c2), children: [child(c0), child(c1), child(c2)])
	}

	public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleView<(C0, C1, C2, C3)> {
		TupleView((c0, c1, c2, c3), children: [child(c0), child(c1), child(c2), child(c3)])
	}

	public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleView<(C0, C1, C2, C3, C4)> {
		TupleView((c0, c1, c2, c3, c4), children: [child(c0), child(c1), child(c2), child(c3), child(c4)])
	}

	public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleView<(C0, C1, C2, C3, C4, C5)> {
		TupleView((c0, c1, c2, c3, c4, c5), children: [child(c0), child(c1), child(c2), child(c3), child(c4), child(c5)])
	}

	public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleView<(C0, C1, C2, C3, C4, C5, C6)> {
		TupleView((c0, c1, c2, c3, c4, c5, c6), children: [child(c0), child(c1), child(c2), child(c3), child(c4), child(c5), child(c6)])
	}

	public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7)> {
		TupleView((c0, c1, c2, c3, c4, c5, c6, c7), children: [child(c0), child(c1), child(c2), child(c3), child(c4), child(c5), child(c6), child(c7)])
	}

	public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8)> {
		TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8), children: [child(c0), child(c1), child(c2), child(c3), child(c4), child(c5), child(c6), child(c7), child(c8)])
	}

	public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> {
		TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9), children: [child(c0), child(c1), child(c2), child(c3), child(c4), child(c5), child(c6), child(c7), child(c8), child(c9)])
	}
}
