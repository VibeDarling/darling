import Foundation
import CoreData
@objc(AuthoredSwiftFetchRow)
final class AuthoredSwiftFetchRow: NSManagedObject {
    @NSManaged var label: String?
    @NSManaged var rank: Int64
}
private var authoredFetchStage: Int32 = 50
@_cdecl("authored_swift_fetch_stage")
public func authoredSwiftFetchStage() -> Int32 { authoredFetchStage }
@_cdecl("authored_swift_fetch_probe")
public func authoredSwiftFetchProbe() -> Int32 {
    authoredFetchStage=50
    let label=NSAttributeDescription(), rank=NSAttributeDescription()
    label.name="label"; label.attributeType = .stringAttributeType; label.isOptional=true
    rank.name="rank"; rank.attributeType = .integer64AttributeType; rank.isOptional=true
    let entity=NSEntityDescription(); entity.name="SwiftFetchRow"; entity.managedObjectClassName=NSStringFromClass(AuthoredSwiftFetchRow.self); entity.properties=[label,rank]
    let model=NSManagedObjectModel(); model.entities=[entity]
    authoredFetchStage=51
    let coordinator=NSPersistentStoreCoordinator(managedObjectModel:model)
    do {
        authoredFetchStage=52
        _ = try coordinator.addPersistentStore(ofType:NSInMemoryStoreType, configurationName:nil, at:nil)
        authoredFetchStage=53
        let context=NSManagedObjectContext(concurrencyType:.mainQueueConcurrencyType); context.persistentStoreCoordinator=coordinator
        authoredFetchStage=54
        let request=NSFetchRequest<AuthoredSwiftFetchRow>(entityName:"SwiftFetchRow")
        authoredFetchStage=55
        request.sortDescriptors=[NSSortDescriptor(key:"rank",ascending:false)]
        authoredFetchStage=56
        if try !context.fetch(request).isEmpty { return 10 }
        authoredFetchStage=57
        let first=AuthoredSwiftFetchRow(context:context), second=AuthoredSwiftFetchRow(context:context)
        first.label="first"; first.rank=1; second.label="second"; second.rank=2
        authoredFetchStage=58
        let inserted=try context.fetch(request)
        if inserted.count != 2 || inserted[0] !== second || inserted[1] !== first { return 11 }
        first.label="updated"; first.rank=3
        authoredFetchStage=59
        let updated=try context.fetch(request)
        if updated.count != 2 || updated[0] !== first || updated[0].label != "updated" { return 12 }
        context.delete(second)
        authoredFetchStage=60
        let deleted=try context.fetch(request)
        if deleted.count != 1 || deleted[0] !== first { return 13 }
        authoredFetchStage=61
        let failing=AuthoredFailingFetchContext(concurrencyType:.mainQueueConcurrencyType)
        do {
            authoredFetchStage=62
            _ = try failing.fetch(request)
            return 14
        } catch {
            let value=error as NSError
            if value.domain != "invalid.example.AuthoredFetch" || value.code != 731 { return 15 }
        }
        authoredFetchStage=63
        let successful=AuthoredSuccessWithErrorFetchContext(concurrencyType:.mainQueueConcurrencyType)
        authoredFetchStage=64
        if try !successful.fetch(request).isEmpty { return 16 }
        return 0
    } catch { return authoredFetchStage }
}
