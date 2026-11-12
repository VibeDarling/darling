import Foundation
final class AuthoredSessionDelegate: NSObject, URLSessionDataDelegate {}
@_cdecl("authored_session_probe")
public func authoredSessionProbe(_ nilCache: Int32) -> Int32 {
    AuthoredSessionStage(0)
    let configuration = URLSessionConfiguration.default
    if nilCache != 0 { configuration.urlCache = nil }
    let expectedCache = configuration.urlCache
    guard (nilCache == 0 && expectedCache != nil) || (nilCache != 0 && expectedCache == nil) else { return 20 }
    AuthoredSessionStage(1)
    let delegate = AuthoredSessionDelegate()
    AuthoredSessionStage(2)
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    AuthoredSessionStage(3)
    AuthoredSessionStage(4)
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
    AuthoredSessionStage(5)
    AuthoredSessionStage(6)
    guard session.delegate === delegate, session.delegateQueue === queue,
          (session.configuration.urlCache == nil) == (expectedCache == nil) else { return 21 }
    AuthoredSessionStage(7)
    AuthoredSessionStage(8)
    session.sessionDescription = "Authored session"
    guard session.sessionDescription == "Authored session" else { return 22 }
    AuthoredSessionStage(9)
    AuthoredSessionStage(10)
    session.invalidateAndCancel()
    AuthoredSessionStage(11)
    withExtendedLifetime((delegate, queue, session)) {}
    return 0
}
