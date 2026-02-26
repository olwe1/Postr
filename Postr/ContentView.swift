import SwiftUI

struct ContentView: View {
    @EnvironmentObject var account: NostrAccount
    @EnvironmentObject var profileService: ProfileService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(
                onLogout: {
                    account.deleteSession(profileService: profileService)
                }
            )

            if !account.isLoggedIn {
                LoginView()
            } else {
                PostingView()
            }
        }
        .frame(maxWidth: 350)
        .task {
            profileService.loadFromCache()
            account.resolvePublicKey()
            if account.isLoggedIn {
                await account.connectClient()
                profileService.fetchProfile()
            }
        }
    }
}
