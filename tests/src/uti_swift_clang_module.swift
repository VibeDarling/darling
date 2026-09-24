import UniformTypeIdentifiers
let folder: UTType = .folder
let png = UTType(filenameExtension: "png")
let ref: UTTypeReference = folder as UTTypeReference
if folder.identifier == "public.folder" && png?.conforms(to: .image) == true && ref.identifier == "public.folder" {
    print("ALL PASSED")
} else {
    print("FAIL: \(folder.identifier) \(String(describing: png?.identifier))")
    exit(1)
}
