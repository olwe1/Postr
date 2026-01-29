import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionService
    @EnvironmentObject var alertState: AlertState

    private var isValidNsec: Bool { session.isValidNsec(session.nsec) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("Enter your private key…", text: $session.nsec)
                .textFieldStyle(.plain)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isValidNsec ? Color.green : Color.red, lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("Save Nsec") {
                    if KeychainHelper.save(value: session.nsec) {
                        session.nsecSaved = true
                        alertState.show("Nsec securely saved!", severity: .success)
                        Task { @MainActor in
                            await session.getClientSession()
                            await session.fetchProfile()
                        }
                    } else {
                        alertState.show("Failed to save nsec.", severity: .error)
                    }
                }
                .disabled(!isValidNsec)
                Spacer()
            }
        }
        .padding(16)
    }
}
