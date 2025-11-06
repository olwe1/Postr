import Foundation
import Combine

final class DraftViewModel: ObservableObject {
    @Published var text: String = ""
    private var cancellables = Set<AnyCancellable>()
    private let storageKey: String

    init(storageKey: String) {
        self.storageKey = storageKey
        self.text = UserDefaults.standard.string(forKey: storageKey) ?? ""

        $text
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] newText in
                guard let self = self else { return }
                UserDefaults.standard.set(newText, forKey: self.storageKey)
            }
            .store(in: &cancellables)
    }

    func saveNow() {
        UserDefaults.standard.set(text, forKey: storageKey)
    }

    func clear() {
        text = ""
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
