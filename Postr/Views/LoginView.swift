import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionService
    @EnvironmentObject var alertState: AlertState

    var body: some View {
        SecureField("Enter your private key…", text: $session.nsec)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        Button("Save Nsec") {
            if KeychainHelper.save(value: session.nsec) {
                session.nsecSaved = true
                alertState.message = "Nsec securely saved!"
                alertState.severity = .success
                Task { @MainActor in
                    await session.getClientSession()
                    await session.fetchProfile()
                }
            } else {
                alertState.message = "Failed to save nsec."
                alertState.severity = .error
            }
        }
    }
}
