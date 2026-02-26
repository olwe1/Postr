import Foundation
import NostrSDK

struct ProfileData {
    var relays: [String]?
    var name: String?
    var nameField: String = "display_name"
    var nameAlt: String = ""
    var imageURL: String?
    var bannerURL: String?
    var status: String?
    var blossomServers: [String]?
    var rawMetadataJSON: String = ""
}

struct ProfileFetcher {
    func fetchAll(pubKey: PublicKey, client: Client) async throws -> ProfileData {
        var result = ProfileData()

        async let relays = fetchRelays(pubKey: pubKey, client: client)
        async let meta = fetchMetadata(pubKey: pubKey, client: client)
        async let status = fetchStatus(pubKey: pubKey, client: client)
        async let blossom = fetchBlossomServers(pubKey: pubKey, client: client)

        result.relays = try? await relays
        if let m = try? await meta {
            result.name = m.name
            result.nameField = m.nameField
            result.nameAlt = m.nameAlt
            result.imageURL = m.imageURL
            result.bannerURL = m.bannerURL
            result.rawMetadataJSON = m.rawMetadataJSON
        }
        result.status = try? await status
        result.blossomServers = try? await blossom

        return result
    }

    private func fetchRelays(pubKey: PublicKey, client: Client) async throws -> [String]? {
        let filter = Filter().author(author: pubKey).kind(kind: Kind(kind: 10002))
        let events = try await client.fetchEvents(filter: filter, timeout: 5)
        let relayURLs = try events.toVec().flatMap { event in
            event.tags().toVec().compactMap { tag -> String? in
                let vec = tag.asVec()
                return (vec.count > 1 && vec[0] == "r") ? vec[1] : nil
            }
        }
        return relayURLs.isEmpty ? nil : relayURLs
    }

    struct MetadataResult {
        var name: String
        var nameField: String
        var nameAlt: String
        var imageURL: String
        var bannerURL: String
        var rawMetadataJSON: String
    }

    func fetchMetadata(pubKey: PublicKey, client: Client) async throws -> MetadataResult? {
        let metadata = try await client.fetchMetadata(publicKey: pubKey, timeout: 5)
        guard
            let jsonString = try metadata?.asJson(),
            let data = jsonString.data(using: .utf8),
            let anyDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let stringDict = anyDict.compactMapValues { $0 as? String }

        var result = MetadataResult(
            name: "", nameField: "display_name", nameAlt: "", imageURL: "", bannerURL: "",
            rawMetadataJSON: jsonString)

        if let dn = stringDict["display_name"], !dn.isEmpty {
            result.name = dn
            result.nameField = "display_name"
            result.nameAlt = stringDict["name"] ?? ""
        } else if let n = stringDict["name"], !n.isEmpty {
            result.name = n
            result.nameField = "name"
        }

        result.imageURL = stringDict["picture"] ?? ""
        result.bannerURL = stringDict["banner"] ?? ""
        return result
    }

    private func fetchStatus(pubKey: PublicKey, client: Client) async throws -> String? {
        let filter = Filter().author(author: pubKey).kind(kind: Kind(kind: 30315))
        let events = try await client.fetchEvents(filter: filter, timeout: 5)
        let generalStatus = try events.toVec()
            .filter { event in
                event.tags().toVec().contains { tag in
                    let vec = tag.asVec()
                    return vec.count >= 2 && vec[0] == "d" && vec[1] == "general"
                }
            }
            .max(by: { $0.createdAt().asSecs() < $1.createdAt().asSecs() })
        return generalStatus?.content()
    }

    private func fetchBlossomServers(pubKey: PublicKey, client: Client) async throws -> [String]? {
        let filter = Filter().author(author: pubKey).kind(kind: Kind(kind: 10063))
        let events = try await client.fetchEvents(filter: filter, timeout: 5)
        let latestEvent = try events.toVec().max(by: {
            $0.createdAt().asSecs() < $1.createdAt().asSecs()
        })
        guard let event = latestEvent else { return nil }
        let servers = event.tags().toVec().compactMap { tag -> String? in
            let vec = tag.asVec()
            return (vec.count > 1 && vec[0] == "server") ? vec[1] : nil
        }
        return servers.isEmpty ? nil : servers
    }
}
