import Foundation

struct UploadedFile: Identifiable {
    let id = UUID()
    let url: String
    let sha256: String
    let mimeType: String
    let size: Int64
    let dimensions: String?
    let originalFilename: String
}

struct BlobDescriptor: Codable {
    let url: String
    let sha256: String
    let size: Int64
    let type: String
    let uploaded: Int64
}
