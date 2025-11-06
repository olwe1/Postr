import SwiftUI

class AlertState: ObservableObject {
    @Published var message: String = ""
    @Published var severity: MessageSeverity = .success
    private var hideTask: DispatchWorkItem?

    func show(_ message: String, severity: MessageSeverity, autoHideAfter seconds: Int? = nil) {
        self.message = message
        self.severity = severity

        hideTask?.cancel()
        let delay = seconds ?? defaultDelay(for: severity)
        guard delay > 0 else { return }
        let task = DispatchWorkItem { [weak self] in
            self?.message = ""
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: task)
    }

    private func defaultDelay(for severity: MessageSeverity) -> Int {
        switch severity {
        case .success: return 3
        case .error: return 8
        }
    }
}

struct AlertView: View {
    @EnvironmentObject var alertState: AlertState

    var body: some View {
        if !alertState.message.isEmpty {
            Text(alertState.message)
                .foregroundColor(alertState.severity.color)
                .font(.subheadline)
        }
    }
}

enum MessageSeverity {
    case success
    case error

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        }
    }
}
