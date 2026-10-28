import SwiftUI

/// Deterministic, category-tinted cover illustration composed from SF Symbols.
/// Used when an activity has no uploaded photo, so the feed stays beautiful without stock imagery.
struct ActivityCoverArt: View {
    let category: ActivityCategory
    let seed: UUID
    var imageURL: URL?

    var body: some View {
        ZStack {
            category.softTint
            GeometryReader { proxy in
                let size = proxy.size
                let symbols = category.decorativeSymbols
                let rng = SeededRandom(seed: seed)
                ZStack {
                    Circle()
                        .fill(category.tint.opacity(0.14))
                        .frame(width: size.height * 1.3)
                        .position(x: size.width * rng.value(0, 0.25, 0.85), y: size.height * rng.value(1, 0.1, 0.5))
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(category.tint.opacity(0.10))
                        .frame(width: size.height * 0.9, height: size.height * 0.9)
                        .rotationEffect(.degrees(rng.value(2, -25, 25)))
                        .position(x: size.width * rng.value(3, 0.1, 0.4), y: size.height * rng.value(4, 0.6, 1.0))
                    ForEach(0..<4, id: \.self) { index in
                        Image(systemName: symbols[(index + Int(rng.value(5, 0, 5))) % symbols.count])
                            .font(.system(size: size.height * rng.value(10 + index, 0.16, 0.26), weight: .semibold))
                            .foregroundStyle(category.tint.opacity(0.35))
                            .rotationEffect(.degrees(rng.value(20 + index, -18, 18)))
                            .position(x: size.width * (0.18 + Double(index) * 0.22) + rng.value(30 + index, -14, 14),
                                      y: size.height * rng.value(40 + index, 0.22, 0.78))
                    }
                    Image(systemName: category.symbol)
                        .font(.system(size: size.height * 0.42, weight: .bold))
                        .foregroundStyle(category.tint)
                        .position(x: size.width * 0.72, y: size.height * 0.52)
                }
            }
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Tiny deterministic hash-based generator so the same activity always gets the same art.
private struct SeededRandom {
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
