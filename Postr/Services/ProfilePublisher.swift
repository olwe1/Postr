import Foundation
import NostrSDK

struct ProfilePublisher {
    func publishStatus(_ status: String, account: NostrAccount) async throws {
        let tags: [Tag] = [try Tag.parse(data: ["d", "general"])]
        let builder = EventBuilder(kind: Kind(kind: 30315), content: status).tags(tags: tags)
        try await account.sendAndVerify(builder: builder)
    }

    func publishName(
        _ name: String,
        nameField: String,
        nameAlt: String,
        cachedRawMetadataJSON: String,
        pubKey: PublicKey,
        client: Client,
        account: NostrAccount
    ) async throws {
        let baseJSON: String
        if let meta = try? await ProfileFetcher().fetchMetadata(pubKey: pubKey, client: client) {
            baseJSON = meta.rawMetadataJSON
        } else {
            baseJSON = cachedRawMetadataJSON
        }

        var anyDict: [String: Any]
        if !baseJSON.isEmpty,
            let data = baseJSON.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            anyDict = parsed
        } else {
            anyDict = [:]
        }

        if nameField == "display_name" {
            anyDict["display_name"] = name
            if !nameAlt.isEmpty {
                anyDict["name"] = nameAlt
            }
        } else {
            anyDict["name"] = name
            anyDict.removeValue(forKey: "display_name")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: anyDict)
        let jsonString = String(decoding: jsonData, as: UTF8.self)
        let builder = EventBuilder(kind: Kind(kind: 0), content: jsonString)
        try await account.sendAndVerify(builder: builder)
    }
}
