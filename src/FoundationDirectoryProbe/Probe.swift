import Foundation
@_cdecl("authored_directory_probe")
public func authoredDirectoryProbe() -> Int32 {
    AuthoredDirectoryStage(0)
    guard let expected = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
          expected.isFileURL else { return 21 }
    AuthoredDirectoryStage(1)
    AuthoredDirectoryStage(2)
    let actual = URL.documentsDirectory
    AuthoredDirectoryStage(3)
    guard actual.isFileURL, actual == expected else { return 22 }
    return 0
}
