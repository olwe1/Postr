import Foundation
import Combine

final class PostingViewModel: ObservableObject {
    @Published var isPosting: Bool = false
    private var cancellables = Set<AnyCancellable>()

    func canPost(noteText: String) -> Bool {
        return !isPosting && !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func post(noteText: String, session: SessionService, alerts: AlertState, onSuccess: (() -> Void)? = nil) {
        guard !isPosting else { return }
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isPosting = true
        PostService.postNote(
            note: trimmed,
            nsec: session.nsec,
            relays: session.relays
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    alerts.show("Note posted successfully!", severity: .success)
                    onSuccess?()
                    self.isPosting = false
                case .failure(let error):
                    alerts.show("Error: \(error.localizedDescription)", severity: .error)
                    self.isPosting = false
                }
            }
        }
    }
}