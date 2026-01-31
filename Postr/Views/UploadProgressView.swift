import SwiftUI

struct UploadProgressView: View {
    let progress: Double
    let isUploading: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                if isUploading {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                } else {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
        .onHover { hovering in
            if !isUploading {
                hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
            }
        }
        .help("Upload file")
    }
}
