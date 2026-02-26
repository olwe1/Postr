import SwiftUI

extension View {
    func handCursor() -> some View {
        self.onHover { hovering in
            hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
        }
    }
}
