import AppKit
import SwiftUI

struct DonateView: View {
    @StateObject private var vm = DonateViewModel()
    private let npubURL = URL(
        string:
            "https://nosta.me/npub18eanjnh87flqaz3dvrvusga6dq35sm6prqh7l73uuu6zdksul8jsvkcn5r"
    )!

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Link("Follow me on nostr", destination: npubURL)
                .onHover { hovering in
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                .font(.headline)
            Text("⚡️ Or zap me sats ⚡️")
            Image("donationQrCode")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 200)
                .accessibility(
                    label: Text("bitcoin lightning donation address")
                )
            
            Button(action: vm.copyLnAddress) {
                Text(vm.showCopied ? "Copied" : vm.lnAddress)
                    .foregroundColor(vm.showCopied ? .green : .primary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hovering && !vm.showCopied ? NSCursor.pointingHand.push() : NSCursor.pop()
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(16)
    }
}
