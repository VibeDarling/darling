// This file is part of Darling.
//
// Copyright (C) 2026 Darling Developers
//
// Darling is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// View modifiers: the ViewModifier protocol for apps' own, and the built-in
// ones (padding, frame, background, overlay, font, foregroundColor, ...).

public protocol ViewModifier {
	associatedtype Body: View
	typealias Content = _ViewModifier_Content<Self>
	@ViewBuilder func body(content: Self.Content) -> Self.Body
}

extension ViewModifier where Body == Never {
	public func body(content: Content) -> Never {
		fatalError("\(Self.self) is a primitive modifier and has no body")
	}
}

/// The view a modifier's body receives: the view it modifies.
public struct _ViewModifier_Content<Modifier: ViewModifier>: View {
	public typealias Body = Never
	let make: (ResolveContext) -> [Node]
}

extension _ViewModifier_Content: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		make(context)
	}
}

/// Built-in modifiers resolve their content themselves.
protocol _PrimitiveModifier {
	func _apply(_ content: (ResolveContext) -> [Node], _ context: ResolveContext) -> [Node]
}

public struct ModifiedContent<Content, Modifier> {
	public var content: Content
	public var modifier: Modifier

	public init(content: Content, modifier: Modifier) {
		self.content = content
		self.modifier = modifier
	}
}

extension ModifiedContent: View where Content: View, Modifier: ViewModifier {
	public typealias Body = Never
}

extension ModifiedContent: _PrimitiveView where Content: View, Modifier: ViewModifier {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		let content = self.content
		let make: (ResolveContext) -> [Node] = { SwiftUI._makeNodes(content, $0.child("c")) }
		if let primitive = modifier as? _PrimitiveModifier {
			return primitive._apply(make, context)
		}
		let key = context.path + ":" + _typeName(Modifier.self, qualified: false)
		context.renderer.bindDynamicProperties(of: modifier, key: key)
		return SwiftUI._makeNodes(modifier.body(content: _ViewModifier_Content(make: make)), context.child("m"))
	}
}

extension View {
	public func modifier<T>(_ modifier: T) -> ModifiedContent<Self, T> {
		ModifiedContent(content: self, modifier: modifier)
	}
}

private func single(_ nodes: [Node]) -> Node {
	if nodes.count == 1 {
		return nodes[0]
	}
	let stack = Node(.stack)
	stack.axis = .vertical
	stack.children = nodes
	return stack
}

// MARK: - Environment modifiers

public struct _EnvironmentModifier: ViewModifier, _PrimitiveModifier {
	public typealias Body = Never
	let change: (inout EnvironmentValues) -> Void

	func _apply(_ content: (ResolveContext) -> [Node], _ context: ResolveContext) -> [Node] {
		var inner = context
		change(&inner.environment)
		return content(inner)
	}
}

extension View {
	public func font(_ font: Font?) -> ModifiedContent<Self, _EnvironmentModifier> {
		modifier(_EnvironmentModifier { $0.font = font })
	}

	public func foregroundColor(_ color: Color?) -> ModifiedContent<Self, _EnvironmentModifier> {
		modifier(_EnvironmentModifier { $0.foregroundColor = color })
	}

	public func foregroundStyle(_ color: Color) -> ModifiedContent<Self, _EnvironmentModifier> {
		foregroundColor(color)
	}

	public func tint(_ color: Color?) -> ModifiedContent<Self, _EnvironmentModifier> {
		modifier(_EnvironmentModifier { $0.tint = color })
	}

	public func multilineTextAlignment(_ alignment: TextAlignment) -> ModifiedContent<Self, _EnvironmentModifier> {
		modifier(_EnvironmentModifier { $0.multilineTextAlignment = alignment })
	}

	public func lineLimit(_ limit: Int?) -> ModifiedContent<Self, _EnvironmentModifier> {
		modifier(_EnvironmentModifier { $0.lineLimit = limit })
	}
}

// MARK: - Layout modifiers

public struct _PaddingModifier: ViewModifier, _PrimitiveModifier {
	public typealias Body = Never
	let insets: EdgeInsets

	func _apply(_ content: (ResolveContext) -> [Node], _ context: ResolveContext) -> [Node] {
		let node = Node(.padding)
		node.insets = insets
		node.children = [single(content(context))]
		return [node]
	}
}

extension View {
	public func padding(_ insets: EdgeInsets) -> ModifiedContent<Self, _PaddingModifier> {
		modifier(_PaddingModifier(insets: insets))
	}

	public func padding(_ edges: Edge.Set = .all, _ length: Double? = nil) -> ModifiedContent<Self, _PaddingModifier> {
		let value = length ?? 16
		return padding(EdgeInsets(top: edges.contains(.top) ? value : 0,
		                          leading: edges.contains(.leading) ? value : 0,
		                          bottom: edges.contains(.bottom) ? value : 0,
		                          trailing: edges.contains(.trailing) ? value : 0))
	}

	public func padding(_ length: Double) -> ModifiedContent<Self, _PaddingModifier> {
		padding(.all, length)
	}
}

public struct _FrameModifier: ViewModifier, _PrimitiveModifier {
	public typealias Body = Never
	var width: Double?, height: Double?
	var minWidth: Double?, maxWidth: Double?, minHeight: Double?, maxHeight: Double?
	var alignment: Alignment

	func _apply(_ content: (ResolveContext) -> [Node], _ context: ResolveContext) -> [Node] {
		let node = Node(.frame)
		node.frameSpec = self
		node.alignment = alignment
		node.children = [single(content(context))]
		return [node]
	}
}

extension View {
	public func frame(width: Double? = nil, height: Double? = nil, alignment: Alignment = .center) -> ModifiedContent<Self, _FrameModifier> {
		modifier(_FrameModifier(width: width, height: height, alignment: alignment))
	}

	public func frame(minWidth: Double? = nil, idealWidth: Double? = nil, maxWidth: Double? = nil,
	                  minHeight: Double? = nil, idealHeight: Double? = nil, maxHeight: Double? = nil,
	                  alignment: Alignment = .center) -> ModifiedContent<Self, _FrameModifier> {
		modifier(_FrameModifier(minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight, maxHeight: maxHeight, alignment: alignment))
	}
}

// MARK: - Decoration

public struct _BackgroundModifier<Background: View>: ViewModifier, _PrimitiveModifier {
	public typealias Body = Never
	let background: Background
	let alignment: Alignment
	let isOverlay: Bool

	func _apply(_ content: (ResolveContext) -> [Node], _ context: ResolveContext) -> [Node] {
		let node = Node(isOverlay ? .overlay : .background)
		node.alignment = alignment
		let decoration = single(SwiftUI._makeNodes(background, context.child(isOverlay ? "ov" : "bg")))
		node.children = [single(content(context)), decoration]
		return [node]
	}
}

extension View {
	public func background<Background: View>(_ background: Background, alignment: Alignment = .center) -> ModifiedContent<Self, _BackgroundModifier<Background>> {
		modifier(_BackgroundModifier(background: background, alignment: alignment, isOverlay: false))
	}

	public func background<Background: View>(alignment: Alignment = .center, @ViewBuilder content: () -> Background) -> ModifiedContent<Self, _BackgroundModifier<Background>> {
		background(content(), alignment: alignment)
	}

	public func overlay<Overlay: View>(_ overlay: Overlay, alignment: Alignment = .center) -> ModifiedContent<Self, _BackgroundModifier<Overlay>> {
		modifier(_BackgroundModifier(background: overlay, alignment: alignment, isOverlay: true))
	}

	public func overlay<Overlay: View>(alignment: Alignment = .center, @ViewBuilder content: () -> Overlay) -> ModifiedContent<Self, _BackgroundModifier<Overlay>> {
		overlay(content(), alignment: alignment)
	}
}

public struct _OpacityModifier: ViewModifier, _PrimitiveModifier {
	public typealias Body = Never
	let opacity: Double

	func _apply(_ content: (ResolveContext) -> [Node], _ context: ResolveContext) -> [Node] {
		let node = Node(.padding)
		node.opacity = opacity
		node.children = [single(content(context))]
		return [node]
	}
}

extension View {
	public func opacity(_ opacity: Double) -> ModifiedContent<Self, _OpacityModifier> {
		modifier(_OpacityModifier(opacity: opacity))
	}
}

// MARK: - Lifecycle

public struct _AppearModifier: ViewModifier, _PrimitiveModifier {
	public typealias Body = Never
	let action: () -> Void

	func _apply(_ content: (ResolveContext) -> [Node], _ context: ResolveContext) -> [Node] {
		context.renderer.onAppear(key: context.path, action)
		return content(context)
	}
}

extension View {
	/// Runs once when the view first appears in the tree.
	public func onAppear(perform action: (() -> Void)? = nil) -> ModifiedContent<Self, _AppearModifier> {
		modifier(_AppearModifier(action: action ?? {}))
	}
}
