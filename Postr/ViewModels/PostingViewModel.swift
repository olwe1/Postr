import Foundation
import NostrSDK

final class PostingViewModel: ObservableObject {
    @Published var isPosting: Bool = false

    func canPost(noteText: String) -> Bool {
        !isPosting && !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func post(
        noteText: String,
        imetaTags: [[String]] = [],
        session: SessionService,
        alerts: AlertState,
        onSuccess: (() -> Void)? = nil
    ) {
        guard !isPosting else { return }
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isPosting = true

        Task { @MainActor in
            do {
                guard let client = session.client else {
                    throw URLError(.badServerResponse)
                }

                let secretKey = try SecretKey.parse(secretKey: session.nsec)
                let keys = Keys(secretKey: secretKey)

                var builder = EventBuilder.textNote(content: trimmed)
                if !imetaTags.isEmpty {
                    let tags: [Tag] = try imetaTags.map { try Tag.parse(data: $0) }
                    builder = builder.tags(tags: tags)
                }

                let unsignedEvent = builder.build(publicKey: keys.publicKey())
                let event = try unsignedEvent.signWithKeys(keys: keys)

                await client.connect()
                await client.waitForConnection(timeout: 15)
                _ = try await client.sendEvent(event: event)
                await client.disconnect()

                alerts.show("Note posted successfully!", severity: .success)
                onSuccess?()
            } catch {
                alerts.show("Error: \(error.localizedDescription)", severity: .error)
            }
            isPosting = false
        }
    }
}
