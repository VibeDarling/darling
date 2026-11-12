// This file is part of Darling.
//
// Copyright (C) 2026 Darling Developers
//
// Darling is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

internal import SwiftUIBackend

/// An app: `@main struct MyApp: App { var body: some Scene { ... } }`.
public protocol App {
	associatedtype Body: Scene
	@SceneBuilder var body: Self.Body { get }
	init()
}

extension App {
	/// What `@main` calls: runs UIApplicationMain and shows the first
	/// WindowGroup's content in a window filling the screen.
	public static func main() {
		let app = Self()
		guard let root = _rootView(of: app.body) else {
			fatalError("SwiftUI: \(Self.self).body has no WindowGroup")
		}
		AppLauncher.root = root
		let argc = CommandLine.argc
		let argv = CommandLine.unsafeArgv
		_ = SUIApplicationMain(argc, argv, { _ in AppLauncher.launch() }, nil)
	}
}

enum AppLauncher {
	static var root: ((ResolveContext) -> [Node])?
	static var renderer: Renderer?

	static func launch() {
		guard let root = root else { return }
		let renderer = Renderer(root: root)
		AppLauncher.renderer = renderer
		renderer.attach()
	}
}

// MARK: - Scenes

public protocol Scene {
	associatedtype Body: Scene
	@SceneBuilder var body: Self.Body { get }
}

extension Never: Scene {}

extension Scene where Body == Never {
	public var body: Never {
		fatalError("\(Self.self) is a primitive scene and has no body")
	}
}

protocol _PrimitiveScene {
	var _rootView: ((ResolveContext) -> [Node])? { get }
}

func _rootView<S: Scene>(of scene: S) -> ((ResolveContext) -> [Node])? {
	if let primitive = scene as? _PrimitiveScene {
		return primitive._rootView
	}
	return _rootView(of: scene.body)
}

/// The app's window and the view it shows. On a phone there is one.
public struct WindowGroup<Content: View>: Scene {
	public typealias Body = Never
	let content: Content

	public init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	public init(_ title: String, @ViewBuilder content: () -> Content) {
		self.content = content()
	}
}

extension WindowGroup: _PrimitiveScene {
	var _rootView: ((ResolveContext) -> [Node])? {
		let content = self.content
		return { _makeNodes(content, $0) }
	}
}

/// Scenes in sequence; the first that has a window is shown.
public struct _TupleScene: Scene {
	public typealias Body = Never
	let scenes: [((ResolveContext) -> [Node])?]
}

extension _TupleScene: _PrimitiveScene {
	var _rootView: ((ResolveContext) -> [Node])? {
		for scene in scenes {
			if let root = scene {
				return root
			}
		}
		return nil
	}
}

@resultBuilder
public enum SceneBuilder {
	public static func buildBlock<Content: Scene>(_ content: Content) -> Content { content }

	public static func buildBlock<C0: Scene, C1: Scene>(_ c0: C0, _ c1: C1) -> _TupleScene {
		_TupleScene(scenes: [_rootView(of: c0), _rootView(of: c1)])
	}

	public static func buildBlock<C0: Scene, C1: Scene, C2: Scene>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleScene {
		_TupleScene(scenes: [_rootView(of: c0), _rootView(of: c1), _rootView(of: c2)])
	}
}
