import Foundation
import CoreData
@objc(AuthoredSwiftFetchRow)
final class AuthoredSwiftFetchRow: NSManagedObject {
    @NSManaged var label: String?
    @NSManaged var rank: Int64
}
@_cdecl("authored_swift_fetch_probe")
public func authoredSwiftFetchProbe() -> Int32 {
    let label=NSAttributeDescription(), rank=NSAttributeDescription()
    label.name="label"; label.attributeType = .stringAttributeType; label.isOptional=true
    rank.name="rank"; rank.attributeType = .integer64AttributeType; rank.isOptional=true
    let entity=NSEntityDescription(); entity.name="SwiftFetchRow"; entity.managedObjectClassName=NSStringFromClass(AuthoredSwiftFetchRow.self); entity.properties=[label,rank]
    let model=NSManagedObjectModel(); model.entities=[entity]
    let coordinator=NSPersistentStoreCoordinator(managedObjectModel:model)
    do {
        _ = try coordinator.addPersistentStore(ofType:NSInMemoryStoreType, configurationName:nil, at:nil)
        let context=NSManagedObjectContext(concurrencyType:.mainQueueConcurrencyType); context.persistentStoreCoordinator=coordinator
        let request=NSFetchRequest<AuthoredSwiftFetchRow>(entityName:"SwiftFetchRow")
        request.sortDescriptors=[NSSortDescriptor(key:"rank",ascending:false)]
        if try !context.fetch(request).isEmpty { return 10 }
        let first=AuthoredSwiftFetchRow(context:context), second=AuthoredSwiftFetchRow(context:context)
        first.label="first"; first.rank=1; second.label="second"; second.rank=2
        let inserted=try context.fetch(request)
        if inserted.count != 2 || inserted[0] !== second || inserted[1] !== first { return 11 }
        first.label="updated"; first.rank=3
        let updated=try context.fetch(request)
        if updated.count != 2 || updated[0] !== first || updated[0].label != "updated" { return 12 }
        context.delete(second)
        let deleted=try context.fetch(request)
        if deleted.count != 1 || deleted[0] !== first { return 13 }
        let failing=AuthoredFailingFetchContext(concurrencyType:.mainQueueConcurrencyType)
        do {
            _ = try failing.fetch(request)
            return 14
        } catch {
            let value=error as NSError
            if value.domain != "invalid.example.AuthoredFetch" || value.code != 731 { return 15 }
        }
        let successful=AuthoredSuccessWithErrorFetchContext(concurrencyType:.mainQueueConcurrencyType)
        if try !successful.fetch(request).isEmpty { return 16 }
        return 0
    } catch { return 40 }
}
