import Foundation

@MainActor
final class PostingViewModel: ObservableObject {
    @Published var isPosting: Bool = false

    func canPost(noteText: String) -> Bool {
        !isPosting && !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func post(
        noteText: String,
        imetaTags: [[String]] = [],
        publishingService: PublishingService,
        alerts: AlertState,
        onSuccess: (() -> Void)? = nil
    ) {
        guard !isPosting else { return }
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isPosting = true

        Task {
            do {
                try await publishingService.publishNote(text: trimmed, imetaTags: imetaTags)
                alerts.show("Note posted successfully!", severity: .success)
                onSuccess?()
            } catch {
                alerts.show("Error: \(error.localizedDescription)", severity: .error)
            }
            isPosting = false
        }
    }
}
