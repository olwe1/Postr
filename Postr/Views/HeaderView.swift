import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var account: NostrAccount
    @EnvironmentObject var profileService: ProfileService
    @EnvironmentObject var alertState: AlertState
    @State private var showRelaySheet = false
    @State private var relayDraft = ""
    @State private var blossomServersDraft: [String] = []
    @State private var uploadToAllServersDraft: Bool = true
    @State private var isEditingStatus = false
    @State private var statusDraft = ""
    @State private var isEditingName = false
    @State private var nameDraft = ""
    let onLogout: () -> Void
    let avatarSize: CGFloat = 44

    var body: some View {
        if account.isLoggedIn {
            VStack(spacing: 0) {
                if let data = profileService.profileBannerData,
                   let uiimg = NSImage(data: data)
                {
                    Image(nsImage: uiimg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .clipped()
                        .padding(.horizontal, -16)
                        .padding(.top, -16)
                }

                HStack {
                    if let data = profileService.profileImageData,
                       let uiimg = NSImage(data: data),
                       let url = URL(string: "https://nosta.me/\(account.pubKey?.toHex() ?? "")")
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
                                .handCursor()
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

                    VStack(alignment: .leading, spacing: 2) {
                        if !profileService.profileName.isEmpty {
                            if isEditingName {
                                HStack(spacing: 4) {
                                    TextField("Name...", text: $nameDraft)
                                        .font(.system(size: 20, weight: .medium, design: .rounded))
                                        .tracking(0.2)
                                        .textFieldStyle(.plain)
                                        .frame(maxWidth: 200)
                                        .onSubmit { submitName() }

                                    Button { submitName() } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .handCursor()
                                }
                            } else {
                                Button {
                                    nameDraft = profileService.profileName
                                    isEditingName = true
                                } label: {
                                    Text(profileService.profileName)
                                        .font(.system(size: 20, weight: .medium, design: .rounded))
                                        .tracking(0.2)
                                }
                                .buttonStyle(.plain)
                                .handCursor()
                            }

                            HStack(spacing: 4) {
                                if isEditingStatus {
                                    TextField("Status...", text: $statusDraft)
                                        .font(.system(size: 12))
                                        .textFieldStyle(.plain)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: 200)
                                        .onSubmit { submitStatus() }

                                    Button { submitStatus() } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .handCursor()
                                } else {
                                    Button {
                                        statusDraft = profileService.profileStatus
                                        isEditingStatus = true
                                    } label: {
                                        Text(profileService.profileStatus.isEmpty ? "No status" : profileService.profileStatus)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                            .truncationMode(.tail)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .buttonStyle(.plain)
                                    .handCursor()
                                }
                            }
                        }
                    }

                    Spacer()

                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                            .handCursor()
                    }
                    .buttonStyle(.plain)
                    .help("Edit relays")
                }
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .sheet(isPresented: $showRelaySheet) {
                SettingsView(
                    relays: $relayDraft,
                    blossomServers: $blossomServersDraft,
                    uploadToAllServers: $uploadToAllServersDraft,
                    onSave: {
                        account.relays = relayDraft
                        account.blossomServers = blossomServersDraft
                        account.uploadToAllServers = uploadToAllServersDraft
                        Task { try? await PublishingService(account: account).publishBlossomServers() }
                        showRelaySheet = false
                    },
                    onCancel: { showRelaySheet = false },
                    onLogout: account.nsecSaved
                        ? { showRelaySheet = false; onLogout() }
                        : nil
                )
            }
        }
    }

    private func submitName() {
        guard nameDraft != profileService.profileName else { isEditingName = false; return }
        isEditingName = false
        Task {
            do {
                try await profileService.publishName(nameDraft)
            } catch {
                alertState.show("Failed to publish name.", severity: .error)
            }
        }
    }

    private func submitStatus() {
        guard statusDraft != profileService.profileStatus else { isEditingStatus = false; return }
        isEditingStatus = false
        Task {
            do {
                try await profileService.publishStatus(statusDraft)
            } catch {
                alertState.show("Failed to publish status.", severity: .error)
            }
        }
    }

    private func onSettings() {
        relayDraft = account.relays
        blossomServersDraft = account.blossomServers
        uploadToAllServersDraft = account.uploadToAllServers
        showRelaySheet = true
    }
}
