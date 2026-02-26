import SwiftUI

struct LoginView: View {
    @EnvironmentObject var account: NostrAccount
    @EnvironmentObject var alertState: AlertState
    @EnvironmentObject var profileService: ProfileService

    private var isValidNsec: Bool { account.isValidNsec(account.nsec) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("Enter your private key…", text: $account.nsec)
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
                    if KeychainHelper.save(value: account.nsec) {
                        account.nsecSaved = true
                        alertState.show("Nsec securely saved!", severity: .success)
                        account.resolvePublicKey()
                        profileService.fetchProfile()
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
