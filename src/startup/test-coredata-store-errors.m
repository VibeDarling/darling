#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#include <sqlite3.h>

static NSManagedObjectModel *model(NSAttributeType type) {
    NSAttributeDescription *attribute = [NSAttributeDescription new];
    attribute.name=@"value"; attribute.attributeType=type; attribute.optional=YES;
    NSEntityDescription *entity=[NSEntityDescription new]; entity.name=@"Item"; entity.properties=@[attribute];
    NSManagedObjectModel *result=[NSManagedObjectModel new]; result.entities=@[entity];
    [entity release]; [attribute release]; return [result autorelease];
}
static NSPersistentStore *openStore(NSManagedObjectModel *schema, NSString *path, NSDictionary *options, NSString *configuration, NSError **error) {
    NSPersistentStoreCoordinator *coordinator=[[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:schema] autorelease];
    NSPersistentStore *store=[coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:configuration URL:[NSURL fileURLWithPath:path] options:options error:error];
    if (!store && coordinator.persistentStores.count) [NSException raise:NSInternalInconsistencyException format:@"Failed load added store"];
    return store;
}
static BOOL unchanged(NSString *path, NSData *before) { return [[NSData dataWithContentsOfFile:path] isEqual:before]; }
static int run(NSString *root) {
    NSFileManager *manager=NSFileManager.defaultManager;
    if (![manager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL]) return 10;
    NSString *valid=[root stringByAppendingPathComponent:@"valid.sqlite"], *missing=[root stringByAppendingPathComponent:@"missing.sqlite"], *corrupt=[root stringByAppendingPathComponent:@"corrupt.sqlite"], *foreign=[root stringByAppendingPathComponent:@"foreign.sqlite"];
    NSError *error=nil;
    if (openStore(model(NSStringAttributeType),missing,@{NSReadOnlyPersistentStoreOption:@YES},nil,&error) || !error || [manager fileExistsAtPath:missing]) return 11;
    NSData *garbage=[@"authored non-database bytes, preserve exactly\n" dataUsingEncoding:NSUTF8StringEncoding];
    if (![garbage writeToFile:corrupt atomically:YES]) return 12;
    error=nil; if (openStore(model(NSStringAttributeType),corrupt,nil,nil,&error) || !error || !unchanged(corrupt,garbage)) return 13;
    if (openStore(model(NSStringAttributeType),corrupt,nil,nil,NULL) || !unchanged(corrupt,garbage)) return 14;
    sqlite3 *database=NULL;
    if (sqlite3_open(foreign.fileSystemRepresentation,&database) != SQLITE_OK || sqlite3_exec(database,"CREATE TABLE authored_foreign(value TEXT); INSERT INTO authored_foreign VALUES('keep')",NULL,NULL,NULL) != SQLITE_OK) { sqlite3_close(database); return 15; }
    sqlite3_close(database);
    NSData *foreignBefore=[NSData dataWithContentsOfFile:foreign]; [foreignBefore writeToFile:[foreign stringByAppendingString:@".before"] atomically:YES];
    error=nil; if (openStore(model(NSStringAttributeType),foreign,nil,nil,&error) || !error || !unchanged(foreign,foreignBefore)) return 16;
    error=nil; if (!openStore(model(NSStringAttributeType),valid,nil,nil,&error) || error) return 17;
    NSData *validBefore=[NSData dataWithContentsOfFile:valid]; [validBefore writeToFile:[valid stringByAppendingString:@".before"] atomically:YES];
    error=nil; if (openStore(model(NSInteger64AttributeType),valid,nil,nil,&error) || !error || !unchanged(valid,validBefore)) return 18;
    NSString *unsupported=[root stringByAppendingPathComponent:@"unsupported.sqlite"];
    error=nil; if (openStore(model(NSDecimalAttributeType),unsupported,nil,nil,&error) || !error || [manager fileExistsAtPath:unsupported]) return 19;
    error=nil; if (openStore(model(NSStringAttributeType),valid,nil,@"missing configuration",&error) || !error || !unchanged(valid,validBefore)) return 20;
    error=nil; if (openStore(model(NSStringAttributeType),root,nil,nil,&error) || !error) return 21;
    [garbage writeToFile:[corrupt stringByAppendingString:@".before"] atomically:YES];
    return 0;
}
int main(int argc,const char **argv) {
    @autoreleasepool {
        if (argc != 2) return 2;
        @try { return run([NSString stringWithUTF8String:argv[1]]); }
        @catch (id exception) { return 90; }
    }
}
