import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    @Binding var relays: String
    @Binding var blossomServers: [String]
    @Binding var uploadToAllServers: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    var onLogout: (() -> Void)? = nil

    @State private var newServerURL: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Relays")
                .font(.headline)
            TextField("Relays (comma-separated)", text: $relays)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body))

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

    private func addServer() {
        var url = newServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        if !blossomServers.contains(url) {
            blossomServers.append(url)
        }
        newServerURL = ""
    }
}
