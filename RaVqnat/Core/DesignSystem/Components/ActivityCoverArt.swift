import SwiftUI

/// Deterministic cover illustration for activities without a photo: a manga-style screentone
/// field on paper with the category symbol and its pink afterimages. The same activity always
/// gets the same composition.
struct ActivityCoverArt: View {
    let category: ActivityCategory
    let seed: UUID
    var imageURL: URL?

    var body: some View {
        ZStack {
            Theme.Palette.surface
            Halftone(pattern: category.pattern, seed: seed)
            GeometryReader { proxy in
                let rng = SeededRandom(seed: seed)
                let symbolSize = proxy.size.height * 0.46
                EchoSymbol(symbol: category.symbol, size: symbolSize, spacing: symbolSize * 0.14)
                    .position(x: proxy.size.width * rng.value(0, 0.58, 0.74), y: proxy.size.height * 0.54)
                Image(systemName: category.decorativeSymbols[Int(rng.value(1, 0, 4.99))])
                    .font(.system(size: proxy.size.height * 0.16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ink.opacity(0.85))
                    .rotationEffect(.degrees(rng.value(2, -14, 14)))
                    .position(x: proxy.size.width * rng.value(3, 0.14, 0.3), y: proxy.size.height * rng.value(4, 0.62, 0.78))
            }
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill().grayscale(0.15) }
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Screentone fills drawn with `Canvas`.
private struct Halftone: View {
    let pattern: HalftonePattern
    let seed: UUID

    var body: some View {
        Canvas { context, size in
            let ink = GraphicsContext.Shading.color(Theme.Palette.ink.opacity(0.22))
            let rng = SeededRandom(seed: seed)
            let spacing: CGFloat = 9
            switch pattern {
            case .dots, .gradientDots:
                // Dot radius fades across the frame, like a printed tone gradient.
                let angle = rng.value(6, 0, .pi * 2)
                var y: CGFloat = 0
                var row = 0
                while y < size.height + spacing {
                    var x: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                    while x < size.width + spacing {
                        let t = ((x / size.width) * cos(angle) + (y / size.height) * sin(angle) + 1) / 2
                        let r = pattern == .dots ? 1.6 * t + 0.3 : 2.6 * t * t + 0.2
                        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: ink)
                        x += spacing
                    }
                    y += spacing * 0.866
                    row += 1
                }
            case .diagonal:
                var path = Path()
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 7
                }
                context.stroke(path, with: ink, lineWidth: 1)
            case .grid:
                var path = Path()
                var x: CGFloat = 0
                while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += 14 }
                var y: CGFloat = 0
                while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += 14 }
                context.stroke(path, with: ink, lineWidth: 0.75)
            }
        }
        .mask(LinearGradient(colors: [.black, .black.opacity(0.15)], startPoint: .leading, endPoint: .trailing))
        .drawingGroup()
    }
}

/// Tiny deterministic hash-based generator so the same activity always gets the same art.
struct SeededRandom {
    let bytes: [UInt8]
    init(seed: UUID) {
        let u = seed.uuid
        bytes = [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7, u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
    }
    func value(_ index: Int, _ low: Double, _ high: Double) -> Double {
        let a = Double(bytes[index % 16]), b = Double(bytes[(index * 7 + 3) % 16])
        let unit = (a * 256 + b) / 65_535
        return low + (high - low) * unit
    }
}
