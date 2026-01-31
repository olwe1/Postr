import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
class UploadViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadedFiles: [UploadedFile] = []
    @Published var errorMessage: String?

    func selectAndUploadFiles(
        servers: [String],
        nsec: String,
        uploadToAll: Bool,
        onURLReady: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]

        panel.begin { [weak self] response in
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }

            guard let self = self, response == .OK else { return }

            let urls = panel.urls
            guard !urls.isEmpty else { return }

            var filesToUpload: [(data: Data, mimeType: String, filename: String)] = []
            for url in urls {
                guard let data = try? Data(contentsOf: url) else { continue }
                let mimeType = self.getMimeType(for: url)
                let filename = url.lastPathComponent
                filesToUpload.append((data: data, mimeType: mimeType, filename: filename))
            }

            guard !filesToUpload.isEmpty else { return }

            Task { @MainActor in
                await self.uploadFiles(
                    filesToUpload,
                    servers: servers,
                    nsec: nsec,
                    uploadToAll: uploadToAll,
                    onURLReady: onURLReady,
                    onError: onError
                )
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func uploadFiles(
        _ files: [(data: Data, mimeType: String, filename: String)],
        servers: [String],
        nsec: String,
        uploadToAll: Bool,
        onURLReady: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) async {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil

        let totalFiles = files.count
        var failedFileNames: [String] = []

        for (index, file) in files.enumerated() {
            do {
                let uploaded = try await BlossomService.uploadToAllServers(
                    fileData: file.data,
                    mimeType: file.mimeType,
                    filename: file.filename,
                    servers: servers,
                    nsec: nsec,
                    uploadToAll: uploadToAll,
                    onProgress: { [weak self] fileProgress in
                        let base = Double(index) / Double(totalFiles)
                        let contribution = fileProgress / Double(totalFiles)
                        Task { @MainActor in
                            self?.uploadProgress = base + contribution
                        }
                    }
                )

                uploadedFiles.append(uploaded)
                onURLReady(uploaded.url)

            } catch {
                failedFileNames.append(file.filename)
                print("Upload failed for \(file.filename): \(error)")
            }
        }

        isUploading = false
        uploadProgress = 0.0

        if !failedFileNames.isEmpty {
            let message = "Failed: \(failedFileNames.joined(separator: ", "))"
            errorMessage = message
            onError(message)
        }
    }

    private func getMimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }

    func clearAll() {
        uploadedFiles.removeAll()
        errorMessage = nil
    }

    func generateImetaTags() -> [[String]] {
        uploadedFiles.map { file in
            var tag = [
                "imeta",
                "url \(file.url)",
                "x \(file.sha256)",
                "m \(file.mimeType)",
                "size \(file.size)",
            ]
            if let dim = file.dimensions {
                tag.append("dim \(dim)")
            }
            return tag
        }
    }
}
