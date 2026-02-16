import SwiftUI

struct ActionArcRing: View {
    let color: Color
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.34)
            .stroke(
                AngularGradient(colors: [color.opacity(0.2), color.opacity(0.95), color.opacity(0.2)], center: .center),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .rotationEffect(.degrees(spinning ? 450 : 90))
            .animation(.linear(duration: 1.05).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
            .onDisappear { spinning = false }
            .frame(width: 126, height: 126)
    }
}
