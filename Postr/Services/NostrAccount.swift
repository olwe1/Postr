import Foundation
import NostrSDK

final class NostrAccount: ObservableObject {
    @Published var nsec: String = ""
    @Published var pubKey: PublicKey?
    @Published var nsecSaved: Bool = false
    @Published var relays: String = "wss://relay.nostr.band,wss://nos.lol,wss://relay.primal.net"
    @Published var blossomServers: [String] = ["https://blossom.primal.net"]
    @Published var uploadToAllServers: Bool = true

    private let blossomCacheKey = "blossomSettings"

    struct BlossomCache: Codable {
        let servers: [String]
        let uploadToAll: Bool
    }

    init() {
        loadFromKeychain()
        loadBlossomFromCache()
    }

    var isLoggedIn: Bool { !nsec.isEmpty && nsecSaved }

    func loadFromKeychain() {
        if let saved = KeychainHelper.get() {
            self.nsec = saved
            self.nsecSaved = true
        }
    }

    func resolvePublicKey() {
        guard !nsec.isEmpty else { return }
        do {
            let secretKey = try SecretKey.parse(secretKey: nsec)
            self.pubKey = Keys(secretKey: secretKey).publicKey()
        } catch {
            print("NostrAccount: failed to resolve pubKey: \(error)")
        }
    }

    func isValidNsec(_ value: String) -> Bool {
        (try? SecretKey.parse(secretKey: value)) != nil
    }

    @MainActor
    func deleteSession(profileService: ProfileService) {
        KeychainHelper.delete()
        self.nsec = ""
        self.nsecSaved = false
        self.pubKey = nil
        self.blossomServers = ["https://blossom.primal.net"]
        self.uploadToAllServers = true
        clearBlossomCache()
        profileService.clearSession()
    }

    func makeClient() async throws -> Client {
        let client = Client()
        let relayURLs =
            relays
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for relay in relayURLs {
            let relayURL = try RelayUrl.parse(url: relay)
            _ = try await client.addRelay(url: relayURL)
        }
        return client
    }

    func saveBlossomToCache() {
        UserDefaultsCache.save(
            BlossomCache(servers: blossomServers, uploadToAll: uploadToAllServers),
            key: blossomCacheKey)
    }

    func loadBlossomFromCache() {
        guard let cache = UserDefaultsCache.load(BlossomCache.self, key: blossomCacheKey) else {
            return
        }
        self.blossomServers = cache.servers
        self.uploadToAllServers = cache.uploadToAll
    }

    func clearBlossomCache() {
        UserDefaultsCache.remove(key: blossomCacheKey)
    }

    func sendAndVerify(builder: EventBuilder) async throws {
        guard !nsec.isEmpty else { return }
        let secretKey = try SecretKey.parse(secretKey: nsec)
        let keys = Keys(secretKey: secretKey)
        let event = try builder.signWithKeys(keys: keys)

        let client = try await makeClient()
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
}
