import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    @Binding var relays: [String]
    @Binding var blossomServers: [String]
    @Binding var uploadToAllServers: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    var onLogout: (() -> Void)? = nil

    @State private var newRelayURL: String = ""
    @State private var newServerURL: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Relays")
                .font(.headline)

            if relays.isEmpty {
                Text("No relays configured")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(relays.enumerated()), id: \.offset) { index, relay in
                        HStack(spacing: 8) {
                            Text(relay)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button(action: { relays.remove(at: index) }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            HStack {
                TextField("wss://...", text: $newRelayURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit { addRelay() }

                Button(action: addRelay) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(newRelayURL.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plain)
            }

            Divider()

            Text("Blossom Servers")
                .font(.headline)

            if blossomServers.isEmpty {
                Text("No servers configured")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(blossomServers.enumerated()), id: \.offset) { index, server in
                        HStack(spacing: 8) {
                            Text(server)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button(action: { moveServer(at: index, direction: -1) }) {
                                Image(systemName: "chevron.up")
                                    .font(.caption)
                            }
                            .disabled(index == 0)
                            .buttonStyle(.plain)
                            .opacity(index == 0 ? 0.3 : 1)

                            Button(action: { moveServer(at: index, direction: 1) }) {
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .disabled(index == blossomServers.count - 1)
                            .buttonStyle(.plain)
                            .opacity(index == blossomServers.count - 1 ? 0.3 : 1)

                            Button(action: { blossomServers.remove(at: index) }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            HStack {
                TextField("https://...", text: $newServerURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit { addServer() }

                Button(action: addServer) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(newServerURL.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plain)
            }

            Toggle("Upload to all servers", isOn: $uploadToAllServers)
                .font(.caption)

            Divider()

            Form {
                LaunchAtLogin.Toggle("Launch at startup")
            }

            Spacer()

            HStack {
                if let onLogout {
                    Button("Log Out") { onLogout() }
                        .buttonStyle(.bordered)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 400)
    }

    private func moveServer(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < blossomServers.count else { return }
        blossomServers.swapAt(index, newIndex)
    }

    private func normalizedRelay(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("wss://") && !url.hasPrefix("ws://") { url = "wss://" + url }
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        return url
    }

    private func normalizedServer(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") { url = "https://" + url }
        if url.hasSuffix("/") { url = String(url.dropLast()) }
        return url
    }

    private func addRelay() {
        let url = normalizedRelay(newRelayURL)
        guard !url.isEmpty else { return }
        if !relays.map({ normalizedRelay($0) }).contains(url) {
            relays.append(url)
            newRelayURL = ""
        }
    }

    private func addServer() {
        let url = normalizedServer(newServerURL)
        guard !url.isEmpty else { return }
        if !blossomServers.map({ normalizedServer($0) }).contains(url) {
            blossomServers.append(url)
            newServerURL = ""
        }
    }
}
