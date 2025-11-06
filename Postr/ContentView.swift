import NostrSDK
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(
                onLogout: {
                    session.deleteSession()
                }
            )

            if !session.isLoggedIn {
                LoginView()
            } else {
                PostingView()
            }
        }
        .frame(maxWidth: 350)
        .task {
            session.loadProfileFromCache()
            await session.getClientSession()
            if session.isLoggedIn { await session.fetchProfile() }
        }
    }
}
