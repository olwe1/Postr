import SwiftUI

struct PostingView: View {
    @EnvironmentObject var account: NostrAccount
    @EnvironmentObject var alertState: AlertState
    @EnvironmentObject var uploadVM: UploadViewModel
    @EnvironmentObject var publishingService: PublishingService
    @StateObject private var note = DraftViewModel(storageKey: "draft_note")
    @StateObject private var vm = PostingViewModel()
    @State private var showDonatePopover = false

    private var isProcessing: Bool {
        vm.isPosting || uploadVM.isUploading
    }

    private var buttonText: String {
        if uploadVM.isUploading { return "Uploading…" }
        if vm.isPosting { return "Posting…" }
        return "Post"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Note:")
                    .font(.headline)
                Spacer()
                AlertView()
            }

            TextEditor(text: $note.text)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3))
                )

            HStack {
                UploadProgressView(
                    progress: uploadVM.uploadProgress,
                    isUploading: uploadVM.isUploading,
                    onSelect: { selectAndUploadFiles() }
                )

                Spacer()

                Button(action: performPost) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(buttonText)
                    }
                }
                .disabled(!canPost)
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .handCursor()

                Spacer()

                Button(action: { showDonatePopover.toggle() }) {
                    Text("⚡️")
                }
                .buttonStyle(.plain)
                .handCursor()
                .popover(isPresented: $showDonatePopover) {
                    DonateView()
                }
            }
            .padding(.vertical, 6)
        }
        .onChange(of: showDonatePopover) { newValue in
            if newValue == false { NSApp.activate(ignoringOtherApps: true) }
        }
        .onDisappear {
            note.saveNow()
        }
    }

    private var canPost: Bool {
        !isProcessing && vm.canPost(noteText: note.text)
    }

    private func selectAndUploadFiles() {
        uploadVM.selectAndUploadFiles(
            servers: account.blossomServers,
            nsec: account.nsec,
            uploadToAll: account.uploadToAllServers,
            onURLReady: { url in
                if !note.text.isEmpty && !note.text.hasSuffix("\n") { note.text += "\n" }
                note.text += url
            },
            onError: { message in
                alertState.show(message, severity: .error)
            }
        )
    }

    private func performPost() {
        let finalNote = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let imetaTags = uploadVM.generateImetaTags()

        vm.post(
            noteText: finalNote,
            imetaTags: imetaTags,
            publishingService: publishingService,
            alerts: alertState
        ) {
            note.clear()
            uploadVM.clearAll()
        }
    }
}
