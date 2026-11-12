// This file is part of Darling.
//
// Copyright (C) 2026 Darling Developers
//
// Darling is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// Colors, fonts, geometry types and the environment they travel in.

public typealias CGFloat = Double

// MARK: - Color

/// An sRGB color. Also a view that fills the space it is offered.
public struct Color: Hashable, View {
	public typealias Body = Never
	var red: Double, green: Double, blue: Double, alpha: Double

	public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
		self.red = red
		self.green = green
		self.blue = blue
		self.alpha = opacity
	}

	public init(white: Double, opacity: Double = 1) {
		self.init(red: white, green: white, blue: white, opacity: opacity)
	}

	public func opacity(_ opacity: Double) -> Color {
		Color(red: red, green: green, blue: blue, opacity: alpha * opacity)
	}

	// The iOS system colors (light appearance).
	public static let black = Color(white: 0)
	public static let white = Color(white: 1)
	public static let gray = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
	public static let red = Color(red: 1, green: 59 / 255, blue: 48 / 255)
	public static let orange = Color(red: 1, green: 149 / 255, blue: 0)
	public static let yellow = Color(red: 1, green: 204 / 255, blue: 0)
	public static let green = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
	public static let mint = Color(red: 0, green: 199 / 255, blue: 190 / 255)
	public static let teal = Color(red: 48 / 255, green: 176 / 255, blue: 199 / 255)
	public static let cyan = Color(red: 50 / 255, green: 173 / 255, blue: 230 / 255)
	public static let blue = Color(red: 0, green: 122 / 255, blue: 1)
	public static let indigo = Color(red: 88 / 255, green: 86 / 255, blue: 214 / 255)
	public static let purple = Color(red: 175 / 255, green: 82 / 255, blue: 222 / 255)
	public static let pink = Color(red: 1, green: 45 / 255, blue: 85 / 255)
	public static let brown = Color(red: 162 / 255, green: 132 / 255, blue: 94 / 255)
	public static let clear = Color(white: 0, opacity: 0)
	public static let primary = Color(white: 0)
	public static let secondary = Color(red: 60 / 255, green: 60 / 255, blue: 67 / 255, opacity: 0.6)
	public static let accentColor = Color.blue
}

extension Color: _PrimitiveView {
	func _makeNodes(_ context: ResolveContext) -> [Node] {
		let node = Node(.color)
		node.color = self
		return [node]
	}
}

// MARK: - Font

public struct Font: Hashable {
	var size: Double
	var weight: Weight
	var isItalic: Bool

	public struct Weight: Hashable {
		let value: Int
		public static let ultraLight = Weight(value: 100)
		public static let thin = Weight(value: 200)
		public static let light = Weight(value: 300)
		public static let regular = Weight(value: 400)
		public static let medium = Weight(value: 500)
		public static let semibold = Weight(value: 600)
		public static let bold = Weight(value: 700)
		public static let heavy = Weight(value: 800)
		public static let black = Weight(value: 900)
	}

	public enum Design: Hashable {
		case `default`, serif, rounded, monospaced
	}

	public enum TextStyle: CaseIterable, Hashable {
		case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2
	}

	init(size: Double, weight: Weight = .regular, italic: Bool = false) {
		self.size = size
		self.weight = weight
		self.isItalic = italic
	}

	// iOS's default (Large) Dynamic Type sizes.
	public static let largeTitle = Font(size: 34)
	public static let title = Font(size: 28)
	public static let title2 = Font(size: 22)
	public static let title3 = Font(size: 20)
	public static let headline = Font(size: 17, weight: .semibold)
	public static let subheadline = Font(size: 15)
	public static let body = Font(size: 17)
	public static let callout = Font(size: 16)
	public static let footnote = Font(size: 13)
	public static let caption = Font(size: 12)
	public static let caption2 = Font(size: 11)

	public static func system(_ style: TextStyle, design: Design = .default) -> Font {
		switch style {
		case .largeTitle: return .largeTitle
		case .title: return .title
		case .title2: return .title2
		case .title3: return .title3
		case .headline: return .headline
		case .subheadline: return .subheadline
		case .body: return .body
		case .callout: return .callout
		case .footnote: return .footnote
		case .caption: return .caption
		case .caption2: return .caption2
		}
	}

	public static func system(size: Double, weight: Weight = .regular, design: Design = .default) -> Font {
		Font(size: size, weight: weight)
	}

	public func weight(_ weight: Weight) -> Font {
		var font = self
		font.weight = weight
		return font
	}

	public func bold() -> Font { weight(.bold) }

	public func italic() -> Font {
		var font = self
		font.isItalic = true
		return font
	}
}

// MARK: - Geometry

public enum Axis: Hashable {
	case horizontal, vertical

	public struct Set: OptionSet, Hashable {
		public let rawValue: Int8
		public init(rawValue: Int8) { self.rawValue = rawValue }
		public static let horizontal = Set(rawValue: 1)
		public static let vertical = Set(rawValue: 2)
	}
}

public struct CGPoint: Hashable {
	public var x: Double, y: Double
	public init(x: Double, y: Double) { self.x = x; self.y = y }
	public static let zero = CGPoint(x: 0, y: 0)
}

public struct CGSize: Hashable {
	public var width: Double, height: Double
	public init(width: Double, height: Double) { self.width = width; self.height = height }
	public static let zero = CGSize(width: 0, height: 0)
}

public struct CGRect: Hashable {
	public var origin: CGPoint, size: CGSize
	public init(x: Double, y: Double, width: Double, height: Double) {
		origin = CGPoint(x: x, y: y)
		size = CGSize(width: width, height: height)
	}
}

public struct EdgeInsets: Hashable {
	public var top: Double, leading: Double, bottom: Double, trailing: Double

	public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
		self.top = top
		self.leading = leading
		self.bottom = bottom
		self.trailing = trailing
	}
}

public enum Edge: Int8, CaseIterable {
	case top, leading, bottom, trailing

	public struct Set: OptionSet, Hashable {
		public let rawValue: Int8
		public init(rawValue: Int8) { self.rawValue = rawValue }
		public init(_ edge: Edge) { self.init(rawValue: 1 << edge.rawValue) }
		public static let top = Set(.top)
		public static let leading = Set(.leading)
		public static let bottom = Set(.bottom)
		public static let trailing = Set(.trailing)
		public static let horizontal: Set = [.leading, .trailing]
		public static let vertical: Set = [.top, .bottom]
		public static let all: Set = [.top, .leading, .bottom, .trailing]
	}
}

public enum HorizontalAlignment: Hashable {
	case leading, center, trailing
}

public enum VerticalAlignment: Hashable {
	case top, center, bottom, firstTextBaseline, lastTextBaseline
}

public struct Alignment: Hashable {
	public var horizontal: HorizontalAlignment
	public var vertical: VerticalAlignment

	public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
		self.horizontal = horizontal
		self.vertical = vertical
	}

	public static let center = Alignment(horizontal: .center, vertical: .center)
	public static let leading = Alignment(horizontal: .leading, vertical: .center)
	public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
	public static let top = Alignment(horizontal: .center, vertical: .top)
	public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
	public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
	public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
	public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
	public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

public enum TextAlignment: Hashable, CaseIterable {
	case leading, center, trailing
}

// MARK: - Environment

/// What modifiers such as .font and .foregroundColor set for a whole subtree.
public struct EnvironmentValues {
	public var font: Font?
	public var foregroundColor: Color?
	public var multilineTextAlignment: TextAlignment = .leading
	public var lineLimit: Int?
	/// The color of button labels (the accent color unless set).
	public var tint: Color?
	var isButtonLabel = false

	public init() {}
}
