import Foundation
import CoreData

private var authoredDiskStage: Int32 = 70
@_cdecl("authored_swift_disk_stage")
public func authoredSwiftDiskStage() -> Int32 { authoredDiskStage }

@objc(AuthoredSwiftDiskRow)
final class AuthoredSwiftDiskRow: NSManagedObject {
    @NSManaged var label: String?
    @NSManaged var enabled: Bool
    @NSManaged var sequence: Int64
    @NSManaged var ratio: Double
    @NSManaged var address: URL?
    @NSManaged var moment: Date?
    @NSManaged var folder: AuthoredSwiftDiskFolder?
}
@objc(AuthoredSwiftDiskFolder)
final class AuthoredSwiftDiskFolder: NSManagedObject {
    @NSManaged var label: String?
    @NSManaged var rows: NSSet
}
private func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
    let result = NSAttributeDescription()
    result.name = name; result.attributeType = type; result.isOptional = true
    return result
}
private func authoredDiskModel() -> NSManagedObjectModel {
    let row = NSEntityDescription(), folder = NSEntityDescription()
    row.name = "SwiftDiskRow"; row.managedObjectClassName = NSStringFromClass(AuthoredSwiftDiskRow.self)
    folder.name = "SwiftDiskFolder"; folder.managedObjectClassName = NSStringFromClass(AuthoredSwiftDiskFolder.self)
    let owner = NSRelationshipDescription(), children = NSRelationshipDescription()
    owner.name = "folder"; owner.destinationEntity = folder; owner.minCount = 0; owner.maxCount = 1; owner.isOptional = true; owner.deleteRule = .nullifyDeleteRule
    children.name = "rows"; children.destinationEntity = row; children.minCount = 0; children.maxCount = 0; children.isOptional = true; children.deleteRule = .nullifyDeleteRule
    owner.inverseRelationship = children; children.inverseRelationship = owner
    row.properties = [attribute("label", .stringAttributeType), attribute("enabled", .booleanAttributeType), attribute("sequence", .integer64AttributeType), attribute("ratio", .doubleAttributeType), attribute("address", .URIAttributeType), attribute("moment", .dateAttributeType), owner]
    folder.properties = [attribute("label", .stringAttributeType), children]
    let model = NSManagedObjectModel(); model.entities = [row, folder]
    return model
}
private func diskRows(_ context: NSManagedObjectContext) throws -> [AuthoredSwiftDiskRow] {
    let request = NSFetchRequest<AuthoredSwiftDiskRow>(entityName: "SwiftDiskRow")
    request.sortDescriptors = [NSSortDescriptor(key: "moment", ascending: false)]
    return try context.fetch(request)
}
@_cdecl("authored_swift_disk_probe")
public func authoredSwiftDiskProbe(_ modeBytes: UnsafePointer<CChar>, _ pathBytes: UnsafePointer<CChar>) -> Int32 {
    authoredDiskStage = 71
    let mode = String(cString: modeBytes), path = String(cString: pathBytes)
    let storeURL = URL(fileURLWithPath: path)
    let model = authoredDiskModel()
    authoredDiskStage = 72
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    do {
        authoredDiskStage = 73
        _ = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let expectedURL = URL(string: "https://example.invalid/swift%20disk?q=1#part")!
        let referencePath = path + ".swift-identifiers.plist"
        if mode == "create" {
            authoredDiskStage = 74
            if try !diskRows(context).isEmpty { return 10 }
            let folder = AuthoredSwiftDiskFolder(context: context)
            folder.label = "typed folder"
            let first = AuthoredSwiftDiskRow(context: context), second = AuthoredSwiftDiskRow(context: context)
            authoredDiskStage = 75
            first.label = "typed λ"; first.enabled = true; first.sequence = Int64.min + 9; first.ratio = -2.75
            first.address = expectedURL; first.moment = Date(timeIntervalSinceReferenceDate: 30)
            first.folder = folder
            second.label = nil; second.enabled = false; second.sequence = 7; second.ratio = 0.25
            second.address = nil; second.moment = Date(timeIntervalSinceReferenceDate: 10)
            second.folder = folder
            if folder.rows.count != 2 || !folder.rows.contains(first) || !folder.rows.contains(second) { return 11 }
            authoredDiskStage = 76
            try context.save()
            if context.hasChanges || first.objectID.isTemporaryID || second.objectID.isTemporaryID || folder.objectID.isTemporaryID { return 12 }
            let references = [first.objectID.uriRepresentation().absoluteString, second.objectID.uriRepresentation().absoluteString, folder.objectID.uriRepresentation().absoluteString] as NSArray
            authoredDiskStage = 77
            if !references.write(toFile: referencePath, atomically: true) { return 13 }
            return 0
        }
        authoredDiskStage = 78
        let rows = try diskRows(context)
        guard rows.count == 2, let references = NSArray(contentsOfFile: referencePath) as? [String], references.count == 3 else { return 14 }
        let first = rows[0], second = rows[1]
        guard first.label == "typed λ", first.enabled, first.sequence == Int64.min + 9, first.ratio == -2.75,
              first.address == expectedURL, first.moment == Date(timeIntervalSinceReferenceDate: 30),
              second.label == nil, !second.enabled, second.sequence == 7, second.ratio == 0.25,
              second.address == nil, second.moment == Date(timeIntervalSinceReferenceDate: 10),
              first.objectID.uriRepresentation().absoluteString == references[0], second.objectID.uriRepresentation().absoluteString == references[1] else { return 15 }
        authoredDiskStage = 79
        if mode == "changed" {
            if first.folder != nil || second.folder != nil { return 16 }
            let request = NSFetchRequest<AuthoredSwiftDiskFolder>(entityName: "SwiftDiskFolder")
            if try !context.fetch(request).isEmpty { return 17 }
            return 0
        }
        guard let folder = first.folder, second.folder === folder, folder.label == "typed folder", folder.rows.count == 2,
              folder.rows.contains(first), folder.rows.contains(second), folder.objectID.uriRepresentation().absoluteString == references[2] else { return 18 }
        if mode == "reopen" { return 0 }
        if mode != "change" { return 2 }
        authoredDiskStage = 80
        context.delete(folder)
        if first.folder != nil || second.folder != nil { return 19 }
        authoredDiskStage = 81
        try context.save()
        if context.hasChanges { return 20 }
        return 0
    } catch { return 40 }
}
