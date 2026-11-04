// PhotosUI's Swift PHPickerFilter, with the public shape of the iOS 16 SDK's
// interface. A filter is a predicate over asset kinds, combined with any(of:),
// all(of:) and not(_:).
@available(iOS 14.0, *)
public struct PHPickerFilter: Equatable, Hashable {
    indirect enum Term: Hashable {
        case kind(String)
        case any([Term])
        case all([Term])
        case not(Term)
    }

    let term: Term

    public static let images = PHPickerFilter(term: .kind("images"))
    public static let videos = PHPickerFilter(term: .kind("videos"))
    public static let livePhotos = PHPickerFilter(term: .kind("livePhotos"))
    @available(iOS 16.0, *)
    public static let depthEffectPhotos = PHPickerFilter(term: .kind("depthEffectPhotos"))
    @available(iOS 16.0, *)
    public static let bursts = PHPickerFilter(term: .kind("bursts"))
    @available(iOS 15.0, *)
    public static let panoramas = PHPickerFilter(term: .kind("panoramas"))
    @available(iOS 15.0, *)
    public static let screenshots = PHPickerFilter(term: .kind("screenshots"))
    @available(iOS 15.0, *)
    public static let screenRecordings = PHPickerFilter(term: .kind("screenRecordings"))
    @available(iOS 15.0, *)
    public static let slomoVideos = PHPickerFilter(term: .kind("slomoVideos"))
    @available(iOS 15.0, *)
    public static let timelapseVideos = PHPickerFilter(term: .kind("timelapseVideos"))
    @available(iOS 16.0, *)
    public static let cinematicVideos = PHPickerFilter(term: .kind("cinematicVideos"))

    public static func any(of subfilters: [PHPickerFilter]) -> PHPickerFilter {
        PHPickerFilter(term: .any(subfilters.map(\.term)))
    }

    @available(iOS 15.0, *)
    public static func all(of subfilters: [PHPickerFilter]) -> PHPickerFilter {
        PHPickerFilter(term: .all(subfilters.map(\.term)))
    }

    @available(iOS 15.0, *)
    public static func not(_ filter: PHPickerFilter) -> PHPickerFilter {
        PHPickerFilter(term: .not(filter.term))
    }
}
