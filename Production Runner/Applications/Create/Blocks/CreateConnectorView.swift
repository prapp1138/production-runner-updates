import SwiftUI

// MARK: - Connector View
struct CreateConnectorView: View {
    let connector: CreateConnectorModel
    let blocks: [CreateBlockModel]
    let canvasOffset: CGPoint
    let canvasScale: CGFloat
    let geometrySize: CGSize

    @State private var isHovered: Bool = false

    private var sourceBlock: CreateBlockModel? {
        blocks.first { $0.id == connector.sourceBlockID }
    }

    private var targetBlock: CreateBlockModel? {
        blocks.first { $0.id == connector.targetBlockID }
    }

    var body: some View {
        if let source = sourceBlock, let target = targetBlock {
            Canvas { context, size in
                let startPoint = canvasToScreen(blockCenter(source), in: size)
                let endPoint = canvasToScreen(blockCenter(target), in: size)

                // Offset start and end points to block edges
                let (edgeStart, edgeEnd) = calculateEdgePoints(
                    from: startPoint,
                    to: endPoint,
                    sourceSize: CGSize(width: source.width * canvasScale, height: source.height * canvasScale),
                    targetSize: CGSize(width: target.width * canvasScale, height: target.height * canvasScale)
                )

                var path = Path()
                path.move(to: edgeStart)

                // Draw based on control points or straight line
                if connector.controlPoints.isEmpty {
                    path.addLine(to: edgeEnd)
                } else {
                    // Bezier curve through control points
                    let scaledControlPoints = connector.controlPoints.map { point in
                        canvasToScreen(point, in: size)
                    }
                    if scaledControlPoints.count == 1 {
                        path.addQuadCurve(to: edgeEnd, control: scaledControlPoints[0])
                    } else if scaledControlPoints.count >= 2 {
                        path.addCurve(to: edgeEnd, control1: scaledControlPoints[0], control2: scaledControlPoints[1])
                    }
                }

                // Line style
                var strokeStyle = StrokeStyle(lineWidth: connector.lineWidth * canvasScale)
                switch connector.lineStyle {
                case .dashed:
                    strokeStyle.dash = [8, 4]
                case .dotted:
                    strokeStyle.dash = [2, 4]
                case .solid:
                    break
                }

                // Draw the line
                let lineColor = Color(createHex: connector.colorHex) ?? .black
                context.stroke(path, with: .color(lineColor), style: strokeStyle)

                // Draw arrow head
                if connector.arrowHead != .none {
                    let arrowPath = arrowHeadPath(at: edgeEnd, from: edgeStart, style: connector.arrowHead)
                    context.fill(arrowPath, with: .color(lineColor))
                }
            }
        }
    }

    // MARK: - Coordinate Conversion
    private func canvasToScreen(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (point.x - canvasOffset.x) * canvasScale + size.width / 2,
            y: (point.y - canvasOffset.y) * canvasScale + size.height / 2
        )
    }

    private func blockCenter(_ block: CreateBlockModel) -> CGPoint {
        CGPoint(
            x: block.positionX + block.width / 2,
            y: block.positionY + block.height / 2
        )
    }

    // MARK: - Edge Calculation
    private func calculateEdgePoints(
        from start: CGPoint,
        to end: CGPoint,
        sourceSize: CGSize,
        targetSize: CGSize
    ) -> (CGPoint, CGPoint) {
        let direction = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let length = sqrt(direction.x * direction.x + direction.y * direction.y)

        guard length > 0 else { return (start, end) }

        let normalized = CGPoint(x: direction.x / length, y: direction.y / length)

        // Calculate intersection with source block edge
        let sourceRadius = min(sourceSize.width, sourceSize.height) / 2
        let edgeStart = CGPoint(
            x: start.x + normalized.x * sourceRadius,
            y: start.y + normalized.y * sourceRadius
        )

        // Calculate intersection with target block edge
        let targetRadius = min(targetSize.width, targetSize.height) / 2
        let edgeEnd = CGPoint(
            x: end.x - normalized.x * targetRadius,
            y: end.y - normalized.y * targetRadius
        )

        return (edgeStart, edgeEnd)
    }

    // MARK: - Arrow Head
    private func arrowHeadPath(at point: CGPoint, from origin: CGPoint, style: ConnectorArrowHead) -> Path {
        let direction = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        let length = sqrt(direction.x * direction.x + direction.y * direction.y)

        guard length > 0 else { return Path() }

        let normalized = CGPoint(x: direction.x / length, y: direction.y / length)
        let perpendicular = CGPoint(x: -normalized.y, y: normalized.x)

        let arrowSize: CGFloat = 10 * canvasScale

        switch style {
        case .arrow:
            var path = Path()
            path.move(to: point)
            path.addLine(to: CGPoint(
                x: point.x - arrowSize * normalized.x + arrowSize * 0.5 * perpendicular.x,
                y: point.y - arrowSize * normalized.y + arrowSize * 0.5 * perpendicular.y
            ))
            path.addLine(to: CGPoint(
                x: point.x - arrowSize * normalized.x - arrowSize * 0.5 * perpendicular.x,
                y: point.y - arrowSize * normalized.y - arrowSize * 0.5 * perpendicular.y
            ))
            path.closeSubpath()
            return path

        case .circle:
            let radius = arrowSize * 0.4
            let center = CGPoint(
                x: point.x - radius * normalized.x,
                y: point.y - radius * normalized.y
            )
            var path = Path()
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            return path

        case .none:
            return Path()
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CreateConnectorView_Previews: PreviewProvider {
    static var previews: some View {
        let blocks = [
            CreateBlockModel(id: UUID(), blockType: .note, positionX: 100, positionY: 100),
            CreateBlockModel(id: UUID(), blockType: .note, positionX: 300, positionY: 200)
        ]

        let connector = CreateConnectorModel(
            sourceBlockID: blocks[0].id,
            targetBlockID: blocks[1].id
        )

        CreateConnectorView(
            connector: connector,
            blocks: blocks,
            canvasOffset: .zero,
            canvasScale: 1.0,
            geometrySize: CGSize(width: 500, height: 400)
        )
        .frame(width: 500, height: 400)
        .background(Color.gray.opacity(0.1))
    }
}
#endif
