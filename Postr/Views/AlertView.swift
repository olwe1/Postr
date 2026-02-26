import SwiftUI

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
