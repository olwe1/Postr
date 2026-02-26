import Foundation
import os.log

enum UserDefaultsCache {
    static func save<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            os_log("UserDefaultsCache: failed to encode %{public}@: %{public}@", key, String(describing: error))
        }
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            os_log("UserDefaultsCache: failed to decode %{public}@: %{public}@", key, String(describing: error))
            return nil
        }
    }

    static func remove(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
