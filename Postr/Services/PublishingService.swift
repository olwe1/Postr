import Foundation
import NostrSDK

final class PublishingService: ObservableObject {
    private let account: NostrAccount

    init(account: NostrAccount) {
        self.account = account
    }

    func publishNote(text: String, imetaTags: [[String]] = []) async throws {
        guard !account.nsec.isEmpty else { return }

        var builder = EventBuilder.textNote(content: text)
        if !imetaTags.isEmpty {
            let tags: [Tag] = try imetaTags.map { try Tag.parse(data: $0) }
            builder = builder.tags(tags: tags)
        }

        try await account.sendAndVerify(builder: builder)
    }

    func publishBlossomServers() async throws {
        let tags: [Tag] = try account.blossomServers.map { try Tag.parse(data: ["server", $0]) }
        let builder = EventBuilder(kind: Kind(kind: 10063), content: "").tags(tags: tags)
        try await account.sendAndVerify(builder: builder)
        account.saveBlossomToCache()
    }
}
