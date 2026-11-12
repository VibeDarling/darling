import SwiftUI
import UIKit
import Foundation

final class AuthoredLaunchDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, willFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AuthoredDelegateStage(0)
        AuthoredDelegateStage(1)
        return true
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AuthoredDelegateStage(2)
        AuthoredDelegateStage(3)
        return true
    }
    func applicationDidBecomeActive(_ application: UIApplication) { AuthoredDelegateStage(4) }
}
struct DelegateProbeApp: App {
    @UIApplicationDelegateAdaptor(AuthoredLaunchDelegate.self) private var delegate
    var body: some Scene { WindowGroup { Text("Delegate launch OK") } }
}
@_cdecl("authored_delegate_main")
public func authoredDelegateMain() { DelegateProbeApp.main() }

@_cdecl("authored_cache_probe")
public func authoredCacheProbe() -> Int32 {
    let capacity = 150 * 1_048_576
    AuthoredDelegateStage(5)
    let cache = URLCache(memoryCapacity: 0, diskCapacity: capacity, diskPath: "authored-delegate-cache")
    AuthoredDelegateStage(6)
    guard cache.memoryCapacity == 0, cache.diskCapacity == capacity else { return 21 }
    cache.diskCapacity = 0
    guard cache.diskCapacity == 0 else { return 22 }
    AuthoredDelegateStage(7)
    AuthoredDelegateStage(8)
    let configuration = URLSessionConfiguration.default
    AuthoredDelegateStage(9)
    configuration.urlCache = nil
    guard configuration.urlCache == nil else { return 23 }
    AuthoredDelegateStage(10)
    let other = URLSessionConfiguration.default
    guard other !== configuration, other.urlCache != nil else { return 24 }
    AuthoredDelegateStage(11)
    return 0
}
