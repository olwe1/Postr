import NostrSDK
import SwiftUI

struct PostingView: View {
    @EnvironmentObject var session: SessionService
    @EnvironmentObject var alertState: AlertState
    @StateObject private var note = DraftViewModel(storageKey: "draft_note")
    @StateObject private var vm = PostingViewModel()
    @State private var showDonatePopover = false

    var body: some View {
        Group {
            HStack {
                Text("Note:")
                    .font(.headline)

                Spacer()

                AlertView()
            }
            TextEditor(text: $note.text)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3))
                )

            HStack {
                Spacer()

                Button(action: {
                    vm.post(noteText: note.text, session: session, alerts: alertState) {
                        note.clear()
                    }
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(vm.isPosting ? "Posting…" : "Post")
                    }
                }
                .disabled(!vm.canPost(noteText: note.text))
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .onHover { hovering in
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }

                Spacer()

                Button(action: { showDonatePopover.toggle() }) {
                    Text("⚡️")
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                .popover(isPresented: $showDonatePopover) {
                    DonateView()
                }
            }
        }
        .onChange(of: showDonatePopover) { newValue in
            if newValue == false {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onDisappear {
            note.saveNow()
        }
    }
}
