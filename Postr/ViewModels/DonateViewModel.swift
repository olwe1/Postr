import AppKit
import Foundation
import SwiftUI

final class DonateViewModel: ObservableObject {
    @Published var showCopied = false
    let lnAddress = "salmonparrot19@primal.net"

    func copyLnAddress() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lnAddress, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) { self.showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.2)) { self.showCopied = false }
        }
    }
}