import SwiftUI

/// Cover for activities without a photo: a soft monochrome field with the category symbol set
/// large and cropped by the frame, positioned deterministically per activity.
struct ActivityCoverArt: View {
    let category: ActivityCategory
    let seed: UUID
    var imageURL: URL?

    var body: some View {
        ZStack {
            category.softTint
            GeometryReader { proxy in
                let rng = SeededRandom(seed: seed)
                // Oversized, cropped watermark…
                Image(systemName: category.symbol)
                    .font(.system(size: proxy.size.height * 1.1, weight: .bold))
                    .foregroundStyle(category.tint.opacity(0.12))
                    .rotationEffect(.degrees(rng.value(0, -14, 14)))
                    .position(x: proxy.size.width * rng.value(1, 0.62, 0.85), y: proxy.size.height * rng.value(2, 0.55, 0.75))
                // …and a crisp mark.
                Image(systemName: category.symbol)
                    .font(.system(size: min(proxy.size.height * 0.26, 64), weight: .semibold))
                    .foregroundStyle(category.tint)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
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
