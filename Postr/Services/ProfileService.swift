import Foundation
import NostrSDK
import os.log

@MainActor
final class ProfileService: ObservableObject {
    @Published var profileName: String = ""
    @Published var profileImageURL: String = ""
    @Published var profileImageData: Data?
    @Published var profileBannerURL: String = ""
    @Published var profileBannerData: Data?
    @Published var profileStatus: String = ""

    private(set) var nameField: String = "display_name"
    private(set) var nameAlt: String = ""
    private(set) var rawMetadataJSON: String = ""

    private let account: NostrAccount
    private let fetcher = ProfileFetcher()
    private let publisher = ProfilePublisher()
    private let cacheKey = "profileCache"
    private var fetchTask: Task<Void, Never>?

    init(account: NostrAccount) {
        self.account = account
    }

    func clearSession() {
        fetchTask?.cancel()
        fetchTask = nil
        profileName = ""
        profileImageURL = ""
        profileImageData = nil
        profileBannerURL = ""
        profileBannerData = nil
        profileStatus = ""
        rawMetadataJSON = ""
        clearCache()
    }

    func fetchProfile() {
        fetchTask?.cancel()
        fetchTask = Task { await runFetch() }
    }

    private func runFetch() async {
        guard !account.nsec.isEmpty, let pubKey = account.pubKey else { return }
        do {
            let client = try await account.makeClient()
            await client.connect()
            defer { Task { await client.disconnect() } }

            guard !Task.isCancelled else { return }

            let data = try await fetcher.fetchAll(pubKey: pubKey, client: client)

            guard !Task.isCancelled else { return }

            if let relays = data.relays {
                account.relays = relays
            }
            if !data.name.isNilOrEmpty {
                profileName = data.name!
                nameField = data.nameField
                nameAlt = data.nameAlt
            }
            if !data.rawMetadataJSON.isEmpty {
                rawMetadataJSON = data.rawMetadataJSON
            }
            if let url = data.imageURL {
                profileImageURL = url
                if !url.isEmpty {
                    profileImageData = await loadImageData(from: url)
                }
            }
            if let url = data.bannerURL {
                profileBannerURL = url
                if !url.isEmpty {
                    profileBannerData = await loadImageData(from: url)
                }
            }
            if let status = data.status {
                profileStatus = status
            }
            if let servers = data.blossomServers {
                account.blossomServers = servers
                account.saveBlossomToCache()
            }

            saveToCache()

        } catch {
            print("ProfileService: fetch failed: \(error)")
        }
    }

    func publishStatus(_ status: String) async throws {
        let previous = profileStatus
        profileStatus = status
        fetchTask?.cancel()
        fetchTask = nil
        do {
            try await publisher.publishStatus(status, account: account)
            saveToCache()
        } catch {
            profileStatus = previous
            throw error
        }
    }

    func publishName(_ name: String) async throws {
        guard let pubKey = account.pubKey else { return }
        let previous = profileName
        profileName = name
        fetchTask?.cancel()
        fetchTask = nil
        do {
            try await publisher.publishName(
                name,
                nameField: nameField,
                nameAlt: nameAlt,
                cachedRawMetadataJSON: rawMetadataJSON,
                pubKey: pubKey,
                account: account
            )
            saveToCache()
        } catch {
            profileName = previous
            throw error
        }
    }

    func saveToCache() {
        UserDefaultsCache.save(
            Cache(
                relays: account.relays,
                profileName: profileName,
                profileImageURL: profileImageURL,
                profileImageData: profileImageData,
                profileBannerURL: profileBannerURL,
                profileBannerData: profileBannerData,
                profileStatus: profileStatus,
                rawMetadataJSON: rawMetadataJSON,
                lastUpdated: Date()
            ),
            key: cacheKey
        )
    }

    func loadFromCache() {
        guard let cache = UserDefaultsCache.load(Cache.self, key: cacheKey) else { return }
        account.relays = cache.relays
        profileName = cache.profileName
        profileImageURL = cache.profileImageURL
        profileImageData = cache.profileImageData
        profileBannerURL = cache.profileBannerURL
        profileBannerData = cache.profileBannerData
        profileStatus = cache.profileStatus
        rawMetadataJSON = cache.rawMetadataJSON
    }

    func clearCache() {
        UserDefaultsCache.remove(key: cacheKey)
    }
}

extension ProfileService {
    struct Cache: Codable {
        let relays: String
        let profileName: String
        let profileImageURL: String
        let profileImageData: Data?
        let profileBannerURL: String
        let profileBannerData: Data?
        let profileStatus: String
        let rawMetadataJSON: String
        let lastUpdated: Date

        init(
            relays: String, profileName: String,
            profileImageURL: String, profileImageData: Data?,
            profileBannerURL: String, profileBannerData: Data?,
            profileStatus: String, rawMetadataJSON: String,
            lastUpdated: Date
        ) {
            self.relays = relays
            self.profileName = profileName
            self.profileImageURL = profileImageURL
            self.profileImageData = profileImageData
            self.profileBannerURL = profileBannerURL
            self.profileBannerData = profileBannerData
            self.profileStatus = profileStatus
            self.rawMetadataJSON = rawMetadataJSON
            self.lastUpdated = lastUpdated
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            relays = try c.decode(String.self, forKey: .relays)
            profileName = try c.decode(String.self, forKey: .profileName)
            profileImageURL = try c.decode(String.self, forKey: .profileImageURL)
            profileImageData = try c.decodeIfPresent(Data.self, forKey: .profileImageData)
            profileBannerURL = try c.decode(String.self, forKey: .profileBannerURL)
            profileBannerData = try c.decodeIfPresent(Data.self, forKey: .profileBannerData)
            profileStatus = try c.decodeIfPresent(String.self, forKey: .profileStatus) ?? ""
            rawMetadataJSON = try c.decodeIfPresent(String.self, forKey: .rawMetadataJSON) ?? ""
            lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        }
    }
}

extension Optional where Wrapped == String {
    fileprivate var isNilOrEmpty: Bool { self == nil || self!.isEmpty }
}
