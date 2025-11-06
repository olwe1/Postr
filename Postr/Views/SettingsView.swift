import SwiftUI
import LaunchAtLogin

struct SettingsView: View {
    @Binding var relays: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Relays")
                .font(.headline)
            TextField("Relays (comma-separated)", text: $relays)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body))
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave() }
                    .keyboardShortcut(.defaultAction)
            }
            Spacer()
            Form {
                LaunchAtLogin.Toggle("Launch at startup")
            }
        }
        .padding(22)
        .frame(minWidth: 350)
    }
}
