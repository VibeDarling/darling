// This file is part of Darling.
//
// Copyright (C) 2026 Darling Developers
//
// Darling is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// Darling's SwiftUI: a small, source-compatible implementation of the SwiftUI
// API that renders through Darling's UIKit (see backend/). It is not Apple's
// SwiftUI and not ABI-compatible with it: apps are built from source against
// this module. See README.md for what is covered.

/// A piece of user interface. Composite views describe themselves with
/// `body`; the primitive views of this module have `Body == Never`.
public protocol View {
	associatedtype Body: View
	@ViewBuilder var body: Self.Body { get }
}

extension Never: View {
	public typealias Body = Never
	public var body: Never { fatalError("Never has no body") }
}

extension View where Body == Never {
	public var body: Never {
		fatalError("\(Self.self) is a primitive view and has no body")
	}
}

/// What primitive views do instead of having a body: produce render nodes.
/// A view may produce several nodes (a tuple, ForEach, an empty view none);
/// stacks lay out all of them.
protocol _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node]
}

/// The state and environment a view tree is resolved with.
struct ResolveContext {
	var path: String
	var environment: EnvironmentValues
	let renderer: Renderer

	func child(_ key: String) -> ResolveContext {
		var context = self
		context.path += "/" + key
		return context
	}
}

/// Resolves any view into render nodes: primitive views make them, composite
/// views get their dynamic properties (@State) bound and resolve their body.
func _makeNodes<V: View>(_ view: V, _ context: ResolveContext) -> [Node] {
	if let primitive = view as? _PrimitiveView {
		return primitive._makeNodes(context)
	}
	let key = context.path + ":" + _typeName(V.self, qualified: false)
	context.renderer.bindDynamicProperties(of: view, key: key)
	return _makeNodes(view.body, context.child("b"))
}

/// Resolves a view to exactly one node, wrapping several in a vertical stack
/// (what SwiftUI does for a modifier applied to a tuple of views).
func _makeNode<V: View>(_ view: V, _ context: ResolveContext) -> Node {
	let nodes = _makeNodes(view, context)
	if nodes.count == 1 {
		return nodes[0]
	}
	let stack = Node(.stack)
	stack.axis = .vertical
	stack.children = nodes
	return stack
}

// MARK: - Basic views

public struct EmptyView: View {
	public typealias Body = Never
	public init() {}
}

extension EmptyView: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] { [] }
}

/// A type-erased view.
public struct AnyView: View {
	public typealias Body = Never
	let make: (ResolveContext) -> [Node]
	let typeName: String

	public init<V: View>(_ view: V) {
		if let any = view as? AnyView {
			self = any
			return
		}
		make = { SwiftUI._makeNodes(view, $0) }
		typeName = _typeName(V.self, qualified: false)
	}

	public init<V: View>(erasing view: V) {
		self.init(view)
	}
}

extension AnyView: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		// The erased type is part of the path, so state does not survive a
		// change of the view type behind an AnyView, as in SwiftUI.
		make(context.child(typeName))
	}
}

/// Views in sequence, as a view builder makes from several statements.
public struct TupleView<T>: View {
	public typealias Body = Never
	public var value: T
	let children: [(ResolveContext) -> [Node]]

	public init(_ value: T) {
		self.value = value
		// Built without a builder: Mirror finds the elements.
		children = Mirror(reflecting: value).children.map { child in
			let element = child.value
			return { context in
				guard let view = element as? any View else { return [] }
				return SwiftUI._makeNodesOpened(view, context)
			}
		}
	}

	init(_ value: T, children: [(ResolveContext) -> [Node]]) {
		self.value = value
		self.children = children
	}
}

func _makeNodesOpened(_ view: any View, _ context: ResolveContext) -> [Node] {
	_makeNodes(view, context)
}

extension TupleView: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		var nodes: [Node] = []
		for (index, child) in children.enumerated() {
			nodes += child(context.child(String(index)))
		}
		return nodes
	}
}

/// The result of an if/else in a view builder.
public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View {
	public typealias Body = Never
	enum Storage {
		case trueContent(TrueContent)
		case falseContent(FalseContent)
	}
	let storage: Storage
}

extension _ConditionalContent: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		switch storage {
		case .trueContent(let view):
			return SwiftUI._makeNodes(view, context.child("T"))
		case .falseContent(let view):
			return SwiftUI._makeNodes(view, context.child("F"))
		}
	}
}

// Not a primitive view itself: a dynamic cast of an Optional to a protocol
// looks through the Optional, so `nil` would never match. Its body is.
extension Optional: View where Wrapped: View {
	public var body: _OptionalContent<Wrapped> { _OptionalContent(content: self) }
}

public struct _OptionalContent<Wrapped: View>: View {
	public typealias Body = Never
	let content: Wrapped?
}

extension _OptionalContent: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		guard let view = content else { return [] }
		return SwiftUI._makeNodes(view, context.child("some"))
	}
}

/// Groups views without laying them out.
public struct Group<Content: View>: View {
	public typealias Body = Never
	let content: Content

	public init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}
}

extension Group: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		SwiftUI._makeNodes(content, context.child("g"))
	}
}

/// One view per element of a collection.
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
	public typealias Body = Never
	public var data: Data
	public var content: (Data.Element) -> Content
	let id: (Data.Element) -> ID

	public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
		self.data = data
		self.content = content
		self.id = { $0[keyPath: id] }
	}
}

extension ForEach where Data == Range<Int>, ID == Int {
	public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
		self.data = data
		self.content = content
		self.id = { $0 }
	}
}

extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
	public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
		self.data = data
		self.content = content
		self.id = { $0.id }
	}
}

extension ForEach: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		var nodes: [Node] = []
		for element in data {
			nodes += SwiftUI._makeNodes(content(element), context.child("id=\(id(element))"))
		}
		return nodes
	}
}
