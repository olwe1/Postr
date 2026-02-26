import Foundation
import NostrSDK

final class NostrAccount: ObservableObject {
    private static let defaultRelays: [String] = [
        "wss://relay.nostr.band",
        "wss://nos.lol",
        "wss://relay.primal.net",
    ]
    private static let defaultBlossomServers: [String] = ["https://blossom.primal.net"]

    @Published var nsec: String = ""
    @Published var pubKey: PublicKey?
    @Published var nsecSaved: Bool = false
    @Published var relays: [String] = defaultRelays
    @Published var blossomServers: [String] = defaultBlossomServers
    @Published var uploadToAllServers: Bool = true

    private var sharedClient: Client?
    private let blossomCacheKey = "blossomSettings"
    private let relaysCacheKey = "relaysSettings"

    struct BlossomCache: Codable {
        let servers: [String]
        let uploadToAll: Bool
    }

    struct RelaysCache: Codable {
        let relays: [String]
    }

    init() {
        loadFromKeychain()
        loadBlossomFromCache()
        loadRelaysFromCache()
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
        Task { await disconnectClient() }
        KeychainHelper.delete()
        self.nsec = ""
        self.nsecSaved = false
        self.pubKey = nil
        self.relays = Self.defaultRelays
        self.blossomServers = Self.defaultBlossomServers
        self.uploadToAllServers = true
        clearBlossomCache()
        clearRelaysCache()
        profileService.clearSession()
    }

    func connectClient() async {
        guard sharedClient == nil else { return }
        do {
            let client = try await makeClient()
            await client.connect()
            await client.waitForConnection(timeout: 5)
            sharedClient = client
        } catch {
            print("NostrAccount: connectClient failed: \(error)")
        }
    }

    func disconnectClient() async {
        if let client = sharedClient {
            await client.disconnect()
            sharedClient = nil
        }
    }

    func ensureConnected() async throws -> Client {
        if let client = sharedClient {
            return client
        }
        let client = try await makeClient()
        await client.connect()
        await client.waitForConnection(timeout: 5)
        sharedClient = client
        return client
    }

    func makeClient() async throws -> Client {
        let client = Client()
        for relay in relays where !relay.isEmpty {
            let relayURL = try RelayUrl.parse(url: relay)
            _ = try await client.addRelay(url: relayURL)
        }
        return client
    }

    func sendAndVerify(builder: EventBuilder) async throws {
        guard !nsec.isEmpty else { return }
        let secretKey = try SecretKey.parse(secretKey: nsec)
        let keys = Keys(secretKey: secretKey)
        let event = try builder.signWithKeys(keys: keys)

        let client = try await ensureConnected()
        let output = try await client.sendEvent(event: event)

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

    func saveRelaysToCache() {
        UserDefaultsCache.save(RelaysCache(relays: relays), key: relaysCacheKey)
    }

    func loadRelaysFromCache() {
        guard let cache = UserDefaultsCache.load(RelaysCache.self, key: relaysCacheKey) else {
            return
        }
        self.relays = cache.relays
    }

    func clearRelaysCache() {
        UserDefaultsCache.remove(key: relaysCacheKey)
    }
}
