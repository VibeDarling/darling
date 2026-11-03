import Foundation

@objc final class SortProbeRow: NSObject {
    @objc dynamic var moment: Date
    init(_ time: TimeInterval) { moment = Date(timeIntervalSince1970: time); super.init() }
}
private struct NonKVC { var number: Int }
@_cdecl("authored_sort_probe")
public func authoredSortProbe(_ invalid: Int32) -> Int32 {
    if invalid != 0 {
        _ = NSSortDescriptor(keyPath: \NonKVC.number, ascending: true)
        return 81
    }
    let path = \SortProbeRow.moment
    let reverse = NSSortDescriptor(keyPath: path, ascending: false)
    guard reverse.key == "moment", !reverse.ascending, reverse.keyPath == path else { return 11 }
    let early = SortProbeRow(10), late = SortProbeRow(20)
    guard reverse.compare(late, to: early) == .orderedAscending,
          reverse.compare(early, to: late) == .orderedDescending,
          reverse.compare(early, to: early) == .orderedSame else { return 12 }
    let forward = NSSortDescriptor(keyPath: path, ascending: true)
    guard forward.compare(late, to: early) == .orderedDescending else { return 13 }
    let collection = NSArray(array: [early, late])
    guard let reversed = collection.sortedArray(using: [reverse]) as? [SortProbeRow],
          reversed.count == 2, reversed[0] === late, reversed[1] === early,
          let ordered = collection.sortedArray(using: [forward]) as? [SortProbeRow],
          ordered.count == 2, ordered[0] === early, ordered[1] === late else { return 16 }
    let string = NSSortDescriptor(key: "moment", ascending: false)
    guard reverse.compare(late, to: early) == string.compare(late, to: early) else { return 14 }
    let custom = NSSortDescriptor(keyPath: path, ascending: false) { left, right in
        (left as! NSDate).compare(right as! Date)
    }
    guard custom.keyPath == path, custom.compare(late, to: early) == .orderedAscending else { return 15 }
    return 0
}
