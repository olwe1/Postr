import Foundation
import NostrSDK

struct PostService {
    static func postNote(
        note: String,
        nsec: String,
        relays: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            let client = Client()
            do {
                try await withTimeout(seconds: 15) {
                    let secretKey = try SecretKey.parse(secretKey: nsec)
                    let keys = Keys(secretKey: secretKey)
                    let relayArray =
                    relays
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    for relay in relayArray {
                        let relayURL = try RelayUrl.parse(url: String(relay))
                        _ = try await client.addRelay(url: relayURL)
                    }
                    
                    let builder = EventBuilder.textNote(content: note)
                    let unsignedEvent = builder.build(publicKey: keys.publicKey())
                    let event = try unsignedEvent.signWithKeys(keys: keys)
                    await client.connect()
                    await client.waitForConnection(timeout: 15)
                    _ = try await client.sendEvent(event: event)
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
            await client.disconnect()
        }
    }
}

// TODO: see if I can get rid of this function
func withTimeout<T>(seconds: Double, task: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await task()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw URLError(.timedOut)
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
