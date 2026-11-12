import SwiftUI
import CoreData
import Foundation

struct FetchedRowsView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var rows: FetchedResults<AuthoredFetchRow>
    init(entity: NSEntityDescription) {
        _rows = FetchRequest(entity: entity, sortDescriptors: [NSSortDescriptor(keyPath: \AuthoredFetchRow.moment, ascending: false)], predicate: nil, animation: nil)
    }
    var body: some View {
        VStack {
            Text("Count: \(rows.count)")
            if rows.isEmpty { Text("Empty store") }
            HStack {
                Button("Add") { AuthoredAdd(context) }
                Button("Edit") { AuthoredEdit(context) }
                Button("Delete") { AuthoredDelete(context) }
            }
            List {
                ForEach(rows, id: \.objectID) { row in Text(row.label) }
            }
        }
    }
}

struct ContextSwitcher: View {
    let first: NSManagedObjectContext
    let other: NSManagedObjectContext
    @State private var secondary = false
    var body: some View {
        NavigationStack {
            VStack {
                Button(secondary ? "Return first" : "Other context") {
                    if secondary { AuthoredReturn(first) } else { AuthoredOther(other) }
                    secondary.toggle()
                }
                if secondary {
                    Text("Other context")
                    FetchedRowsView(entity: AuthoredEntity(other)).environment(\.managedObjectContext, other)
                } else {
                    Text("First context")
                    FetchedRowsView(entity: AuthoredEntity(first)).environment(\.managedObjectContext, first)
                }
            }
        }
    }
}
struct FetchProbeApp: App {
    private let first = AuthoredContext()
    private let other = AuthoredContext()
    var body: some Scene {
        WindowGroup { ContextSwitcher(first: first, other: other) }
    }
}
@_cdecl("authored_fetch_app_main")
public func authoredFetchAppMain() { FetchProbeApp.main() }
