import AppKit
import CryptoKit
import Foundation
import NostrSDK

enum BlossomError: LocalizedError {
    case invalidServer
    case uploadFailed(String)
    case allServersFailed
    case noServers

    var errorDescription: String? {
        switch self {
        case .invalidServer: return "Invalid server URL"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .allServersFailed: return "All servers failed"
        case .noServers: return "No Blossom servers configured"
        }
    }
}

class BlossomService: NSObject {

    static func sha256(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func createAuthorizationHeader(sha256: String, nsec: String) throws -> String {
        let secretKey = try SecretKey.parse(secretKey: nsec)
        let keys = Keys(secretKey: secretKey)
        let expiration = UInt64(Date().timeIntervalSince1970) + 300  // 5 minutes

        let tags: [Tag] = [
            try Tag.parse(data: ["t", "upload"]),
            try Tag.parse(data: ["x", sha256]),
            try Tag.parse(data: ["expiration", String(expiration)]),
        ]
        let builder = EventBuilder(kind: Kind(kind: 24242), content: "Upload file")
            .tags(tags: tags)

        let event = try builder.signWithKeys(keys: keys)
        let eventJson = try event.asJson()

        guard let jsonData = eventJson.data(using: .utf8) else {
            throw BlossomError.uploadFailed("Failed to encode event")
        }
        let base64 = jsonData.base64EncodedString()

        return "Nostr \(base64)"
    }

    static func upload(
        fileData: Data,
        mimeType: String,
        to server: String,
        nsec: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> BlobDescriptor {
        var serverURL = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if serverURL.hasSuffix("/") {
            serverURL = String(serverURL.dropLast())
        }

        guard let url = URL(string: "\(serverURL)/upload") else {
            throw BlossomError.invalidServer
        }

        let hash = sha256(of: fileData)
        let authHeader = try createAuthorizationHeader(sha256: hash, nsec: nsec)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(fileData.count), forHTTPHeaderField: "Content-Length")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let delegate = UploadProgressDelegate(onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        let (data, response) = try await session.upload(for: request, from: fileData)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BlossomError.uploadFailed("Invalid response")
        }

        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw BlossomError.uploadFailed(errorMsg)
        }

        let descriptor = try JSONDecoder().decode(BlobDescriptor.self, from: data)
        return descriptor
    }

    static func uploadToAllServers(
        fileData: Data,
        mimeType: String,
        filename: String,
        servers: [String],
        nsec: String,
        uploadToAll: Bool,
        onProgress: @escaping (Double) -> Void
    ) async throws -> UploadedFile {
        guard !servers.isEmpty else {
            throw BlossomError.noServers
        }

        let serversToUse = uploadToAll ? servers : [servers[0]]
        var firstDescriptor: BlobDescriptor?
        var lastError: Error?

        for (index, server) in serversToUse.enumerated() {
            do {
                let descriptor = try await upload(
                    fileData: fileData,
                    mimeType: mimeType,
                    to: server,
                    nsec: nsec,
                    onProgress: { progress in
                        let serverProgress = Double(index) / Double(serversToUse.count)
                        let contribution = progress / Double(serversToUse.count)
                        onProgress(serverProgress + contribution)
                    }
                )

                if firstDescriptor == nil {
                    firstDescriptor = descriptor
                }
            } catch {
                lastError = error
                print("Upload to \(server) failed: \(error)")
            }
        }

        guard let descriptor = firstDescriptor else {
            throw lastError ?? BlossomError.allServersFailed
        }

        let dimensions = getImageDimensions(from: fileData, mimeType: mimeType)

        return UploadedFile(
            url: descriptor.url,
            sha256: descriptor.sha256,
            mimeType: mimeType,
            size: descriptor.size,
            dimensions: dimensions,
            originalFilename: filename
        )
    }

    private static func getImageDimensions(from data: Data, mimeType: String) -> String? {
        guard mimeType.hasPrefix("image/") else { return nil }
        guard let image = NSImage(data: data) else { return nil }
        let size = image.size
        return "\(Int(size.width))x\(Int(size.height))"
    }
}

class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.onProgress(progress)
        }
    }
}
