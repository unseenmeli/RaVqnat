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
        ZStack {
            if isFilled {
                shape.fill(style: FillStyle(eoFill: false))
            } else {
                shape.stroke(style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))
            }
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

/// A label that reveals its letters left to right by growing from zero width, so the icon next to
/// it glides sideways as the word types itself in.
struct RevealingLabel: View {
    let key: LocalizedStringKey
    let isRevealed: Bool
    @State private var fullWidth: CGFloat = 0

    var body: some View {
        Text(key)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { fullWidth = $0 }
            .frame(width: isRevealed ? fullWidth : 0, alignment: .leading)
            .mask(alignment: .leading) {
                // Soft trailing edge while the word is still appearing.
                LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.8),
                                       .init(color: .black.opacity(isRevealed ? 1 : 0), location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            }
            .opacity(isRevealed ? 1 : 0)
            .accessibilityHidden(true)
    }
}
