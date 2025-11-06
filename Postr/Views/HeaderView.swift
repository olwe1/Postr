import AppKit
import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var session: SessionService
    @State private var showRelaySheet = false
    @State private var relayDraft = ""
    let onLogout: () -> Void
    let avatarSize: CGFloat = 40

    var body: some View {
        HStack {
            if let data = session.profileImageData,
                let uiimg = NSImage(data: data),
                let url = URL(string: "https://nosta.me/\(session.pubKey?.toHex() ?? "")")
            {
                Link(destination: url) {
                    Image(nsImage: uiimg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                        .shadow(radius: 3)
                        .accessibility(label: Text("Profile photo"))
                        .onHover { hovering in
                            hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                        }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: avatarSize * 0.5))
                            .foregroundColor(.secondary)
                    )
            }

            Text(session.profileName)
                .font(.title2)

            Spacer()

            if session.nsecSaved {
                Button("Log Out", action: onLogout)
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .foregroundColor(.red)
                    .onHover { hovering in
                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                    }
            }

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .imageScale(.large)
                    .padding(8)
                    .onHover { hovering in
                        hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                    }
            }
            .buttonStyle(.plain)
            .help("Edit relays")
        }
        .sheet(isPresented: $showRelaySheet) {
            SettingsView(
                relays: $relayDraft,
                onSave: {
                    session.relays = relayDraft
                    showRelaySheet = false
                },
                onCancel: {
                    showRelaySheet = false
                }
            )
        }
    }

    func onSettings() {
        relayDraft = session.relays
        showRelaySheet = true
    }
}
