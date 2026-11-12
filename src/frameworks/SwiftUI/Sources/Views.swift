// This file is part of Darling.
//
// Copyright (C) 2026 Darling Developers
//
// Darling is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// The primitive views: Text, stacks, Spacer, Divider, Button.

// MARK: - Text

/// A string key, as Text("Tapped \(count) times") takes. There is no
/// localization: the key is the text.
public struct LocalizedStringKey: Hashable, ExpressibleByStringInterpolation {
	let key: String

	public init(_ value: String) {
		key = value
	}

	public init(stringLiteral value: String) {
		key = value
	}

	public init(stringInterpolation: StringInterpolation) {
		key = stringInterpolation.output
	}

	public struct StringInterpolation: StringInterpolationProtocol {
		var output = ""

		public init(literalCapacity: Int, interpolationCount: Int) {
			output.reserveCapacity(literalCapacity + interpolationCount * 4)
		}

		public mutating func appendLiteral(_ literal: String) {
			output += literal
		}

		public mutating func appendInterpolation<T>(_ value: T) {
			output += String(describing: value)
		}

		public mutating func appendInterpolation(_ text: Text) {
			output += text.content
		}
	}
}

public struct Text: View, Equatable {
	public typealias Body = Never
	var content: String
	var font: Font?
	var color: Color?
	var weight: Font.Weight?
	var isItalic = false

	public init(_ key: LocalizedStringKey) {
		content = key.key
	}

	public init(verbatim content: String) {
		self.content = content
	}

	@_disfavoredOverload
	public init<S: StringProtocol>(_ content: S) {
		self.content = String(content)
	}

	public func font(_ font: Font?) -> Text {
		var text = self
		text.font = font
		return text
	}

	public func foregroundColor(_ color: Color?) -> Text {
		var text = self
		text.color = color
		return text
	}

	public func fontWeight(_ weight: Font.Weight?) -> Text {
		var text = self
		text.weight = weight
		return text
	}

	public func bold() -> Text { fontWeight(.bold) }

	public func italic() -> Text {
		var text = self
		text.isItalic = true
		return text
	}

	public static func + (lhs: Text, rhs: Text) -> Text {
		var text = lhs
		text.content += rhs.content
		return text
	}
}

extension Text: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		let environment = context.environment
		let node = Node(.text)
		node.text = content
		var font = self.font ?? environment.font ?? .body
		if let weight = weight {
			font = font.weight(weight)
		}
		if isItalic {
			font = font.italic()
		}
		node.font = font
		node.color = color ?? environment.foregroundColor
			?? (environment.isButtonLabel ? environment.tint ?? .accentColor : .primary)
		node.textAlignment = environment.multilineTextAlignment
		node.lineLimit = environment.lineLimit ?? 0
		return [node]
	}
}

// MARK: - Stacks

public struct VStack<Content: View>: View {
	public typealias Body = Never
	let alignment: HorizontalAlignment
	let spacing: Double?
	let content: Content

	public init(alignment: HorizontalAlignment = .center, spacing: Double? = nil, @ViewBuilder content: () -> Content) {
		self.alignment = alignment
		self.spacing = spacing
		self.content = content()
	}
}

extension VStack: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		let node = Node(.stack)
		node.axis = .vertical
		node.spacing = spacing
		node.alignment = Alignment(horizontal: alignment, vertical: .center)
		node.children = SwiftUI._makeNodes(content, context.child("v"))
		return [node]
	}
}

public struct HStack<Content: View>: View {
	public typealias Body = Never
	let alignment: VerticalAlignment
	let spacing: Double?
	let content: Content

	public init(alignment: VerticalAlignment = .center, spacing: Double? = nil, @ViewBuilder content: () -> Content) {
		self.alignment = alignment
		self.spacing = spacing
		self.content = content()
	}
}

extension HStack: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		let node = Node(.stack)
		node.axis = .horizontal
		node.spacing = spacing
		node.alignment = Alignment(horizontal: .center, vertical: alignment)
		node.children = SwiftUI._makeNodes(content, context.child("h"))
		return [node]
	}
}

/// Views on top of each other, aligned within the largest.
public struct ZStack<Content: View>: View {
	public typealias Body = Never
	let alignment: Alignment
	let content: Content

	public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
		self.alignment = alignment
		self.content = content()
	}
}

extension ZStack: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		let node = Node(.zstack)
		node.alignment = alignment
		node.children = SwiftUI._makeNodes(content, context.child("z"))
		return [node]
	}
}

/// Takes the space a stack has left along its axis (both axes elsewhere).
public struct Spacer: View {
	public typealias Body = Never
	public var minLength: Double?

	public init(minLength: Double? = nil) {
		self.minLength = minLength
	}
}

extension Spacer: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		let node = Node(.spacer)
		node.minLength = minLength ?? 8
		return [node]
	}
}

/// A thin line across a stack.
public struct Divider: View {
	public typealias Body = Never
	public init() {}
}

extension Divider: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		let node = Node(.divider)
		node.color = Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255, opacity: 0.29)
		return [node]
	}
}

// MARK: - Button

public struct Button<Label: View>: View {
	public typealias Body = Never
	let label: Label
	let action: () -> Void

	public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
		self.action = action
		self.label = label()
	}
}

extension Button where Label == Text {
	public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
		self.init(action: action) { Text(titleKey) }
	}

	@_disfavoredOverload
	public init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {
		self.init(action: action) { Text(title) }
	}
}

extension Button: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		var labelContext = context.child("label")
		labelContext.environment.isButtonLabel = true
		let node = Node(.button)
		node.children = [_makeNode(label, labelContext)]
		node.action = action
		return [node]
	}
}
