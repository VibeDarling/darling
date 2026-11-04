// Darling's presenter for the view graph: lays out the render tree and keeps a UIKit view
// hierarchy in step with it, as the ios-android-runtime's native host does for the same tree
// (its swiftui.cpp). Layout follows that host, which adapted OpenSwiftUI's StackLayout and
// FrameLayout (MIT). Everything here calls Darling's UIKit through Objective-C only: Darling has
// no libswiftUIKit.
import Foundation
import CoreFoundation
import UIKit
import DarlingCoreDataBridge
import os.log

// MARK: - Main-thread scheduling

func darlingScheduleUpdate(_ callback: @escaping @convention(c) () -> Void) {
    CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { callback() }
    CFRunLoopWakeUp(CFRunLoopGetMain())
}

// MARK: - Colors

func darlingColorComponents(_ color: UIColor) -> [Double] {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    if color.getRed(&r, green: &g, blue: &b, alpha: &a) { return [Double(r), Double(g), Double(b), Double(a)] }
    var w: CGFloat = 0
    if color.getWhite(&w, alpha: &a) { return [Double(w), Double(w), Double(w), Double(a)] }
    return [0, 0, 0, 1]
}
func darlingColorIsSystemBackground(_ color: UIColor) -> Bool {
    let selector = NSSelectorFromString("systemBackgroundColor")
    guard UIColor.responds(to: selector), let background = UIColor.perform(selector)?.takeUnretainedValue() as? UIColor else { return false }
    return color == background
}
func darlingColorIsDynamic(_ color: UIColor) -> Bool { false }
func darlingResolveColor(_ color: UIColor, dark: Bool, increasedContrast: Bool) -> [Double] {
    darlingColorComponents(color)
}

func darlingRuntimeLog(_ subsystem: String, _ category: String) -> OSLog {
    OSLog(subsystem: subsystem, category: category)
}

// MARK: - Layout

private struct Placed {
    let node: RenderNode
    var size = CGSize.zero
    var origin = CGPoint.zero
    var firstBaseline: CGFloat = 0
    var lastBaseline: CGFloat = 0
    var children: [Placed] = []
}

private func number(_ node: RenderNode, _ key: String) -> CGFloat? {
    guard let text = node.properties[key], let value = Double(text), !value.isNaN else { return nil }
    return CGFloat(value)
}
private func alignOffset(_ alignment: Int, _ available: CGFloat, _ size: CGFloat) -> CGFloat {
    alignment == 0 ? 0 : alignment == 2 ? available - size : (available - size) / 2
}

/// The font a text node asks for. Darling's UIKit has the classic system font constructors only.
private func font(for node: RenderNode) -> UIFont {
    let size = number(node, "font-size") ?? 17
    let bold = (number(node, "font-weight") ?? 0) >= 0.23
    let design = Int(number(node, "font-design") ?? 0)
    if let name = node.properties["font-name"], !name.isEmpty, let custom = UIFont(name: name, size: size) { return custom }
    if design == 3, let mono = UIFont(name: "Courier", size: size) { return mono }
    if node.properties["font-italic"] == "true" { return UIFont.italicSystemFont(ofSize: size) }
    return bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
}
private func paint(_ node: RenderNode, _ key: String = "foreground") -> [CGFloat]? {
    guard let text = node.properties[key] else { return nil }
    let values = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard values.count == 4 else { return nil }
    return values.map { CGFloat(min(max($0, 0), 1)) }
}
private func uiColor(_ components: [CGFloat]) -> UIColor {
    UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
}

private let measuringLabel = UILabel()
/// Text sizes already measured: a layout pass measures the same text at the same width many times
/// (a stack measures its children before and after dividing its space), and UIKit's measurement
/// is slow. Keyed by everything measureText reads.
private var measuredTexts: [String: (CGSize, CGFloat, CGFloat)] = [:]
private func measureText(_ node: RenderNode, width: CGFloat) -> (CGSize, CGFloat, CGFloat) {
    var key = node.text + "\u{0}" + String(Double(width))
    for property in ["font-name", "font-size", "font-weight", "font-design", "font-italic", "font-style", "font-width",
                     "letter-spacing", "max-lines", "min-lines"] {
        key += "\u{0}" + (node.properties[property] ?? "")
    }
    if let measured = measuredTexts[key] { return measured }
    let measured = measureTextUncached(node, width: width)
    if measuredTexts.count > 20000 { measuredTexts.removeAll(keepingCapacity: true) }
    measuredTexts[key] = measured
    return measured
}
private func measureTextUncached(_ node: RenderNode, width: CGFloat) -> (CGSize, CGFloat, CGFloat) {
    let label = measuringLabel
    label.font = font(for: node)
    let maxLines = Int(number(node, "max-lines") ?? -1)
    label.numberOfLines = maxLines < 0 ? 0 : maxLines
    label.text = node.text
    let limit = width >= 0 ? width : CGFloat.greatestFiniteMagnitude
    var size = label.sizeThatFits(CGSize(width: limit, height: CGFloat.greatestFiniteMagnitude))
    size.width = ceil(size.width); size.height = ceil(size.height)
    if node.text.isEmpty { size = CGSize(width: 0, height: ceil(label.font.lineHeight)) }
    let minLines = Int(number(node, "min-lines") ?? 0)
    if minLines > 0 { size.height = max(size.height, ceil(label.font.lineHeight) * CGFloat(minLines)) }
    let ascent = ceil(label.font.ascender)
    let lastBaseline = max(ascent, size.height - ceil(-label.font.descender))
    return (size, ascent, lastBaseline)
}

private struct SizeRange { var low: CGFloat; var high: CGFloat }
private func sizeRange(_ layout: Placed, horizontal: Bool) -> SizeRange {
    let node = layout.node
    let ideal = horizontal ? layout.size.width : layout.size.height
    switch node.kind {
    case "empty": return SizeRange(low: 0, high: 0)
    case "text": return horizontal ? SizeRange(low: 0, high: ideal) : SizeRange(low: ideal, high: ideal)
    case "shape", "color", "platform", "geometry", "position": return SizeRange(low: 0, high: .infinity)
    case "image" where node.properties["image-resize"] != nil: return SizeRange(low: 0, high: .infinity)
    case "spacer":
        let axis = node.properties["axis"] ?? "both"
        return axis == "both" || axis == (horizontal ? "horizontal" : "vertical")
            ? SizeRange(low: max(0, CGFloat(node.spacing)), high: .infinity) : SizeRange(low: 0, high: 0)
    case "overlay", "background":
        return layout.children.isEmpty ? SizeRange(low: 0, high: 0)
            : sizeRange(layout.children[node.kind == "background" && layout.children.count > 1 ? 1 : 0], horizontal: horizontal)
    case "aspect", "offset": return layout.children.first.map { sizeRange($0, horizontal: horizontal) } ?? SizeRange(low: 0, high: 0)
    case "scroll":
        // Along the axes it scrolls, a scroll view takes whatever it is given.
        if (node.properties["axes"] ?? "v").contains(horizontal ? "h" : "v") { return SizeRange(low: 0, high: .infinity) }
        return layout.children.first.map { sizeRange($0, horizontal: horizontal) } ?? SizeRange(low: ideal, high: ideal)
    case "frame":
        if node.properties[horizontal ? "width" : "height"] != nil { return SizeRange(low: ideal, high: ideal) }
        return layout.children.first.map { sizeRange($0, horizontal: horizontal) } ?? SizeRange(low: ideal, high: ideal)
    case "fixed-size":
        if node.properties[horizontal ? "fix-width" : "fix-height"] == "true" { return SizeRange(low: ideal, high: ideal) }
        return layout.children.first.map { sizeRange($0, horizontal: horizontal) } ?? SizeRange(low: ideal, high: ideal)
    case "padding":
        guard let child = layout.children.first else { return SizeRange(low: ideal, high: ideal) }
        var range = sizeRange(child, horizontal: horizontal)
        let inset = (number(node, horizontal ? "leading" : "top") ?? 0) + (number(node, horizontal ? "trailing" : "bottom") ?? 0)
        range.low = max(0, range.low + inset); range.high = max(0, range.high + inset)
        return range
    case "flex-frame":
        guard let child = layout.children.first else { return SizeRange(low: ideal, high: ideal) }
        var range = sizeRange(child, horizontal: horizontal)
        let low = number(node, horizontal ? "min-width" : "min-height"), high = number(node, horizontal ? "max-width" : "max-height")
        if let low = low { range.low = low }
        if let high = high { range.high = high }
        if low != nil { range.high = max(range.low, range.high) } else { range.low = min(range.low, range.high) }
        return range
    case "hstack", "vstack", "group", "zstack":
        let sum = horizontal ? node.kind == "hstack" : node.kind != "hstack" && node.kind != "zstack"
        let gaps = sum && !layout.children.isEmpty ? CGFloat(node.spacing) * CGFloat(layout.children.count - 1) : 0
        var result = SizeRange(low: gaps, high: gaps)
        for child in layout.children {
            let range = sizeRange(child, horizontal: horizontal)
            if sum { result.low += range.low; result.high += range.high }
            else { result.low = max(result.low, range.low); result.high = max(result.high, range.high) }
        }
        return SizeRange(low: max(0, result.low), high: max(0, result.high))
    case "button" where horizontal:
        return SizeRange(low: min(ideal, node.properties["button-kind"] == "apple" ? 140 : 44), high: ideal)
    default: return SizeRange(low: ideal, high: ideal)
    }
}
private func distribute(_ children: [Placed], available: CGFloat, horizontal: Bool) -> [CGFloat] {
    let ranges = children.map { sizeRange($0, horizontal: horizontal) }
    let minimum = ranges.reduce(0) { $0 + $1.low }
    if available < minimum { return ranges.map(\.low) }
    // As in SwiftUI's stacks, the least flexible child is offered its share of the space first,
    // so that the views that can grow (spacers, frames to infinity) take what the others leave.
    var sizes = ranges.map(\.low)
    var remaining = available - minimum
    var count = ranges.count
    for index in ranges.indices.sorted(by: { ranges[$0].high - ranges[$0].low < ranges[$1].high - ranges[$1].low }) {
        let extra = min(remaining / CGFloat(count), ranges[index].high - ranges[index].low)
        sizes[index] += extra
        remaining -= extra
        count -= 1
    }
    return sizes
}

/// Layouts already measured in this layout pass, by node (its layoutID) and proposal: stacks
/// measure each child before and after dividing their space, so nested stacks would otherwise
/// measure the same views a number of times exponential in their depth.
private struct MeasureKey: Hashable { let node: Int; let width: CGFloat; let height: CGFloat }
private var measured: [MeasureKey: Placed] = [:]
private func measure(_ node: RenderNode, _ width: CGFloat, _ height: CGFloat = -1) -> Placed {
    guard node.layoutID != 0 else { return measureUncached(node, width, height) }
    let key = MeasureKey(node: node.layoutID, width: width, height: height)
    if let placed = measured[key] { return placed }
    let placed = measureUncached(node, width, height)
    measured[key] = placed
    return placed
}
/// Gives every node of a tree its own layoutID, for the measurements of one layout pass.
private func numberForLayout(_ node: inout RenderNode, _ next: inout Int) {
    next += 1
    node.layoutID = next
    for index in node.children.indices { numberForLayout(&node.children[index], &next) }
}
/// Measures a node for a proposal; a negative dimension is unspecified.
private func measureUncached(_ node: RenderNode, _ width: CGFloat, _ height: CGFloat = -1) -> Placed {
    var result = Placed(node: node)
    switch node.kind {
    case "empty":
        return result
    case "shape":
        if let shape = node.shape {
            let size = shape.size(width: Double(width), height: Double(height))
            let w = Double(size.width), h = Double(size.height)
            result.size = CGSize(width: w.isFinite ? max(0, w) : 0, height: h.isFinite ? max(0, h) : 0)
        }
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        return result
    case "flex-frame":
        guard let first = node.children.first else { return result }
        struct Dimension {
            var low, ideal, high: CGFloat?
            func proposal(_ parent: CGFloat) -> CGFloat {
                if parent < 0 && ideal == nil { return -1 }
                return min(max(parent >= 0 ? parent : ideal!, low ?? 0), high ?? .infinity)
            }
            func size(_ parent: CGFloat, _ child: CGFloat) -> CGFloat {
                if parent >= 0, let low = low, let high = high { return min(max(parent, low), high) }
                if parent < 0, let ideal = ideal { return ideal }
                if let low = low, let high = high { return min(max(child, low), high) }
                if let low = low { return max(min(parent >= 0 ? proposal(parent) : .infinity, child), low) }
                if let high = high { return min(max(parent >= 0 || ideal != nil ? proposal(parent) : -.infinity, child), high) }
                return child
            }
        }
        let horizontal = Dimension(low: number(node, "min-width"), ideal: number(node, "ideal-width"), high: number(node, "max-width"))
        let vertical = Dimension(low: number(node, "min-height"), ideal: number(node, "ideal-height"), high: number(node, "max-height"))
        var child = measure(first, horizontal.proposal(width), vertical.proposal(height))
        result.size = CGSize(width: horizontal.size(width, child.size.width), height: vertical.size(height, child.size.height))
        func placement(_ d: Dimension, _ parent: CGFloat, _ size: CGFloat) -> CGFloat {
            parent < 0 && d.ideal == nil && (d.low ?? -.infinity) < size && size < (d.high ?? .infinity) ? -1 : size
        }
        let w = placement(horizontal, width, result.size.width), h = placement(vertical, height, result.size.height)
        if w != horizontal.proposal(width) || h != vertical.proposal(height) { child = measure(first, w, h) }
        child.origin = CGPoint(x: alignOffset(node.horizontal, result.size.width, child.size.width),
            y: node.vertical >= 3 ? result.size.height - (node.vertical == 3 ? child.firstBaseline : child.lastBaseline)
                                  : alignOffset(node.vertical, result.size.height, child.size.height))
        result.firstBaseline = child.origin.y + child.firstBaseline; result.lastBaseline = child.origin.y + child.lastBaseline
        result.children = [child]
        return result
    case "geometry":
        // A GeometryReader takes what it is offered (10 points where nothing is) and lays its
        // content out at its top leading corner.
        result.size = CGSize(width: width >= 0 ? width : 10, height: height >= 0 ? height : 10)
        if let first = node.children.first { result.children = [measure(first, result.size.width, result.size.height)] }
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        return result
    case "scroll":
        // Unbounded along its axes: the content takes its ideal size there; the scroll view takes
        // what it is offered (its content's size where nothing is offered).
        guard let first = node.children.first else { return result }
        let axes = node.properties["axes"] ?? "v"
        let child = measure(first, axes.contains("h") ? -1 : width, axes.contains("v") ? -1 : height)
        result.size = CGSize(width: width >= 0 ? width : child.size.width, height: height >= 0 ? height : child.size.height)
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        result.children = [child]
        return result
    case "padding":
        guard let first = node.children.first else { return result }
        let top = number(node, "top") ?? 0, leading = number(node, "leading") ?? 0
        let bottom = number(node, "bottom") ?? 0, trailing = number(node, "trailing") ?? 0
        var child = measure(first, width >= 0 ? max(0, width - leading - trailing) : -1, height >= 0 ? max(0, height - top - bottom) : -1)
        result.size = CGSize(width: max(0, child.size.width + leading + trailing), height: max(0, child.size.height + top + bottom))
        child.origin = CGPoint(x: leading, y: top)
        result.firstBaseline = top + child.firstBaseline; result.lastBaseline = top + child.lastBaseline
        result.children = [child]
        return result
    case "overlay", "background":
        guard node.children.count == 2 else { return measureStack(node, width, height, kind: "zstack") }
        let primary = node.kind == "background" ? 1 : 0
        let base = measure(node.children[primary], width, height)
        var decoration = measure(node.children[1 - primary], base.size.width, base.size.height)
        result.size = base.size
        result.firstBaseline = base.firstBaseline; result.lastBaseline = base.lastBaseline
        decoration.origin = CGPoint(x: alignOffset(node.horizontal, base.size.width, decoration.size.width),
            y: node.vertical >= 3 ? (node.vertical == 3 ? base.firstBaseline - decoration.firstBaseline : base.lastBaseline - decoration.lastBaseline)
                                  : alignOffset(node.vertical, base.size.height, decoration.size.height))
        result.children = primary == 1 ? [decoration, base] : [base, decoration]
        return result
    case "button":
        guard let first = node.children.first else { return result }
        let apple = node.properties["button-kind"] == "apple"
        var child = measure(first, width >= 0 ? max(0, width - 24) : -1, -1)
        result.size = CGSize(width: max(apple ? 140 : 44, child.size.width + 24), height: max(apple ? 44 : 30, child.size.height + 12))
        child.origin = CGPoint(x: (result.size.width - child.size.width) / 2, y: (result.size.height - child.size.height) / 2)
        result.firstBaseline = child.origin.y + child.firstBaseline; result.lastBaseline = child.origin.y + child.lastBaseline
        result.children = [child]
        return result
    case "layout":
        guard let layout = node.layout else { return measureStack(node, width, height, kind: "zstack") }
        // The host measures an unspecified or infinite dimension at the view's ideal size.
        func dimensions(_ proposal: ProposedViewSize) -> (CGFloat, CGFloat) {
            (proposal.width.map { $0.isFinite ? max(0, $0) : -1 } ?? -1, proposal.height.map { $0.isFinite ? max(0, $0) : -1 } ?? -1)
        }
        let pass = LayoutPass { index, proposal in
            let (w, h) = dimensions(proposal)
            return measure(node.children[index], w, h).size
        }
        let subviews = pass.subviews(count: node.children.count)
        let proposal = ProposedViewSize(width: width < 0 ? nil : width, height: height < 0 ? nil : height)
        result.size = layout.sizeThatFits(proposal, subviews)
        layout.placeSubviews(CGRect(origin: .zero, size: result.size), proposal, subviews)
        result.children = node.children.indices.map { index in
            // As in SwiftUI, a subview the layout does not place is centered.
            let placement = pass.placements[index]
                ?? LayoutPlacement(position: CGPoint(x: result.size.width / 2, y: result.size.height / 2), anchor: .center, proposal: .unspecified)
            let (w, h) = dimensions(placement.proposal)
            var child = measure(node.children[index], w, h)
            child.origin = CGPoint(x: placement.position.x - placement.anchor.x * child.size.width,
                                   y: placement.position.y - placement.anchor.y * child.size.height)
            return child
        }
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        return result
    case "offset":
        guard let first = node.children.first else { return result }
        var child = measure(first, width, height)
        result.size = child.size
        child.origin = CGPoint(x: number(node, "dx") ?? 0, y: number(node, "dy") ?? 0)
        result.firstBaseline = child.firstBaseline; result.lastBaseline = child.lastBaseline
        result.children = [child]
        return result
    case "position":
        guard let first = node.children.first else { return result }
        var child = measure(first, width, height)
        result.size = CGSize(width: width >= 0 ? width : child.size.width, height: height >= 0 ? height : child.size.height)
        child.origin = CGPoint(x: (number(node, "x") ?? 0) - child.size.width / 2, y: (number(node, "y") ?? 0) - child.size.height / 2)
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        result.children = [child]
        return result
    case "fixed-size":
        guard let first = node.children.first else { return result }
        let child = measure(first, node.properties["fix-width"] == "true" ? -1 : width, node.properties["fix-height"] == "true" ? -1 : height)
        result.size = child.size
        result.firstBaseline = child.firstBaseline; result.lastBaseline = child.lastBaseline
        result.children = [child]
        return result
    case "spacer":
        let axis = node.properties["axis"] ?? "both"
        let minimum = max(0, CGFloat(node.spacing))
        result.size = CGSize(width: axis == "vertical" ? 0 : max(minimum, width), height: axis == "horizontal" ? 0 : max(minimum, height))
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        return result
    case "platform":
        let proposal: CGSize? = width >= 0 && height >= 0 ? CGSize(width: width, height: height) : nil
        if let size = node.platformSize?(proposal) {
            result.size = size
        } else {
            // As SwiftUI sizes a UIKit view: its intrinsic size where it has one (a label wraps at
            // its preferredMaxLayoutWidth), what it is offered where it has none.
            let intrinsic = node.platformView?.intrinsicContentSize ?? CGSize(width: -1, height: -1)
            result.size = CGSize(width: intrinsic.width >= 0 ? intrinsic.width : max(0, width),
                                 height: intrinsic.height >= 0 ? intrinsic.height : max(0, height))
        }
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        return result
    case "color":
        result.size = CGSize(width: width >= 0 ? width : 10, height: height >= 0 ? height : 10)
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        return result
    case "frame":
        guard let first = node.children.first else { return result }
        var child = measure(first, number(node, "width") ?? width, number(node, "height") ?? height)
        result.size = CGSize(width: number(node, "width") ?? child.size.width, height: number(node, "height") ?? child.size.height)
        child.origin = CGPoint(x: alignOffset(node.horizontal, result.size.width, child.size.width),
                               y: alignOffset(node.vertical, result.size.height, child.size.height))
        result.firstBaseline = child.origin.y + child.firstBaseline; result.lastBaseline = child.origin.y + child.lastBaseline
        result.children = [child]
        return result
    case "aspect":
        guard let first = node.children.first else { return result }
        let ideal = measure(first, -1, -1)
        var ratio = number(node, "ratio") ?? (ideal.size.height > 0 ? ideal.size.width / ideal.size.height : 1)
        if ratio <= 0 { ratio = 1 }
        var w = width, h = height
        if w < 0 && h < 0 { w = ideal.size.width; h = w / ratio }
        else if w < 0 { w = h * ratio }
        else if h < 0 { h = w / ratio }
        else if (w / h > ratio) == (node.properties["mode"] == "fit") { w = h * ratio } else { h = w / ratio }
        let child = measure(first, w, h)
        result.size = child.size
        result.firstBaseline = child.firstBaseline; result.lastBaseline = child.lastBaseline
        result.children = [child]
        return result
    case "image":
        if let image = node.image {
            result.size = image.size
            if node.properties["image-resize"] != nil {
                if width >= 0 { result.size.width = width }
                if height >= 0 { result.size.height = height }
            }
        }
        result.firstBaseline = result.size.height; result.lastBaseline = result.size.height
        return result
    case "text":
        let (size, first, last) = measureText(node, width: width)
        result.size = size
        if width >= 0 { result.size.width = min(width, result.size.width) }
        result.firstBaseline = first; result.lastBaseline = last
        return result
    default:
        return measureStack(node, width, height, kind: node.kind)
    }
}

private func measureStack(_ node: RenderNode, _ width: CGFloat, _ height: CGFloat, kind: String) -> Placed {
    var result = Placed(node: node)
    let horizontal = kind == "hstack", overlay = kind == "zstack"
    let spacing = CGFloat(node.spacing)
    let gaps = node.children.isEmpty || overlay ? 0 : spacing * CGFloat(node.children.count - 1)
    var widths: [CGFloat] = [], ideals: [Placed] = []
    if horizontal {
        ideals = node.children.map { measure($0, -1, height) }
        widths = ideals.map(\.size.width)
        if width >= 0 { widths = distribute(ideals, available: max(0, width - gaps), horizontal: true) }
    }
    for (index, childNode) in node.children.enumerated() {
        let proposal = horizontal ? (width >= 0 ? max(0, widths[index]) : -1) : width
        let child = horizontal && (width < 0 || widths[index] == ideals[index].size.width)
            ? ideals[index] : measure(childNode, proposal, horizontal || overlay ? height : -1)
        if horizontal {
            result.size.width += child.size.width; result.size.height = max(result.size.height, child.size.height)
        } else if overlay {
            result.size.width = max(result.size.width, child.size.width); result.size.height = max(result.size.height, child.size.height)
        } else {
            result.size.width = max(result.size.width, child.size.width); result.size.height += child.size.height
        }
        result.children.append(child)
    }
    if !horizontal && !overlay && height >= 0 {
        let heights = distribute(result.children, available: max(0, height - gaps), horizontal: false)
        result.size.height = 0
        for i in result.children.indices {
            if heights[i] != result.children[i].size.height { result.children[i] = measure(result.children[i].node, width, heights[i]) }
            result.size.height += result.children[i].size.height
        }
    }
    if horizontal { result.size.width = max(0, result.size.width + gaps) }
    else if !overlay { result.size.height = max(0, result.size.height + gaps) }
    var sharedBaseline: CGFloat = 0
    let baselines = (horizontal || overlay) && node.vertical >= 3
    if baselines {
        var descent: CGFloat = 0
        for child in result.children {
            let baseline = node.vertical == 3 ? child.firstBaseline : child.lastBaseline
            sharedBaseline = max(sharedBaseline, baseline); descent = max(descent, child.size.height - baseline)
        }
        result.size.height = sharedBaseline + descent
    }
    var position: CGFloat = 0
    result.firstBaseline = result.size.height
    for i in result.children.indices {
        var child = result.children[i]
        child.origin.x = horizontal ? position : alignOffset(node.horizontal, result.size.width, child.size.width)
        if baselines { child.origin.y = sharedBaseline - (node.vertical == 3 ? child.firstBaseline : child.lastBaseline) }
        else if horizontal || overlay { child.origin.y = alignOffset(node.vertical, result.size.height, child.size.height) }
        else { child.origin.y = position }
        result.firstBaseline = min(result.firstBaseline, child.origin.y + child.firstBaseline)
        result.lastBaseline = max(result.lastBaseline, child.origin.y + child.lastBaseline)
        position += (horizontal ? child.size.width : child.size.height) + spacing
        result.children[i] = child
    }
    return result
}

// MARK: - Views

/// Draws a shape node's path, filled with its paint.
@objc(DarlingSwiftUIShapeView) final class ShapeView: UIView {
    var shape: RuntimeShape?
    var fillColor: [CGFloat] = [0, 0, 0, 1]
    override func draw(_ rect: CGRect) {
        guard let shape = shape else { return }
        // UIBezierPath rather than CGPath: the CGPath methods are in CoreGraphics' Swift overlay.
        let path = UIBezierPath()
        for element in shape.path(width: Double(bounds.width), height: Double(bounds.height)).elements {
            switch element {
            case .move(let p): path.move(to: p)
            case .line(let p): path.addLine(to: p)
            case let .quadCurve(p, c): path.addQuadCurve(to: p, controlPoint: c)
            case let .curve(p, c1, c2): path.addCurve(to: p, controlPoint1: c1, controlPoint2: c2)
            case .closeSubpath: path.close()
            }
        }
        if let stroke = shape.stroke {
            path.lineWidth = stroke.lineWidth
            path.lineCapStyle = stroke.lineCap
            path.lineJoinStyle = stroke.lineJoin
            path.miterLimit = stroke.miterLimit
            if !stroke.dash.isEmpty { path.setLineDash(stroke.dash, count: stroke.dash.count, phase: stroke.dashPhase) }
            uiColor(fillColor).setStroke()
            path.stroke()
            return
        }
        path.usesEvenOddFillRule = shape.isEOFilled
        uiColor(fillColor).setFill()
        path.fill()
    }
}

/// A button node: the label's views are its subviews; a tap inside runs the graph's action.
@objc(DarlingSwiftUIButton) final class ButtonView: UIView {
    var action = ""
    var enabled = true
    private var armed = false
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if dumpTrees { fputs("SwiftUI: touch began on button \(action) (enabled \(enabled))\n", stderr) }
        armed = enabled; alpha = enabled ? 0.4 : alpha
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { armed = false; alpha = 1 }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let wasArmed = armed
        armed = false; alpha = 1
        if dumpTrees { fputs("SwiftUI: touch ended on button \(action) (armed \(wasArmed), inside \(touches.first.map { bounds.contains($0.location(in: self)) } ?? false))\n", stderr) }
        guard wasArmed, let touch = touches.first, bounds.contains(touch.location(in: self)) else { return }
        _ = action.withCString { darlingActivateButton($0) }
    }
}

/// What each GeometryReader (by node identity) does with the frame it is laid out in.
var geometryReporters: [String: (CGRect) -> Void] = [:]

private var viewKinds: [ObjectIdentifier: String] = [:]
private var viewIdentities: [ObjectIdentifier: String] = [:]

private func discard(_ view: UIView) {
    // A platform view belongs to the app's representable, which keeps or dismantles it.
    if viewKinds[ObjectIdentifier(view)] != "platform" { for child in view.subviews { discard(child) } }
    viewKinds[ObjectIdentifier(view)] = nil
    viewIdentities[ObjectIdentifier(view)] = nil
    view.removeFromSuperview()
}

/// The view of a node that only lays out others (a stack, a frame, a spacer, a clear color): as
/// in SwiftUI, a touch goes through it to whatever is below, unless it lands in one of its children.
@objc(DarlingSwiftUILayoutView) final class LayoutView: UIView {
    /// A visible color takes touches itself.
    var hittable = false
    // Darling's UIKit hit-tests with AppKit's -hitTest:, a point in the superview's coordinates.
    private static let viewHitTest = unsafeBitCast(class_getMethodImplementation(UIView.self, NSSelectorFromString("hitTest:")),
                                                   to: (@convention(c) (AnyObject, Selector, CGPoint) -> Unmanaged<AnyObject>?).self)
    @objc(hitTest:) func layoutHitTest(_ point: CGPoint) -> AnyObject? {
        let hit = LayoutView.viewHitTest(self, NSSelectorFromString("hitTest:"), point)?.takeUnretainedValue()
        return hit === self && !hittable ? nil : hit
    }
}

private func makeView(for kind: String) -> UIView {
    switch kind {
    case "text": return UILabel()
    case "image": return UIImageView()
    case "shape": return ShapeView()
    case "button": return ButtonView()
    case "scroll": return UIScrollView()
    case "platform": return UIView()
    default: return LayoutView()
    }
}

private func reconcile(_ parent: UIView, _ old: UIView?, _ layout: Placed, _ frame: CGRect, _ index: Int) -> UIView {
    let node = layout.node
    if node.kind == "platform", let platform = node.platformView {
        if let old = old, old !== platform { discard(old) }
        if platform.superview !== parent { parent.insertSubview(platform, at: index) }
        viewKinds[ObjectIdentifier(platform)] = "platform"
        viewIdentities[ObjectIdentifier(platform)] = node.identity
        platform.frame = frame.integral
        return platform
    }
    var view: UIView
    if let old = old, viewKinds[ObjectIdentifier(old)] == node.kind,
       node.identity.isEmpty || viewIdentities[ObjectIdentifier(old)] == node.identity {
        view = old
    } else {
        if let old = old { discard(old) }
        view = makeView(for: node.kind)
        viewKinds[ObjectIdentifier(view)] = node.kind
        parent.insertSubview(view, at: index)
    }
    viewIdentities[ObjectIdentifier(view)] = node.identity
    view.frame = frame.integral
    view.isOpaque = false
    view.backgroundColor = nil
    view.accessibilityLabel = node.properties["label"]
    view.accessibilityIdentifier = node.properties["identifier"]
    switch node.kind {
    case "text":
        let label = view as! UILabel
        label.font = font(for: node)
        let maxLines = Int(number(node, "max-lines") ?? -1)
        label.numberOfLines = maxLines < 0 ? 0 : maxLines
        label.textColor = paint(node).map(uiColor) ?? UIColor.black
        label.text = node.text
    case "image":
        let imageView = view as! UIImageView
        imageView.image = node.image
        imageView.contentMode = .scaleToFill
    case "shape":
        let shapeView = view as! ShapeView
        shapeView.shape = node.shape
        shapeView.fillColor = paint(node) ?? [0, 0, 0, 1]
        shapeView.setNeedsDisplay()
    case "color":
        let color = paint(node) ?? [0, 0, 0, 1]
        view.backgroundColor = uiColor(color)
        (view as? LayoutView)?.hittable = color.count > 3 && color[3] > 0
    case "button":
        let button = view as! ButtonView
        button.action = node.properties["action"] ?? ""
        button.enabled = node.properties["enabled"] != "false"
        if node.properties["button-kind"] == "apple" {
            button.backgroundColor = UIColor(white: node.properties["button-style"] == "0" ? 0 : 1, alpha: 1)
        }
    default:
        break
    }
    // A GeometryReader's frame, or that of a view with onGeometryChange, goes back to its graph,
    // which updates if it changed.
    if !node.identity.isEmpty, let report = geometryReporters[node.identity] {
        report(view.convert(view.bounds, to: nil))
    }
    // A scroll view's children live in a content view of its own, beside its indicators.
    var container = view
    if node.kind == "scroll", let scrollView = view as? UIScrollView {
        let contentSize = layout.children.first?.size ?? .zero
        if let existing = scrollView.subviews.first(where: { viewKinds[ObjectIdentifier($0)] == "scroll-content" }) {
            container = existing
        } else {
            container = LayoutView()
            viewKinds[ObjectIdentifier(container)] = "scroll-content"
            scrollView.addSubview(container)
        }
        container.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.contentSize = contentSize
        scrollView.showsVerticalScrollIndicator = node.properties["indicators"] != "false"
        scrollView.showsHorizontalScrollIndicator = node.properties["indicators"] != "false"
    }
    var oldChildren = container.subviews
    if node.kind == "text" || node.kind == "image" { oldChildren = [] }
    var used = Set<ObjectIdentifier>()
    for (i, child) in layout.children.enumerated() {
        var previous: UIView?
        if !child.node.identity.isEmpty {
            previous = oldChildren.first { viewIdentities[ObjectIdentifier($0)] == child.node.identity && !used.contains(ObjectIdentifier($0)) }
        } else if i < oldChildren.count, (viewIdentities[ObjectIdentifier(oldChildren[i])] ?? "").isEmpty,
                  !used.contains(ObjectIdentifier(oldChildren[i])) {
            previous = oldChildren[i]
        }
        if let previous = previous { used.insert(ObjectIdentifier(previous)) }
        let placed = reconcile(container, previous, child, CGRect(origin: child.origin, size: child.size), i)
        if i < container.subviews.count, container.subviews[i] !== placed { container.insertSubview(placed, at: i) }
    }
    for child in oldChildren where !used.contains(ObjectIdentifier(child)) { discard(child) }
    if node.kind == "button" { for child in view.subviews { child.isUserInteractionEnabled = false } }
    return view
}

// MARK: - Presentation

/// The root view controller's view: lays the current tree out in its safe area.
@objc(DarlingSwiftUIHostView) final class HostView: UIView {
    var tree: RenderNode?
    private var root: UIView?
    override func layoutSubviews() {
        super.layoutSubviews()
        render()
    }
    /// A touch no button took: with tree dumps on, says which views it landed in.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if dumpTrees, let touch = touches.first {
            var chain: [String] = [], view = touch.view
            while let v = view, v !== self { chain.append("\(viewKinds[ObjectIdentifier(v)] ?? String(describing: type(of: v))) \(v.frame)"); view = v.superview }
            fputs("SwiftUI: unhandled touch at \(touch.location(in: self)): \(chain.joined(separator: " < "))\n", stderr)
        }
        super.touchesBegan(touches, with: event)
    }
    func render() {
        guard var tree = tree else { return }
        var next = 0
        numberForLayout(&tree, &next)
        let outer = measured
        measured = [:]
        defer { measured = outer }
        var area = bounds
        if tree.properties["ignores-safe-area"] != "true", responds(to: NSSelectorFromString("safeAreaInsets")) {
            let insets = safeAreaInsets
            area = CGRect(x: area.minX + insets.left, y: area.minY + insets.top,
                          width: max(0, area.width - insets.left - insets.right), height: max(0, area.height - insets.top - insets.bottom))
        }
        let layout = measure(tree, area.width, area.height)
        let frame = CGRect(x: area.minX + (area.width - layout.size.width) / 2, y: area.minY + (area.height - layout.size.height) / 2,
                           width: layout.size.width, height: layout.size.height)
        root = reconcile(self, root, layout, frame, 0)
    }
    /// The size the tree takes when proposed `size` (infinite dimensions take its ideal size).
    func fittingSize(proposing size: CGSize) -> CGSize {
        guard let tree = tree else { return .zero }
        return measure(tree, size.width.isFinite ? size.width : -1, size.height.isFinite ? size.height : -1).size
    }
}

@objc(DarlingSwiftUIHostingController) final class HostViewController: UIViewController {
    override func loadView() {
        let view = HostView(frame: UIScreen.main.bounds)
        view.backgroundColor = UIColor.white
        self.view = view
    }
}

private var currentTree: RenderNode?
private var hostView: HostView?

/// With DARLING_SWIFTUI_DUMP set, each new tree is written to stderr: a debugging aid for views
/// that come out empty.
let dumpTrees = getenv("DARLING_SWIFTUI_DUMP") != nil
private var lastDump = ""
private func dump(_ node: RenderNode, _ depth: Int, _ out: inout String) {
    var line = String(repeating: "  ", count: depth) + node.kind
    if !node.text.isEmpty { line += " \"" + node.text.prefix(40) + "\"" }
    let properties = node.properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.prefix(30))" }
    if !properties.isEmpty { line += " [" + properties.joined(separator: " ") + "]" }
    if node.image != nil { line += " <image>" }
    if let view = node.platformView { line += " <\(type(of: view))>" }
    out += line + "\n"
    for child in node.children { dump(child, depth + 1, &out) }
}

/// Writes `tree` to stderr if DARLING_SWIFTUI_DUMP is set and it differs from the last one written.
func darlingDumpTree(_ tree: RenderNode, _ title: String = "SwiftUI tree") {
    guard dumpTrees else { return }
    var text = ""
    dump(tree, 0, &text)
    if text != lastDump { lastDump = text; fputs(title + ":\n" + text, stderr) }
}

func darlingSetTree(_ tree: RenderNode) {
    currentTree = tree
    darlingDumpTree(tree)
    guard let view = hostView else { return }
    view.tree = tree
    view.render()
}

func darlingUpdate() {
    hostView?.render()
}

private var forwardedDelegate: NSObject?
private var startTasksCallback: (@convention(c) () -> Void)?
private var firstEvaluation: (() -> Void)?

/// The application delegate SwiftUI installs: shows the tree in a window, then forwards the
/// launch callbacks to the app's adapted delegate, if it has one.
@objc(DarlingSwiftUIAppDelegate) final class SwiftUIAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        DarlingSwiftUIPhase(27)
        if let forwarded = forwardedDelegate as? UIApplicationDelegate,
           forwarded.responds(to: #selector(UIApplicationDelegate.application(_:willFinishLaunchingWithOptions:))) {
            DarlingSwiftUIPhase(28)
            let result = forwarded.application?(application, willFinishLaunchingWithOptions: launchOptions) ?? true
            DarlingSwiftUIPhase(29)
            return result
        }
        return true
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        DarlingSwiftUIPhase(30)
        var result = true
        if let forwarded = forwardedDelegate as? UIApplicationDelegate {
            if forwarded.responds(to: #selector(UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:))) {
                DarlingSwiftUIPhase(31)
                result = forwarded.application?(application, didFinishLaunchingWithOptions: launchOptions) ?? true
                DarlingSwiftUIPhase(32)
            } else if forwarded.responds(to: #selector(UIApplicationDelegate.applicationDidFinishLaunching(_:))) {
                DarlingSwiftUIPhase(33)
                forwarded.applicationDidFinishLaunching?(application)
                DarlingSwiftUIPhase(34)
            }
        }
        DarlingSwiftUIPhase(35)
        let window = UIWindow(frame: UIScreen.main.bounds)
        DarlingSwiftUIPhase(36)
        DarlingSwiftUIPhase(37)
        let controller = HostViewController()
        darlingHostViewController = controller
        window.rootViewController = controller
        let view = controller.view as! HostView
        hostView = view
        DarlingSwiftUIPhase(38)
        // The window is key before the first evaluation, whose appearance actions may look for it
        // (UIApplication.shared.keyWindow), as on iOS.
        window.makeKeyAndVisible()
        self.window = window
        DarlingSwiftUIPhase(39)
        firstEvaluation?()
        firstEvaluation = nil
        view.tree = currentTree
        view.setNeedsLayout()
        startTasksCallback?()
        return result
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        (forwardedDelegate as? UIApplicationDelegate)?.applicationDidBecomeActive?(application)
    }
    func applicationWillResignActive(_ application: UIApplication) {
        (forwardedDelegate as? UIApplicationDelegate)?.applicationWillResignActive?(application)
    }
    func applicationDidEnterBackground(_ application: UIApplication) {
        (forwardedDelegate as? UIApplicationDelegate)?.applicationDidEnterBackground?(application)
    }
    func applicationWillEnterForeground(_ application: UIApplication) {
        (forwardedDelegate as? UIApplicationDelegate)?.applicationWillEnterForeground?(application)
    }
    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (forwardedDelegate?.responds(to: selector) ?? false)
    }
    override func forwardingTarget(for selector: Selector!) -> Any? {
        forwardedDelegate?.responds(to: selector) == true ? forwardedDelegate : nil
    }
}

func darlingRunUIKit(delegate: NSObject?, startTasks: @escaping @convention(c) () -> Void, launched: @escaping () -> Void) -> Never {
    DarlingSwiftUIPhase(25)
    forwardedDelegate = delegate
    startTasksCallback = startTasks
    firstEvaluation = launched
    DarlingSwiftUIPhase(26)
    let code = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, "DarlingSwiftUIAppDelegate")
    exit(code)
}
