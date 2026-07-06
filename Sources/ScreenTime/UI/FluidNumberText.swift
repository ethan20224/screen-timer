import SwiftUI

struct FluidNumberText: View {
    let text: String
    let font: Font
    var tracking: CGFloat = 0

    @State private var blurAmount: CGFloat = 0

    var body: some View {
        Text(text)
            .font(font)
            .tracking(tracking)
            .contentTransition(.numericText())
            .blur(radius: blurAmount)
            .animation(.easeOut(duration: 0.3), value: text)
            .onChange(of: text) { _, _ in
                blurAmount = 3
                withAnimation(.easeOut(duration: 0.3)) {
                    blurAmount = 0
                }
            }
    }
}
