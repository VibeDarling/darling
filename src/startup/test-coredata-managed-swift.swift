import Foundation
import CoreData

private var authoredStage: Int32 = 50
@_cdecl("authored_swift_managed_stage")
public func authoredSwiftManagedStage() -> Int32 { authoredStage }

@objc(AuthoredSwiftRecord)
final class AuthoredSwiftRecord: NSManagedObject {
    @NSManaged var label: String?
    @NSManaged var enabled: Bool
    @NSManaged var sequence: Int64
    @NSManaged var ratio: Double
}

@_cdecl("authored_swift_managed_probe")
public func authoredSwiftManagedProbe() -> Int32 {
    authoredStage = 51
    let entity = NSEntityDescription()
    authoredStage = 52
    entity.name = "SwiftRecord"
    entity.managedObjectClassName = NSStringFromClass(AuthoredSwiftRecord.self)
    let names = ["label", "enabled", "sequence", "ratio"]
    let types: [NSAttributeType] = [.stringAttributeType, .booleanAttributeType, .integer64AttributeType, .doubleAttributeType]
    authoredStage = 53
    entity.properties = zip(names, types).map { name, type in
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true
        return attribute
    }
    authoredStage = 54
    let model = NSManagedObjectModel()
    model.entities = [entity]
    authoredStage = 55
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    authoredStage = 56
    do {
        _ = try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
    } catch { return 42 }
    authoredStage = 57
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    authoredStage = 58
    context.persistentStoreCoordinator = coordinator
    authoredStage = 59
    let record = NSEntityDescription.insertNewObject(forEntityName: "SwiftRecord", into: context) as! AuthoredSwiftRecord
    authoredStage = 60
    record.label = "swift λ"
    authoredStage = 61
    record.enabled = true
    authoredStage = 62
    record.sequence = Int64.min + 9
    authoredStage = 63
    record.ratio = -2.75
    authoredStage = 64
    if record.label != "swift λ" || !record.enabled || record.sequence != Int64.min + 9 || record.ratio != -2.75 { return 43 }
    return 0
}
