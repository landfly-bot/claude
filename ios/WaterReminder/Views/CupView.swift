import SwiftUI

/// 杯身里的水面，用一条正弦曲线做波浪
struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseline = rect.minY + amplitude
        path.move(to: CGPoint(x: rect.minX, y: baseline))

        var x = rect.minX
        while x <= rect.maxX {
            let relative = (x - rect.minX) / max(rect.width, 1)
            let y = baseline + sin(relative * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 会随进度涨落的水杯
struct CupView: View {
    let total: Int
    let goal: Int
    let progress: Double
    let percent: Int

    @State private var frontPhase: CGFloat = 0
    @State private var backPhase: CGFloat = .pi

    private let size = CGSize(width: 190, height: 232)

    private var cupShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 62,
            bottomTrailingRadius: 62,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    private var waterHeight: CGFloat {
        guard progress > 0 else { return 0 }
        return max(size.height * CGFloat(progress), 16)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            cupShape.fill(Theme.brand.opacity(0.06))

            ZStack(alignment: .bottom) {
                WaveShape(phase: backPhase, amplitude: 5)
                    .fill(Theme.brand.opacity(0.3))
                WaveShape(phase: frontPhase, amplitude: 7)
                    .fill(Theme.water)
            }
            .frame(height: waterHeight)
            .animation(.easeInOut(duration: 0.7), value: progress)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(cupShape)
        .overlay(cupShape.stroke(Theme.brand.opacity(0.25), lineWidth: 4))
        .overlay(info)
        .onAppear(perform: startWaves)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日已喝 \(total) 毫升，目标 \(goal) 毫升，完成 \(percent)%")
    }

    private var info: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(total)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("mL")
                    .font(.subheadline.weight(.medium))
            }
            Text("目标 \(goal) mL · \(percent)%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .shadow(color: Color(uiColor: .systemBackground).opacity(0.8), radius: 4)
    }

    private func startWaves() {
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
            frontPhase = .pi * 2
        }
        withAnimation(.linear(duration: 4.2).repeatForever(autoreverses: false)) {
            backPhase = .pi * 3
        }
    }
}

#Preview {
    CupView(total: 1200, goal: 2000, progress: 0.6, percent: 60)
        .padding()
}
