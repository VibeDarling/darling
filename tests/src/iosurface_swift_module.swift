import IOSurface

var failures = 0
func check(_ ok: Bool, _ what: String) {
    if !ok {
        print("FAIL: \(what)")
        failures += 1
    }
}

// Both the C type and the Objective-C class import, under their macOS Swift names.
let surfaceClass: AnyClass = IOSurface.self
check(NSStringFromClass(surfaceClass) == "IOSurface", "IOSurface class name")

func width(of surface: IOSurfaceRef) -> Int { IOSurfaceGetWidth(surface) }
func width(of surface: IOSurface) -> Int { surface.width }
check(kIOSurfaceWidth as String == "IOSurfaceWidth", "kIOSurfaceWidth")

let key: IOSurfacePropertyKey = .width
check(key == IOSurfacePropertyKey.width && key != .height, "IOSurfacePropertyKey members")

if failures == 0 {
    print("ALL PASSED")
} else {
    exit(1)
}
