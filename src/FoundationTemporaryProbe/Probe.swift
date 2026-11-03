import Foundation
@_cdecl("authored_temporary_probe")
public func authoredTemporaryProbe() -> Int32 {
    AuthoredTemporaryStage(0)
    let standard = NSTemporaryDirectory()
    guard !standard.isEmpty else { return 20 }
    let expected = URL(fileURLWithPath: standard, isDirectory: true)
    guard expected.isFileURL else { return 21 }
    AuthoredTemporaryStage(1)
    AuthoredTemporaryStage(2)
    let actual = FileManager.default.temporaryDirectory
    AuthoredTemporaryStage(3)
    guard actual.isFileURL, actual == expected else { return 22 }
    return 0
}
