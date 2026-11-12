import Foundation
@_cdecl("authored_path_probe")
public func authoredPathProbe() -> Int32 {
    guard let url = URL(string: "https://example.invalid/a%20b/%E2%82%AC"),
          let empty = URL(string: "https://example.invalid") else { return 20 }
    AuthoredPathStage(0)
    guard url.path() == "/a%20b/%E2%82%AC" else { return 21 }
    AuthoredPathStage(1)
    AuthoredPathStage(2)
    guard url.path(percentEncoded: true) == "/a%20b/%E2%82%AC" else { return 22 }
    AuthoredPathStage(3)
    AuthoredPathStage(4)
    guard url.path(percentEncoded: false) == "/a b/€" else { return 23 }
    AuthoredPathStage(5)
    AuthoredPathStage(6)
    guard empty.path() == "" else { return 24 }
    AuthoredPathStage(7)
    return 0
}
