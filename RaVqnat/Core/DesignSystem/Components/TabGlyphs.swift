import SwiftUI

/// Custom tab icons drawn in the same language as the Home grid (`square.grid.2x2`):
/// separate rounded tiles with small gaps, outlined when inactive and filled when active.
struct TabGlyph: View {
    enum Kind { case map, messages }

    let kind: Kind
    let isFilled: Bool
    var size: CGFloat = 22

    var body: some View {
        let shape = shape(for: kind)
        // Both states stay in the hierarchy and crossfade in place, so nothing is left behind
        // when the icon moves while switching.
        ZStack {
            shape.stroke(style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))
                .opacity(isFilled ? 0 : 1)
            shape.fill()
                .opacity(isFilled ? 1 : 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func shape(for kind: Kind) -> AnyShape {
        switch kind {
        case .map: AnyShape(FoldedMapShape())
        case .messages: AnyShape(ConversationShape())
        }
    }
}

/// A fold-out map: three slanted panels (zig-zag folds) with small gaps, corners softly rounded.
struct FoldedMapShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.1)
        let gap = r.width * 0.07
        let panel = (r.width - gap * 2) / 3
        let slant = r.height * 0.14
        let radius = panel * 0.22
        var path = Path()
        for index in 0..<3 {
            let x0 = r.minX + CGFloat(index) * (panel + gap), x1 = x0 + panel
            // Alternate which side is raised so the panels zig-zag like a folded map.
            let raisedRight = index != 1
            let topLeft = CGPoint(x: x0, y: r.minY + (raisedRight ? slant : 0))
            let topRight = CGPoint(x: x1, y: r.minY + (raisedRight ? 0 : slant))
            let bottomRight = CGPoint(x: x1, y: r.maxY - (raisedRight ? slant : 0))
            let bottomLeft = CGPoint(x: x0, y: r.maxY - (raisedRight ? 0 : slant))
            path.addRoundedPolygon([topLeft, topRight, bottomRight, bottomLeft], radius: radius)
        }
        return path
    }
}

extension Path {
    /// Closed polygon with arc-rounded corners.
    mutating func addRoundedPolygon(_ points: [CGPoint], radius: CGFloat) {
        guard points.count > 2 else { return }
        let count = points.count
        let mid = { (a: CGPoint, b: CGPoint) in CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        move(to: mid(points[count - 1], points[0]))
        for index in 0..<count {
            let corner = points[index], next = points[(index + 1) % count]
            addArc(tangent1End: corner, tangent2End: next, radius: radius)
        }
        closeSubpath()
    }
}

/// A conversation: two staggered rounded speech tiles, each with a small tail.
struct ConversationShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.06
        let r = rect.insetBy(dx: inset, dy: inset)
        let gap = r.height * 0.12
        let bubbleHeight = (r.height - gap) / 2 - r.height * 0.06
        let bubbleWidth = r.width * 0.74
        let radius = bubbleHeight * 0.36
        let tail = bubbleHeight * 0.32
        var path = Path()

        // Incoming: top-left, tail at bottom-left.
        let top = CGRect(x: r.minX, y: r.minY, width: bubbleWidth, height: bubbleHeight)
        path.addRoundedRect(in: top, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        path.move(to: CGPoint(x: top.minX + radius * 0.6, y: top.maxY - 0.5))
        path.addLine(to: CGPoint(x: top.minX + radius * 0.3, y: top.maxY + tail))
        path.addLine(to: CGPoint(x: top.minX + radius * 1.6, y: top.maxY - 0.5))

        // Outgoing: bottom-right, tail at bottom-right.
        let bottom = CGRect(x: r.maxX - bubbleWidth, y: r.minY + bubbleHeight + gap, width: bubbleWidth, height: bubbleHeight)
        path.addRoundedRect(in: bottom, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        path.move(to: CGPoint(x: bottom.maxX - radius * 0.6, y: bottom.maxY - 0.5))
        path.addLine(to: CGPoint(x: bottom.maxX - radius * 0.3, y: bottom.maxY + tail))
        path.addLine(to: CGPoint(x: bottom.maxX - radius * 1.6, y: bottom.maxY - 0.5))
        return path
    }
}

/// A label whose letters arrive one after another — each rises, scales up and sharpens from a
/// blur with a small spring — while the label's width grows so the icon beside it glides sideways.
/// Under Reduce Motion the word simply appears.
struct RevealingLabel: View {
    let title: String
    let isRevealed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fullWidth: CGFloat = 0
    @State private var visibleCount = 0

    static let letterDelay: Duration = .milliseconds(40)

    private var characters: [Character] { Array(title) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                let shown = index < visibleCount
                Text(String(character))
                    .opacity(shown ? 1 : 0)
                    .blur(radius: shown ? 0 : 4)
                    .scaleEffect(shown ? 1 : 0.5, anchor: .bottom)
                    .offset(y: shown ? 0 : 8)
            }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .fixedSize()
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { fullWidth = $0 }
        // The width eases open over roughly the time the letters take, so the icon glides with them.
        .frame(width: isRevealed ? fullWidth : 0, alignment: .leading)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12 + 0.04 * Double(characters.count)), value: isRevealed)
        .task(id: isRevealed) { await play() }
        .accessibilityHidden(true)
    }

    private func play() async {
        guard isRevealed else {
            visibleCount = 0
            return
        }
        if reduceMotion {
            visibleCount = characters.count
            return
        }
        visibleCount = 0
        for count in 1...max(1, characters.count) {
            try? await Task.sleep(for: Self.letterDelay)
            if Task.isCancelled { return }
            withAnimation(.spring(duration: 0.32, bounce: 0.45)) { visibleCount = count }
        }
    }
}
