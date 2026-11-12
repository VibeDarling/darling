// This file is part of Darling.
//
// Copyright (C) 2026 Darling Developers
//
// Darling is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// Rendering: views resolve to a tree of Nodes; the Renderer reconciles each
// new tree with the previous one (reusing the UIViews of nodes of the same
// kind at the same place), then lays it out in the host's safe area.

internal import SwiftUIBackend

// MARK: - Nodes

final class ActionBox {
	var action: () -> Void
	init(_ action: @escaping () -> Void) { self.action = action }
}

final class Node {
	enum Kind {
		case text, color, divider, spacer, stack, zstack, padding, frame, background, overlay, button
	}

	let kind: Kind
	var children: [Node] = []

	// Properties, by kind.
	var text = ""
	var font = Font.body
	var color: Color?
	var textAlignment = TextAlignment.leading
	var lineLimit = 0
	var axis = Axis.vertical
	var spacing: Double?
	var alignment = Alignment.center
	var minLength = 8.0
	var insets = EdgeInsets()
	var opacity = 1.0
	var frameSpec: _FrameModifier?
	var action: (() -> Void)?
	/// For a spacer or divider: the axis of the stack it is in, if any.
	var stackAxis: Axis?

	// The UIKit side.
	var view: UnsafeMutableRawPointer?
	var control: UnsafeMutableRawPointer?
	var actionBox: ActionBox?
	var measured: [Double: CGSize] = [:]

	init(_ kind: Kind) {
		self.kind = kind
	}

	static let debug = SUIDebugEnabled() != 0
	static var debugOrigin = (x: 0.0, y: 0.0)

	func unmount() {
		for child in children {
			child.unmount()
		}
		if let control = control {
			SUIViewRelease(control)
			self.control = nil
		}
		if let view = view {
			SUIViewRelease(view)
			self.view = nil
		}
	}

	private func createView() {
		switch kind {
		case .spacer:
			view = nil
		case .text:
			view = SUILabelCreate()
		case .button:
			view = SUIViewCreate()
			let box = ActionBox(action ?? {})
			actionBox = box
			control = SUITapControlCreate({ context in
				Unmanaged<ActionBox>.fromOpaque(context!).takeUnretainedValue().action()
			}, Unmanaged.passUnretained(box).toOpaque())
		default:
			view = SUIViewCreate()
		}
	}

	/// Takes over old's views if it is the same kind of node, else replaces
	/// them; then does the same for the children.
	func mount(reusing old: Node?) {
		let previous: Node?
		if let old = old, old.kind == kind {
			view = old.view
			control = old.control
			actionBox = old.actionBox
			old.view = nil
			old.control = nil
			previous = old
		} else {
			old?.unmount()
			createView()
			previous = nil
		}
		for (index, child) in children.enumerated() {
			if child.kind == .spacer || child.kind == .divider {
				child.stackAxis = kind == .stack ? axis : nil
			}
			let oldChild = previous.flatMap { index < $0.children.count ? $0.children[index] : nil }
			child.mount(reusing: oldChild)
		}
		if let previous = previous, previous.children.count > children.count {
			for extra in previous.children[children.count...] {
				extra.unmount()
			}
		}
		applyProperties(previous: previous)
		guard let view = view else { return }
		var subviews: [UnsafeMutableRawPointer?] = children.compactMap { $0.view }
		if kind == .background {
			subviews.reverse()
		}
		if let control = control {
			subviews.append(control)
		}
		if !subviews.isEmpty || previous != nil {
			subviews.withUnsafeMutableBufferPointer { buffer in
				SUIViewSetSubviews(view, buffer.baseAddress, Int32(buffer.count))
			}
		}
	}

	private func applyProperties(previous: Node?) {
		guard let view = view else { return }
		switch kind {
		case .text:
			if previous?.text != text || previous == nil {
				text.withCString { SUILabelSetText(view, $0) }
			}
			SUILabelSetFont(view, font.size, Int32(font.weight.value), font.isItalic ? 1 : 0)
			let c = color ?? .primary
			SUILabelSetTextColor(view, c.red, c.green, c.blue, c.alpha)
			SUILabelSetAlignment(view, textAlignment == .center ? 1 : textAlignment == .trailing ? 2 : 0)
			SUILabelSetLineLimit(view, Int32(lineLimit))
		case .color, .divider:
			let c = color ?? .clear
			SUIViewSetBackgroundColor(view, c.red, c.green, c.blue, c.alpha)
		case .button:
			actionBox?.action = action ?? {}
		default:
			break
		}
		if previous == nil || previous!.opacity != opacity {
			SUIViewSetAlpha(view, opacity)
		}
	}

	// MARK: Layout

	/// The size this node takes when offered the proposal. A nil dimension
	/// asks for the ideal size; .infinity asks how far it can grow.
	func size(_ proposal: Proposal) -> CGSize {
		switch kind {
		case .text:
			return measureText(maxWidth: proposal.width ?? .infinity)
		case .color:
			return CGSize(width: proposal.width ?? 10, height: proposal.height ?? 10)
		case .divider:
			if stackAxis == .horizontal {
				return CGSize(width: 1, height: proposal.height ?? 0)
			}
			return CGSize(width: proposal.width ?? 0, height: 1)
		case .spacer:
			switch stackAxis {
			case .vertical?:
				return CGSize(width: 0, height: max(minLength, proposal.height ?? minLength))
			case .horizontal?:
				return CGSize(width: max(minLength, proposal.width ?? minLength), height: 0)
			case nil:
				return CGSize(width: max(0, proposal.width ?? minLength), height: max(0, proposal.height ?? minLength))
			}
		case .padding:
			guard let child = children.first else { return CGSize(width: insets.leading + insets.trailing, height: insets.top + insets.bottom) }
			let inner = child.size(proposal.inset(insets))
			return CGSize(width: inner.width + insets.leading + insets.trailing, height: inner.height + insets.top + insets.bottom)
		case .frame:
			return frameLayout(proposal).size
		case .background, .overlay, .button:
			return children.first?.size(proposal) ?? .zero
		case .stack:
			return stackLayout(proposal).size
		case .zstack:
			var result = CGSize.zero
			for child in children {
				let s = child.size(proposal)
				result.width = max(result.width, s.width)
				result.height = max(result.height, s.height)
			}
			return result
		}
	}

	private func measureText(maxWidth: Double) -> CGSize {
		let limit = maxWidth.isFinite ? max(0, maxWidth) : 1e7
		if let cached = measured[limit] {
			return cached
		}
		guard let view = view else { return .zero }
		var width = 0.0, height = 0.0
		SUILabelMeasure(view, limit, &width, &height)
		let result = CGSize(width: min(width, limit), height: height)
		measured[limit] = result
		return result
	}

	private func frameLayout(_ proposal: Proposal) -> (size: CGSize, child: CGSize) {
		let spec = frameSpec!
		func childProposal(_ fixed: Double?, _ offered: Double?, _ lo: Double?, _ hi: Double?) -> Double? {
			if let fixed = fixed { return fixed }
			guard var value = offered else { return nil }
			if let hi = hi { value = min(value, hi) }
			if let lo = lo { value = max(value, lo) }
			return value
		}
		func resolve(_ fixed: Double?, _ offered: Double?, _ lo: Double?, _ hi: Double?, _ child: Double) -> Double {
			if let fixed = fixed { return fixed }
			if lo == nil && hi == nil { return child }
			let low = lo ?? child
			let high = max(low, hi ?? child)
			return min(max(offered ?? child, low), high)
		}
		let inner = Proposal(width: childProposal(spec.width, proposal.width, spec.minWidth, spec.maxWidth),
		                     height: childProposal(spec.height, proposal.height, spec.minHeight, spec.maxHeight))
		let child = children.first?.size(inner) ?? .zero
		let size = CGSize(width: resolve(spec.width, proposal.width, spec.minWidth, spec.maxWidth, child.width),
		                  height: resolve(spec.height, proposal.height, spec.minHeight, spec.maxHeight, child.height))
		return (size, child)
	}

	private func stackLayout(_ proposal: Proposal) -> (size: CGSize, sizes: [CGSize]) {
		let vertical = axis == .vertical
		let count = children.count
		guard count > 0 else { return (.zero, []) }
		let gap = spacing ?? 8
		let totalGap = gap * Double(count - 1)
		let cross = vertical ? proposal.width : proposal.height
		let along = vertical ? proposal.height : proposal.width
		func offer(_ value: Double?) -> Proposal {
			vertical ? Proposal(width: cross, height: value) : Proposal(width: value, height: cross)
		}
		func length(_ size: CGSize) -> Double { vertical ? size.height : size.width }
		func thickness(_ size: CGSize) -> Double { vertical ? size.width : size.height }

		var sizes = [CGSize](repeating: .zero, count: count)
		if let along = along {
			// SwiftUI's division: the least flexible children are sized first,
			// each offered an equal share of what is left.
			var flexibility = [Double](repeating: 0, count: count)
			for (index, child) in children.enumerated() {
				let most = length(child.size(offer(.infinity)))
				let least = length(child.size(offer(0)))
				let range = most - least
				flexibility[index] = range.isNaN ? .infinity : range
			}
			let order = (0..<count).sorted { flexibility[$0] < flexibility[$1] || (flexibility[$0] == flexibility[$1] && $0 < $1) }
			var remaining = max(0, along - totalGap)
			var left = count
			for index in order {
				let share = remaining / Double(left)
				let s = children[index].size(offer(share))
				sizes[index] = s
				remaining = max(0, remaining - length(s))
				left -= 1
			}
		} else {
			for (index, child) in children.enumerated() {
				sizes[index] = child.size(offer(nil))
			}
		}
		var total = totalGap, thick = 0.0
		for s in sizes {
			total += length(s)
			thick = max(thick, thickness(s))
		}
		return (vertical ? CGSize(width: thick, height: total) : CGSize(width: total, height: thick), sizes)
	}

	/// Puts this node at a frame in its parent view's coordinates and lays out
	/// its children in its own.
	func place(x: Double, y: Double, width: Double, height: Double) {
		if Node.debug {
			Node.debugOrigin = (Node.debugOrigin.x + x, Node.debugOrigin.y + y)
			let label = kind == .text ? " \"\(text)\"" : ""
			SUILog("\(kind)\(label) at \(Node.debugOrigin.x),\(Node.debugOrigin.y) size \(width)x\(height)")
		}
		defer {
			if Node.debug {
				Node.debugOrigin = (Node.debugOrigin.x - x, Node.debugOrigin.y - y)
			}
		}
		if let view = view {
			SUIViewSetFrame(view, x, y, width, height)
		}
		if let control = control {
			SUIViewSetFrame(control, 0, 0, width, height)
		}
		let bounds = Proposal(width: width, height: height)
		switch kind {
		case .text, .color, .divider, .spacer:
			break
		case .padding:
			children.first?.place(x: insets.leading, y: insets.top,
			                      width: max(0, width - insets.leading - insets.trailing),
			                      height: max(0, height - insets.top - insets.bottom))
		case .button:
			children.first?.place(x: 0, y: 0, width: width, height: height)
		case .background, .overlay:
			children.first?.place(x: 0, y: 0, width: width, height: height)
			if children.count > 1 {
				let decoration = children[1]
				let s = decoration.size(bounds)
				placeAligned(decoration, s, width, height, alignment)
			}
		case .frame:
			let layout = frameLayout(bounds)
			if let child = children.first {
				placeAligned(child, layout.child, width, height, alignment)
			}
		case .zstack:
			for child in children {
				placeAligned(child, child.size(bounds), width, height, alignment)
			}
		case .stack:
			let layout = stackLayout(bounds)
			let gap = spacing ?? 8
			var position = 0.0
			for (index, child) in children.enumerated() {
				let s = layout.sizes[index]
				if axis == .vertical {
					let x: Double
					switch alignment.horizontal {
					case .leading: x = 0
					case .trailing: x = width - s.width
					case .center: x = (width - s.width) / 2
					}
					child.place(x: x.rounded(), y: position.rounded(), width: s.width, height: s.height)
					position += s.height + gap
				} else {
					let y: Double
					switch alignment.vertical {
					case .top, .firstTextBaseline: y = 0
					case .bottom, .lastTextBaseline: y = height - s.height
					case .center: y = (height - s.height) / 2
					}
					child.place(x: position.rounded(), y: y.rounded(), width: s.width, height: s.height)
					position += s.width + gap
				}
			}
		}
	}

	private func placeAligned(_ child: Node, _ size: CGSize, _ width: Double, _ height: Double, _ alignment: Alignment) {
		let w = min(size.width, width), h = min(size.height, height)
		let x: Double, y: Double
		switch alignment.horizontal {
		case .leading: x = 0
		case .trailing: x = width - w
		case .center: x = (width - w) / 2
		}
		switch alignment.vertical {
		case .top, .firstTextBaseline: y = 0
		case .bottom, .lastTextBaseline: y = height - h
		case .center: y = (height - h) / 2
		}
		child.place(x: x.rounded(), y: y.rounded(), width: w, height: h)
	}
}

struct Proposal {
	var width: Double?
	var height: Double?

	func inset(_ insets: EdgeInsets) -> Proposal {
		Proposal(width: width.map { max(0, $0 - insets.leading - insets.trailing) },
		         height: height.map { max(0, $0 - insets.top - insets.bottom) })
	}
}

// MARK: - Renderer

final class Renderer {
	let root: (ResolveContext) -> [Node]
	var host: UnsafeMutableRawPointer?
	var tree: Node?
	var safeArea = CGRect(x: 0, y: 0, width: 0, height: 0)
	var updateScheduled = false
	var rendered = false

	/// Persistent @State boxes, by place in the tree.
	var states: [String: [AnyObject]] = [:]
	var visited: Set<String> = []
	var appeared: Set<String> = []
	var visitedAppear: Set<String> = []
	var pendingAppear: [() -> Void] = []

	init(root: @escaping (ResolveContext) -> [Node]) {
		self.root = root
	}

	static func setNeedsUpdate() {
		AppLauncher.renderer?.setNeedsUpdate()
	}

	func attach() {
		host = SUIHostCreate({ _, x, y, width, height in
			AppLauncher.renderer?.hostDidLayout(CGRect(x: x, y: y, width: width, height: height))
		}, nil)
	}

	func setNeedsUpdate() {
		guard !updateScheduled else { return }
		updateScheduled = true
		SUIRunOnMainQueue({ _ in AppLauncher.renderer?.update() }, nil)
	}

	func hostDidLayout(_ rect: CGRect) {
		safeArea = rect
		if tree == nil {
			update()
		} else {
			layout()
		}
	}

	func bindDynamicProperties<V>(of view: V, key: String) {
		var fresh: [_StateLink] = []
		for child in Mirror(reflecting: view).children {
			if let link = child.value as? _StateLink {
				fresh.append(link)
			}
		}
		guard !fresh.isEmpty else { return }
		visited.insert(key)
		if let kept = states[key], kept.count == fresh.count {
			for (link, box) in zip(fresh, kept) {
				link._link(to: box)
			}
		} else {
			states[key] = fresh.map { $0._box }
		}
	}

	func onAppear(key: String, _ action: @escaping () -> Void) {
		visitedAppear.insert(key)
		if !appeared.contains(key) {
			appeared.insert(key)
			pendingAppear.append(action)
		}
	}

	func update() {
		updateScheduled = false
		guard let host = host else { return }
		visited = []
		visitedAppear = []
		let context = ResolveContext(path: "", environment: EnvironmentValues(), renderer: self)
		let nodes = root(context)
		let top: Node
		if nodes.count == 1 {
			top = nodes[0]
		} else {
			top = Node(.stack)
			top.children = nodes
		}
		top.mount(reusing: tree)
		tree = top
		var subviews: [UnsafeMutableRawPointer?] = top.view.map { [$0] } ?? []
		subviews.withUnsafeMutableBufferPointer { buffer in
			SUIViewSetSubviews(host, buffer.baseAddress, Int32(buffer.count))
		}
		states = states.filter { visited.contains($0.key) }
		appeared = appeared.intersection(visitedAppear)
		layout()
		if !rendered {
			rendered = true
			SUILog("first render")
		}
		let actions = pendingAppear
		pendingAppear = []
		for action in actions {
			action()
		}
	}

	/// Root content gets the safe area and is centered in it, as in SwiftUI.
	func layout() {
		guard let tree = tree else { return }
		let area = safeArea
		var size = tree.size(Proposal(width: area.size.width, height: area.size.height))
		size.width = min(size.width, area.size.width)
		size.height = min(size.height, area.size.height)
		tree.place(x: (area.origin.x + (area.size.width - size.width) / 2).rounded(),
		           y: (area.origin.y + (area.size.height - size.height) / 2).rounded(),
		           width: size.width, height: size.height)
	}
}
