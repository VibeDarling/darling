import CoreFoundation

extension Path {
    @frozen public enum Element: Equatable {
        case move(to: CGPoint), line(to: CGPoint)
        case quadCurve(to: CGPoint, control: CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
        case closeSubpath
    }
    public init(_ callback: (inout Path) -> ()) { self.init(); callback(&self) }
    public init(roundedRect rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .circular) {
        storage = .roundedRect(FixedRoundedRect(rect: rect, corner: cornerSize, style: style))
    }
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {
        self.init(roundedRect: rect, cornerSize: .init(width: cornerRadius, height: cornerRadius), style: style)
    }
    var elements: [Element] {
        switch storage {
        case .empty: return []
        case .path(let box): return box.elements
        case .rect(let rect):
            guard rect.width != 0 && rect.height != 0 else { return [] }
            return [.move(to: .init(x: rect.minX, y: rect.minY)), .line(to: .init(x: rect.maxX, y: rect.minY)), .line(to: .init(x: rect.maxX, y: rect.maxY)), .line(to: .init(x: rect.minX, y: rect.maxY)), .closeSubpath]
        case .ellipse(let rect): return roundedElements(rect, corner: .init(width: abs(rect.width) / 2, height: abs(rect.height) / 2), style: .circular)
        case .roundedRect(let rounded): return roundedElements(rounded.rect, corner: rounded.corner, style: rounded.style)
        default: fatalError("SwiftUI: stroked/trimmed path expansion is unsupported")
        }
    }
    private mutating func append(_ element: Element) {
        // PathBox is reference storage in the SDK's frozen enum. A new box keeps
        // mutations independent of other Path values and SDK-inlined copies.
        var result = elements; result.append(element); storage = .path(PathBox(result))
    }
    public mutating func move(to p: CGPoint) { append(.move(to: p)) }
    public mutating func addLine(to p: CGPoint) { if currentPoint == nil { move(to: .zero) }; append(.line(to: p)) }
    public mutating func addQuadCurve(to p: CGPoint, control cp: CGPoint) { if currentPoint == nil { move(to: .zero) }; append(.quadCurve(to: p, control: cp)) }
    public mutating func addCurve(to p: CGPoint, control1 cp1: CGPoint, control2 cp2: CGPoint) { if currentPoint == nil { move(to: .zero) }; append(.curve(to: p, control1: cp1, control2: cp2)) }
    public mutating func closeSubpath() { if currentPoint != nil { append(.closeSubpath) } }
    public var currentPoint: CGPoint? {
        var current: CGPoint?, start: CGPoint?
        for element in elements {
            switch element {
            case .move(let p): current = p; start = p
            case .line(let p), .quadCurve(let p, _), .curve(let p, _, _): current = p
            case .closeSubpath: current = start
            }
        }
        return current
    }
    public var isEmpty: Bool { elements.isEmpty }
    public func forEach(_ body: (Element) -> Void) { for element in elements { body(element) } }
    public var boundingRect: CGRect {
        var points: [CGPoint] = [], current = CGPoint.zero, start = CGPoint.zero
        for element in elements {
            switch element {
            case .move(let p): current = p; start = p; points.append(p)
            case .line(let p): current = p; points.append(p)
            case let .quadCurve(p, c):
                let c1 = CGPoint(x: current.x + (c.x - current.x) * 2 / 3, y: current.y + (c.y - current.y) * 2 / 3)
                let c2 = CGPoint(x: p.x + (c.x - p.x) * 2 / 3, y: p.y + (c.y - p.y) * 2 / 3)
                points += curveBounds(current, c1, c2, p); current = p
            case let .curve(p, c1, c2): points += curveBounds(current, c1, c2, p); current = p
            case .closeSubpath: current = start
            }
        }
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points { minX = min(minX, p.x); minY = min(minY, p.y); maxX = max(maxX, p.x); maxY = max(maxY, p.y) }
        return .init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    public mutating func addRect(_ rect: CGRect, transform: CGAffineTransform = .identity) { addPath(Path(rect), transform: transform) }
    public mutating func addEllipse(in rect: CGRect, transform: CGAffineTransform = .identity) { addPath(Path(ellipseIn: rect), transform: transform) }
    public mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .circular, transform: CGAffineTransform = .identity) { addPath(Path(roundedRect: rect, cornerSize: cornerSize, style: style), transform: transform) }
    public mutating func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) { for rect in rects { addRect(rect, transform: transform) } }
    public mutating func addLines(_ lines: [CGPoint]) { guard let first = lines.first else { return }; move(to: first); for p in lines.dropFirst() { addLine(to: p) } }
    public mutating func addPath(_ path: Path, transform: CGAffineTransform = .identity) {
        storage = .path(PathBox(elements + path.applying(transform).elements))
    }
    public func applying(_ transform: CGAffineTransform) -> Path {
        func apply(_ p: CGPoint) -> CGPoint { .init(x: p.x * transform.a + p.y * transform.c + transform.tx, y: p.x * transform.b + p.y * transform.d + transform.ty) }
        var result = Path()
        result.storage = .path(PathBox(elements.map { element in
            switch element {
            case .move(let p): return .move(to: apply(p))
            case .line(let p): return .line(to: apply(p))
            case let .quadCurve(p, c): return .quadCurve(to: apply(p), control: apply(c))
            case let .curve(p, c1, c2): return .curve(to: apply(p), control1: apply(c1), control2: apply(c2))
            case .closeSubpath: return .closeSubpath
            }
        }))
        return result
    }
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> Path { applying(CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: dx, ty: dy)) }
}
private func curveBounds(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> [CGPoint] {
    func roots(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat) -> [CGFloat] {
        let a = -p0 + 3 * p1 - 3 * p2 + p3, b = 2 * (p0 - 2 * p1 + p2), c = p1 - p0
        if abs(a) < 1e-12 { return abs(b) < 1e-12 ? [] : [-c / b] }
        let d = b * b - 4 * a * c
        if d < 0 { return [] }
        return [(-b + d.squareRoot()) / (2 * a), (-b - d.squareRoot()) / (2 * a)]
    }
    let ts = roots(p0.x, p1.x, p2.x, p3.x) + roots(p0.y, p1.y, p2.y, p3.y)
    return [p0, p3] + ts.filter { $0 > 0 && $0 < 1 }.map { t in
        let u = 1 - t
        return CGPoint(x: u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x, y: u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y)
    }
}
private func roundedElements(_ r: CGRect, corner: CGSize, style: RoundedCornerStyle) -> [Path.Element] {
    guard r.width != 0 && r.height != 0 else { return [] }
    let x0 = r.minX, x1 = r.maxX, y0 = r.minY, y1 = r.maxY
    let rx = min(max(corner.width, 0), (x1 - x0) / 2), ry = min(max(corner.height, 0), (y1 - y0) / 2)
    // Circular corners use the standard quarter-ellipse cubic. Continuous
    // corners currently use a smooth cubic with zero endpoint curvature; this
    // preserves the distinct style but is an approximation of Apple's curve.
    let k: CGFloat = style == .circular ? 0.5522847498307936 : 1
    return [.move(to: .init(x: x0 + rx, y: y0)), .line(to: .init(x: x1 - rx, y: y0)),
        .curve(to: .init(x: x1, y: y0 + ry), control1: .init(x: x1 - rx + rx*k, y: y0), control2: .init(x: x1, y: y0 + ry - ry*k)),
        .line(to: .init(x: x1, y: y1 - ry)),
        .curve(to: .init(x: x1 - rx, y: y1), control1: .init(x: x1, y: y1 - ry + ry*k), control2: .init(x: x1 - rx + rx*k, y: y1)),
        .line(to: .init(x: x0 + rx, y: y1)),
        .curve(to: .init(x: x0, y: y1 - ry), control1: .init(x: x0 + rx - rx*k, y: y1), control2: .init(x: x0, y: y1 - ry + ry*k)),
        .line(to: .init(x: x0, y: y0 + ry)),
        .curve(to: .init(x: x0 + rx, y: y0), control1: .init(x: x0, y: y0 + ry - ry*k), control2: .init(x: x0 + rx - rx*k, y: y0)), .closeSubpath]
}
