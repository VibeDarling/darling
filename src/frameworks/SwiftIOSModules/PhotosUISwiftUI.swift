// _PhotosUI_SwiftUI's picker API, with the public shape of the iOS 16 SDK's
// interface. There is no photo library, so the picker never presents and no
// item is ever chosen: photosPicker leaves its view as it is and resets the
// presentation binding, and an item made from an identifier loads as nil,
// which is what PhotosPickerItem answers for an unavailable asset.
import CoreTransferable
@_exported import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@available(iOS 16.0, *)
public struct PhotosPickerSelectionBehavior: Equatable, Hashable {
    let ordered: Bool
    public static let `default` = PhotosPickerSelectionBehavior(ordered: false)
    public static let ordered = PhotosPickerSelectionBehavior(ordered: true)
}

@available(iOS 16.0, *)
public struct PhotosPickerItem: Equatable, Hashable {
    public struct EncodingDisambiguationPolicy: Equatable, Hashable {
        let value: Int
        public static let automatic = EncodingDisambiguationPolicy(value: 0)
        public static let current = EncodingDisambiguationPolicy(value: 1)
        public static let compatible = EncodingDisambiguationPolicy(value: 2)
    }

    public let itemIdentifier: String?

    public var supportedContentTypes: [UTType] { [] }

    public init(itemIdentifier: String) {
        self.itemIdentifier = itemIdentifier
    }

    @discardableResult
    public func loadTransferable<T>(type: T.Type,
                                    completionHandler: @escaping (Result<T?, any Error>) -> Void) -> Progress
    where T: Transferable {
        let progress = Progress(totalUnitCount: 1)
        DispatchQueue.global().async {
            progress.completedUnitCount = 1
            completionHandler(.success(nil))
        }
        return progress
    }

    public func loadTransferable<T>(type: T.Type) async throws -> T? where T: Transferable {
        nil
    }
}

@available(iOS 16.0, *)
struct PickerNeverPresents: ViewModifier {
    let isPresented: Binding<Bool>

    func body(content: Content) -> some View {
        content.onChange(of: isPresented.wrappedValue) { presented in
            if presented { isPresented.wrappedValue = false }
        }
    }
}

@available(iOS 16.0, *)
extension View {
    public func photosPicker(isPresented: Binding<Bool>, selection: Binding<PhotosPickerItem?>,
                             matching filter: PHPickerFilter? = nil,
                             preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic)
        -> some View {
        modifier(PickerNeverPresents(isPresented: isPresented))
    }

    public func photosPicker(isPresented: Binding<Bool>, selection: Binding<[PhotosPickerItem]>,
                             maxSelectionCount: Int? = nil,
                             selectionBehavior: PhotosPickerSelectionBehavior = .default,
                             matching filter: PHPickerFilter? = nil,
                             preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic)
        -> some View {
        modifier(PickerNeverPresents(isPresented: isPresented))
    }
}
