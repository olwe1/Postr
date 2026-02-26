import Foundation

func loadImageData(from urlString: String) async -> Data? {
    guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
    return try? await URLSession.shared.data(from: url).0
}
