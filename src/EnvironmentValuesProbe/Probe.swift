import SwiftUI
import CoreData
import Foundation

@inline(never) private func write<Value>(_ path: WritableKeyPath<EnvironmentValues, Value>,
                                         into values: inout EnvironmentValues, value: Value) {
    values[keyPath: path] = value
}
@_cdecl("authored_environment_probe")
public func authoredEnvironmentProbe(_ mode: Int32) -> Int32 {
    let first = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    let second = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    var values = EnvironmentValues()
    if mode == 0 {
        values.managedObjectContext = first
        return values.managedObjectContext === first ? 0 : 11
    }
    if mode == 2 { values.managedObjectContext = first }
    write(\.managedObjectContext, into: &values, value: second)
    return values.managedObjectContext === second ? 0 : 12
}
