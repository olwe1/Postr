import Combine
import Foundation
import NostrSDK
import os.log

class SessionService: ObservableObject {
    @Published var relays: String =
        "wss://relay.nostr.band,wss://nos.lol,wss://relay.primal.net"
    @Published var nsec: String = ""
    @Published var pubKey: PublicKey?
    @Published var client: Client?
    @Published var nsecSaved: Bool = false
    @Published var profileName: String = ""
    @Published var profileImageURL: String = ""
    @Published var profileImageData: Data?
    @Published var profileBannerURL: String = ""
    @Published var profileBannerData: Data?
    @Published var blossomServers: [String] = ["https://blossom.primal.net"]
    @Published var uploadToAllServers: Bool = true
    private let profileCacheKey = "profileCache"
    private let blossomCacheKey = "blossomSettings"

    struct ProfileCache: Codable {
        let relays: String
        let profileName: String
        let profileImageURL: String
        let profileImageData: Data?
        let profileBannerURL: String
        let profileBannerData: Data?
        let lastUpdated: Date
    }

    struct BlossomCache: Codable {
        let servers: [String]
        let uploadToAll: Bool
    }

    init() {
        loadFromKeychain()
        loadBlossomFromCache()
    }

    var isLoggedIn: Bool {
        !nsec.isEmpty && nsecSaved
    }

    func isValidNsec(_ value: String) -> Bool {
        do {
            _ = try SecretKey.parse(secretKey: value)
            return true
        } catch {
            return false
        }
    }

    func loadFromKeychain() {
        if let saved = KeychainHelper.get() {
            self.nsec = saved
            self.nsecSaved = true
        }
    }

    func deleteSession() {
        KeychainHelper.delete()
        self.nsec = ""
        self.nsecSaved = false
        self.pubKey = nil
        self.profileName = ""
        self.profileImageURL = ""
        self.profileImageData = nil
        self.profileBannerURL = ""
        self.profileBannerData = nil
        self.blossomServers = ["https://blossom.primal.net"]
        self.uploadToAllServers = true
        clearProfileCache()
        clearBlossomCache()
    }

    @MainActor
    func getClientSession() async {
        do {
            let secretKey = try SecretKey.parse(secretKey: nsec)
            let keys = Keys(secretKey: secretKey)
            let relayArray =
                relays
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let client = Client()

            for relay in relayArray {
                let relayURL = try RelayUrl.parse(url: String(relay))
                _ = try await client.addRelay(url: relayURL)
            }

            self.pubKey = keys.publicKey()
            self.client = client
        } catch {
            print("Error: \(error)")
        }
    }

    @MainActor
    func fetchProfile() async {
        guard !nsec.isEmpty, let pubKey = pubKey else { return }
        await client?.connect()

        // Save user relays
        let filter = Filter()
            .author(author: pubKey)
            .kind(kind: Kind(kind: 10002))

        do {
            let relayEvents = try await client?.fetchEvents(
                filter: filter,
                timeout: 10
            )
            let eventsArray = try relayEvents?.toVec() ?? []

            let userRelays = eventsArray.flatMap { event in
                (event.tags().toVec()).compactMap { tag in
                    let vec = tag.asVec()
                    return (vec.count > 1 && vec[0] == "r") ? vec[1] : nil
                }
            }

            if !userRelays.isEmpty {
                self.relays = userRelays.joined(separator: ",")
            }

        } catch {
            print("Erreur lors de la récupération des events : \(error)")
        }

        // Get user metadata
        do {
            let metadata = try await client?.fetchMetadata(
                publicKey: pubKey,
                timeout: 10
            )

            if let jsonString = try metadata?.asJson() {
                if let data = jsonString.data(using: .utf8),
                    let dict = try? JSONSerialization.jsonObject(with: data)
                        as? [String: String]
                {
                    self.profileName = dict["display_name"] ?? dict["name"] ?? ""
                    self.profileImageURL = dict["picture"] ?? ""
                    self.profileBannerURL = dict["banner"] ?? ""
                    self.saveProfileToCache()
                    if dict["picture"] != nil { self.downloadProfileImage() }
                    if dict["banner"] != nil { self.downloadProfileBanner() }
                }
            }
        } catch {
            print("Error fetching metadata: \(error.localizedDescription)")
        }

        await fetchBlossomServers()
        await client?.disconnect()
    }

    func downloadProfileImage() {
        downloadProfileData(from: profileImageURL) { data in
            self.profileImageData = data
        }
    }

    func downloadProfileBanner() {
        downloadProfileData(from: profileBannerURL) { data in
            self.profileBannerData = data
        }
    }

    private func downloadProfileData(
        from urlString: String,
        completion: @escaping (Data?) -> Void
    ) {
        guard let url = URL(string: urlString), !urlString.isEmpty
        else { return }
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                completion(data)
                self.saveProfileToCache()
            }
        }
        task.resume()
    }

    func saveProfileToCache() {
        let cache = ProfileCache(
            relays: self.relays,
            profileName: self.profileName,
            profileImageURL: self.profileImageURL,
            profileImageData: self.profileImageData,
            profileBannerURL: self.profileBannerURL,
            profileBannerData: self.profileBannerData,
            lastUpdated: Date()
        )
        do {
            let data = try JSONEncoder().encode(cache)
            UserDefaults.standard.set(data, forKey: profileCacheKey)
        } catch {
            os_log(
                "Failed to encode profile cache: %{public}@",
                String(describing: error)
            )
        }
    }

    func loadProfileFromCache() {
        guard let data = UserDefaults.standard.data(forKey: profileCacheKey)
        else { return }
        do {
            let cache = try JSONDecoder().decode(ProfileCache.self, from: data)
            self.relays = cache.relays
            self.profileName = cache.profileName
            self.profileImageURL = cache.profileImageURL
            self.profileImageData = cache.profileImageData
            self.profileBannerURL = cache.profileBannerURL
            self.profileBannerData = cache.profileBannerData
        } catch {
            os_log(
                "Failed to decode profile cache: %{public}@",
                String(describing: error)
            )
        }
    }

    func clearProfileCache() {
        UserDefaults.standard.removeObject(forKey: profileCacheKey)
    }

    @MainActor
    func fetchBlossomServers() async {
        guard let pubKey = pubKey, let client = client else { return }

        let filter = Filter()
            .author(author: pubKey)
            .kind(kind: Kind(kind: 10063))

        do {
            let events = try await client.fetchEvents(filter: filter, timeout: 10)
            let eventsArray = try events.toVec()

            if let latestEvent = eventsArray.max(by: {
                $0.createdAt().asSecs() < $1.createdAt().asSecs()
            }) {
                let servers = latestEvent.tags().toVec().compactMap { tag in
                    let vec = tag.asVec()
                    return (vec.count > 1 && vec[0] == "server") ? vec[1] : nil
                }
                if !servers.isEmpty {
                    self.blossomServers = servers
                    saveBlossomToCache()
                }
            }
        } catch {
            print("Error fetching blossom servers: \(error)")
        }
    }

    func publishBlossomServers() async throws {
        guard !nsec.isEmpty, let client = client else { return }

        let secretKey = try SecretKey.parse(secretKey: nsec)
        let keys = Keys(secretKey: secretKey)

        let tags: [Tag] = try blossomServers.map { server in
            try Tag.parse(data: ["server", server])
        }
        let builder = EventBuilder(kind: Kind(kind: 10063), content: "")
            .tags(tags: tags)

        let event = try builder.signWithKeys(keys: keys)

        await client.connect()
        await client.waitForConnection(timeout: 15)
        _ = try await client.sendEvent(event: event)
        await client.disconnect()

        saveBlossomToCache()
    }

    func saveBlossomToCache() {
        let cache = BlossomCache(servers: blossomServers, uploadToAll: uploadToAllServers)
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: blossomCacheKey)
        }
    }

    func loadBlossomFromCache() {
        guard let data = UserDefaults.standard.data(forKey: blossomCacheKey),
            let cache = try? JSONDecoder().decode(BlossomCache.self, from: data)
        else { return }
        self.blossomServers = cache.servers
        self.uploadToAllServers = cache.uploadToAll
    }

    func clearBlossomCache() {
        UserDefaults.standard.removeObject(forKey: blossomCacheKey)
    }
}
