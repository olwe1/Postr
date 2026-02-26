import AppKit
import Foundation
import UniformTypeIdentifiers

class UploadViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadedFiles: [UploadedFile] = []
    @Published var errorMessage: String?

    @MainActor
    func selectAndUploadFiles(
        servers: [String],
        nsec: String,
        uploadToAll: Bool,
        onURLReady: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]

        panel.begin { [weak self] response in
            guard let self, response == .OK else { return }
            let urls = panel.urls
            guard !urls.isEmpty else { return }

            var filesToUpload: [(data: Data, mimeType: String, filename: String)] = []
            for url in urls {
                guard let data = try? Data(contentsOf: url) else { continue }
                let mimeType = self.mimeType(for: url)
                filesToUpload.append(
                    (data: data, mimeType: mimeType, filename: url.lastPathComponent))
            }
            guard !filesToUpload.isEmpty else { return }

            Task {
                await self.uploadFiles(
                    filesToUpload, servers: servers, nsec: nsec, uploadToAll: uploadToAll,
                    onURLReady: onURLReady, onError: onError)
                await MainActor.run { NSApp.activate(ignoringOtherApps: true) }
            }
        }
    }

    private func uploadFiles(
        _ files: [(data: Data, mimeType: String, filename: String)],
        servers: [String],
        nsec: String,
        uploadToAll: Bool,
        onURLReady: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) async {
        await MainActor.run {
            isUploading = true
            uploadProgress = 0.0
            errorMessage = nil
        }

        let totalFiles = files.count
        var failedNames: [String] = []

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
                        Task { @MainActor [weak self] in
                            self?.uploadProgress = base + contribution
                        }
                    }
                )
                await MainActor.run {
                    uploadedFiles.append(uploaded)
                }
                await onURLReady(uploaded.url)
            } catch {
                failedNames.append(file.filename)
                print("UploadViewModel: upload failed for \(file.filename): \(error)")
            }
        }

        await MainActor.run {
            isUploading = false
            uploadProgress = 0.0
        }

        if !failedNames.isEmpty {
            let message = "Failed: \(failedNames.joined(separator: ", "))"
            await MainActor.run { errorMessage = message }
            await onError(message)
        }
    }

    private func mimeType(for url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
    }

    @MainActor
    func clearAll() {
        uploadedFiles.removeAll()
        errorMessage = nil
    }

    @MainActor
    func generateImetaTags() -> [[String]] {
        uploadedFiles.map { file in
            var tag = [
                "imeta", "url \(file.url)", "x \(file.sha256)", "m \(file.mimeType)",
                "size \(file.size)",
            ]
            if let dim = file.dimensions { tag.append("dim \(dim)") }
            return tag
        }
    }
}
