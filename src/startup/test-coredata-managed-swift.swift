import Foundation
import CoreData

@objc(AuthoredSwiftRecord)
final class AuthoredSwiftRecord: NSManagedObject {
    @NSManaged var label: String?
    @NSManaged var enabled: Bool
    @NSManaged var sequence: Int64
    @NSManaged var ratio: Double
}

@_cdecl("authored_swift_managed_probe")
public func authoredSwiftManagedProbe() -> Int32 {
    let entity = NSEntityDescription()
    entity.name = "SwiftRecord"
    entity.managedObjectClassName = NSStringFromClass(AuthoredSwiftRecord.self)
    let names = ["label", "enabled", "sequence", "ratio"]
    let types: [NSAttributeType] = [.stringAttributeType, .booleanAttributeType, .integer64AttributeType, .doubleAttributeType]
    entity.properties = zip(names, types).map { name, type in
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true
        return attribute
    }
    let model = NSManagedObjectModel()
    model.entities = [entity]
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    do {
        _ = try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
    } catch { return 42 }
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    let record = NSEntityDescription.insertNewObject(forEntityName: "SwiftRecord", into: context) as! AuthoredSwiftRecord
    record.label = "swift λ"
    record.enabled = true
    record.sequence = Int64.min + 9
    record.ratio = -2.75
    if record.label != "swift λ" || !record.enabled || record.sequence != Int64.min + 9 || record.ratio != -2.75 { return 43 }
    return 0
}
