// This file is part of Darling.
//
// Copyright (C) 2026 Darling Developers
//
// Darling is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// @State keeps its value in a box. A view struct is made afresh each time its
// parent's body runs, with a fresh box holding the initial value; the
// renderer then links that box to the one it keeps for the view's place in
// the tree (Renderer.bindDynamicProperties), so reads and writes reach the
// value that persists. A write schedules a re-render.

public protocol DynamicProperty {
	mutating func update()
}

extension DynamicProperty {
	public mutating func update() {}
}

/// A @State or similar property the renderer links to persistent storage.
protocol _StateLink {
	var _box: AnyObject { get }
	func _link(to persistent: AnyObject)
}

final class StateBox<Value> {
	var value: Value
	/// Set on a fresh box: the persistent one it stands for.
	var target: StateBox<Value>?

	init(_ value: Value) {
		self.value = value
	}

	var resolved: StateBox<Value> {
		var box = self
		while let next = box.target {
			box = next
		}
		return box
	}
}

@propertyWrapper
public struct State<Value>: DynamicProperty {
	let box: StateBox<Value>

	public init(wrappedValue value: Value) {
		box = StateBox(value)
	}

	public init(initialValue value: Value) {
		box = StateBox(value)
	}

	public var wrappedValue: Value {
		get { box.resolved.value }
		nonmutating set {
			box.resolved.value = newValue
			Renderer.setNeedsUpdate()
		}
	}

	public var projectedValue: Binding<Value> {
		let storage = box.resolved
		return Binding(get: { storage.value }, set: { newValue in
			storage.value = newValue
			Renderer.setNeedsUpdate()
		})
	}
}

extension State where Value: ExpressibleByNilLiteral {
	public init() {
		self.init(wrappedValue: nil)
	}
}

extension State: _StateLink {
	var _box: AnyObject { box.resolved }

	func _link(to persistent: AnyObject) {
		guard let target = persistent as? StateBox<Value>, target !== box else { return }
		box.target = target
	}
}

/// A reference to a value someone else owns, usually a parent's @State.
@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {
	let getter: () -> Value
	let setter: (Value) -> Void

	public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
		getter = get
		setter = set
	}

	public init(projectedValue: Binding<Value>) {
		self = projectedValue
	}

	public static func constant(_ value: Value) -> Binding<Value> {
		Binding(get: { value }, set: { _ in })
	}

	public var wrappedValue: Value {
		get { getter() }
		nonmutating set { setter(newValue) }
	}

	public var projectedValue: Binding<Value> { self }

	public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
		let getter = self.getter, setter = self.setter
		return Binding<Subject>(get: { getter()[keyPath: keyPath] }, set: { newValue in
			var value = getter()
			value[keyPath: keyPath] = newValue
			setter(value)
		})
	}
}

extension Binding: DynamicProperty {}
