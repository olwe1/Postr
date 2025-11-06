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
    private let profileCacheKey = "profileCache"

    struct ProfileCache: Codable {
        let relays: String
        let profileName: String
        let profileImageURL: String
        let profileImageData: Data?
        let lastUpdated: Date
    }

    init() {
        loadFromKeychain()
    }

    var isLoggedIn: Bool {
        !nsec.isEmpty && nsecSaved
    }

    func loadFromKeychain() {
        if let saved = KeychainHelper.get() {
            self.nsec = saved
            self.nsecSaved = true
        }
    }

    func saveToKeychain() {
        _ = KeychainHelper.save(value: nsec)
        nsecSaved = true
    }

    func deleteSession() {
        KeychainHelper.delete()
        self.nsec = ""
        self.nsecSaved = false
        self.pubKey = nil
        self.profileName = ""
        self.profileImageURL = ""
        self.profileImageData = nil
        clearProfileCache()
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
                    self.profileName = dict["display_name"] ?? ""
                    self.profileImageURL = dict["picture"] ?? ""
                    self.saveProfileToCache()
                    if dict["picture"] != nil { self.downloadProfileImage() }
                }
            }
        } catch {
            print("Error fetching metadata: \(error.localizedDescription)")
        }

        await client?.disconnect()
    }

    func downloadProfileImage() {
        guard let url = URL(string: profileImageURL), !profileImageURL.isEmpty
        else { return }
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.profileImageData = data
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
}
