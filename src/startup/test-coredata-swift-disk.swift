import Foundation
import CoreData

@_silgen_name("authored_swift_disk_checkpoint")
private func authoredDiskCheckpoint(_ value: Int32)
private var authoredDiskStage: Int32 = 70
private func stage(_ value: Int32) { authoredDiskStage = value; authoredDiskCheckpoint(value) }
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
    stage(118)
    let request = NSFetchRequest<AuthoredSwiftDiskRow>(entityName: "SwiftDiskRow")
    stage(119)
    let descriptor = NSSortDescriptor(key: "moment", ascending: false)
    stage(120)
    request.sortDescriptors = [descriptor]
    stage(121)
    let result = try context.fetch(request)
    stage(122)
    return result
}
@_cdecl("authored_swift_disk_probe")
public func authoredSwiftDiskProbe(_ modeBytes: UnsafePointer<CChar>, _ pathBytes: UnsafePointer<CChar>) -> Int32 {
    stage(71)
    let mode = String(cString: modeBytes), path = String(cString: pathBytes)
    let storeURL = URL(fileURLWithPath: path)
    stage(72)
    let model = authoredDiskModel()
    stage(73)
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    do {
        stage(74)
        _ = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL)
        stage(75)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        stage(76)
        context.persistentStoreCoordinator = coordinator
        stage(77)
        let expectedURL = URL(string: "https://example.invalid/swift%20disk?q=1#part")!
        let referencePath = path + ".swift-identifiers.plist"
        if mode == "create" {
            stage(78)
            if try !diskRows(context).isEmpty { return 10 }
            stage(79)
            let folder = AuthoredSwiftDiskFolder(context: context)
            stage(80)
            folder.label = "typed folder"
            stage(81)
            let first = AuthoredSwiftDiskRow(context: context)
            stage(82)
            let second = AuthoredSwiftDiskRow(context: context)
            stage(83); first.label = "typed λ"
            stage(84); first.enabled = true
            stage(85); first.sequence = Int64.min + 9
            stage(86); first.ratio = -2.75
            stage(87); first.address = expectedURL
            stage(88); first.moment = Date(timeIntervalSinceReferenceDate: 30)
            stage(89); first.folder = folder
            stage(90); second.label = nil
            stage(91); second.enabled = false
            stage(92); second.sequence = 7
            stage(93); second.ratio = 0.25
            stage(94); second.address = nil
            stage(95); second.moment = Date(timeIntervalSinceReferenceDate: 10)
            stage(96); second.folder = folder
            stage(97)
            if folder.rows.count != 2 || !folder.rows.contains(first) || !folder.rows.contains(second) { return 11 }
            stage(98); try context.save()
            stage(99)
            if context.hasChanges || first.objectID.isTemporaryID || second.objectID.isTemporaryID || folder.objectID.isTemporaryID { return 12 }
            stage(100); let firstID = first.objectID.uriRepresentation().absoluteString
            stage(101); let secondID = second.objectID.uriRepresentation().absoluteString
            stage(102); let folderID = folder.objectID.uriRepresentation().absoluteString
            stage(103); let references = [firstID, secondID, folderID] as NSArray
            stage(104)
            if !references.write(toFile: referencePath, atomically: true) { return 13 }
            return 0
        }
        stage(105)
        let rows = try diskRows(context)
        stage(106)
        guard rows.count == 2, let references = NSArray(contentsOfFile: referencePath) as? [String], references.count == 3 else { return 14 }
        let first = rows[0], second = rows[1]
        stage(107)
        guard first.label == "typed λ", first.enabled, first.sequence == Int64.min + 9, first.ratio == -2.75,
              first.address == expectedURL, first.moment == Date(timeIntervalSinceReferenceDate: 30),
              second.label == nil, !second.enabled, second.sequence == 7, second.ratio == 0.25,
              second.address == nil, second.moment == Date(timeIntervalSinceReferenceDate: 10),
              first.objectID.uriRepresentation().absoluteString == references[0], second.objectID.uriRepresentation().absoluteString == references[1] else { return 15 }
        stage(110)
        if mode == "changed" {
            stage(111)
            if first.folder != nil || second.folder != nil { return 16 }
            stage(112)
            let request = NSFetchRequest<AuthoredSwiftDiskFolder>(entityName: "SwiftDiskFolder")
            if try !context.fetch(request).isEmpty { return 17 }
            return 0
        }
        guard let folder = first.folder, second.folder === folder, folder.label == "typed folder", folder.rows.count == 2,
              folder.rows.contains(first), folder.rows.contains(second), folder.objectID.uriRepresentation().absoluteString == references[2] else { return 18 }
        if mode == "reopen" { return 0 }
        if mode != "change" { return 2 }
        stage(113)
        context.delete(folder)
        stage(114)
        if first.folder != nil || second.folder != nil { return 19 }
        stage(115)
        try context.save()
        stage(116)
        if context.hasChanges { return 20 }
        return 0
    } catch { return 40 }
}
