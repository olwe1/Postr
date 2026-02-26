import Foundation
import NostrSDK

final class PublishingService: ObservableObject {
    private let account: NostrAccount

    init(account: NostrAccount) {
        self.account = account
    }

    func publishNote(text: String, imetaTags: [[String]] = []) async throws {
        guard !account.nsec.isEmpty else { return }

        let secretKey = try SecretKey.parse(secretKey: account.nsec)
        let keys = Keys(secretKey: secretKey)

        var builder = EventBuilder.textNote(content: text)
        if !imetaTags.isEmpty {
            let tags: [Tag] = try imetaTags.map { try Tag.parse(data: $0) }
            builder = builder.tags(tags: tags)
        }

        let event = try builder.build(publicKey: keys.publicKey()).signWithKeys(keys: keys)

        let client = try await account.makeClient()
        await client.connect()
        await client.waitForConnection(timeout: 15)
        let output = try await client.sendEvent(event: event)
        await client.disconnect()

        guard !output.success.isEmpty else {
            let reasons = output.failed.values.joined(separator: ", ")
            throw NSError(
                domain: "NostrPublish", code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: reasons.isEmpty
                        ? "No relay accepted the event." : reasons
                ]
            )
        }
    }

    func publishBlossomServers() async throws {
        let tags: [Tag] = try account.blossomServers.map { try Tag.parse(data: ["server", $0]) }
        let builder = EventBuilder(kind: Kind(kind: 10063), content: "").tags(tags: tags)
        try await account.sendAndVerify(builder: builder)
        account.saveBlossomToCache()
    }
}
