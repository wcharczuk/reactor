import Foundation
import CoreGraphics
import CoreText

/// Renders a raster cross-section diagram of the CANDU-6 calandria into the terminal texture.
struct CoreDiagramRenderer {

    static func draw(data: CoreDiagramData, ctx: CGContext,
                     cellWidth: Int, cellHeight: Int, textureHeight: Int) {
        // Convert grid region to pixel rect (CG Y=0 at bottom)
        let pxOriginX = CGFloat(data.gridX * cellWidth)
        let pxOriginY = CGFloat(textureHeight - (data.gridY + data.gridHeight) * cellHeight)
        let pxWidth = CGFloat(data.gridWidth * cellWidth)
        let pxHeight = CGFloat(data.gridHeight * cellHeight)
        let rect = CGRect(x: pxOriginX, y: pxOriginY, width: pxWidth, height: pxHeight)

        ctx.saveGState()
        ctx.clip(to: [rect])

        // Diagram center and radius
        let cx = rect.midX
        let cy = rect.midY
        let radius = min(pxWidth, pxHeight) * 0.46

        // Colors
        let green = CGColor(red: 0.0, green: 0.82, blue: 0.0, alpha: 1.0)
        let brightGreen = CGColor(red: 0.1, green: 1.0, blue: 0.1, alpha: 1.0)
        let dimGreen = CGColor(red: 0.0, green: 0.35, blue: 0.0, alpha: 1.0)
        let veryDimGreen = CGColor(red: 0.0, green: 0.18, blue: 0.0, alpha: 1.0)
        let red = CGColor(red: 1.0, green: 0.15, blue: 0.1, alpha: 1.0)
        let amber = CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)

        // 1. Fuel channel lattice dots (clipped to calandria circle)
        ctx.saveGState()
        let circlePath = CGMutablePath()
        circlePath.addEllipse(in: CGRect(x: cx - radius, y: cy - radius,
                                          width: radius * 2, height: radius * 2))
        ctx.addPath(circlePath)
        ctx.clip()

        let dotRadius: CGFloat = 2.0
        let dotSpacing: CGFloat = 18.0
        let gridExtent = radius + dotSpacing
        ctx.setFillColor(veryDimGreen)
        var dy = -gridExtent
        while dy <= gridExtent {
            var dx = -gridExtent
            while dx <= gridExtent {
                let dotX = cx + dx
                let dotY = cy + dy
                let dist = sqrt(dx * dx + dy * dy)
                if dist < radius - 6 {
                    ctx.fillEllipse(in: CGRect(x: dotX - dotRadius, y: dotY - dotRadius,
                                               width: dotRadius * 2, height: dotRadius * 2))
                }
                dx += dotSpacing
            }
            dy += dotSpacing
        }
        ctx.restoreGState()

        // 2. Calandria shell circle
        ctx.setStrokeColor(green)
        ctx.setLineWidth(2.0)
        ctx.strokeEllipse(in: CGRect(x: cx - radius, y: cy - radius,
                                      width: radius * 2, height: radius * 2))

        // 3. Zone controllers (6 tall narrow rectangles)
        let zoneWidth: CGFloat = 16.0
        let zoneHeight: CGFloat = radius * 1.2
        // Z1-Z3 in upper half, Z4-Z6 in lower half
        let zoneXPositions: [CGFloat] = [-0.55, 0.0, 0.55, -0.55, 0.0, 0.55]
        let zoneYPositions: [CGFloat] = [0.32, 0.32, 0.32, -0.32, -0.32, -0.32]

        let labelFont = CTFontCreateWithName("Menlo" as CFString, 10, nil)

        for i in 0..<6 {
            let zx = cx + zoneXPositions[i] * radius - zoneWidth / 2
            let zy = cy + zoneYPositions[i] * radius - zoneHeight / 2
            let zoneRect = CGRect(x: zx, y: zy, width: zoneWidth, height: zoneHeight)

            // Outline
            ctx.setStrokeColor(dimGreen)
            ctx.setLineWidth(1.0)
            ctx.stroke(zoneRect)

            // Fill from bottom based on fill percentage
            let fill = max(0, min(data.zoneFills[i], 100.0)) / 100.0
            let fillHeight = zoneHeight * CGFloat(fill)
            let fillRect = CGRect(x: zx + 1, y: zy + 1,
                                  width: zoneWidth - 2, height: fillHeight - 1)
            if fillHeight > 1 {
                ctx.setFillColor(dimGreen)
                ctx.fill(fillRect)
            }

            // Label
            let label = "Z\(i + 1)"
            drawLabel(ctx: ctx, text: label, x: zx + zoneWidth / 2, y: zy - 12,
                      font: labelFont, color: dimGreen)
        }

        // 4. Adjuster rods (A-D) — bars from the top of the calandria
        let adjXOffsets: [CGFloat] = [-0.30, 0.30, -0.30, 0.30]
        let adjYSide: [CGFloat] = [1.0, 1.0, -1.0, -1.0] // top pair, bottom pair
        let adjNames = ["A", "B", "C", "D"]
        let rodWidth: CGFloat = 8.0
        let maxRodLength = radius * 0.85

        for i in 0..<4 {
            let pos = max(0, min(data.adjusterPositions[i], 1.0))
            let rodLength = maxRodLength * CGFloat(pos)
            let rx = cx + adjXOffsets[i] * radius - rodWidth / 2

            let rodColor = pos > 0.5 ? brightGreen : dimGreen

            if adjYSide[i] > 0 {
                // Top rods: extend downward from top of calandria
                let ry = cy + radius - 4 - rodLength
                let rodRect = CGRect(x: rx, y: ry, width: rodWidth, height: rodLength)
                ctx.setFillColor(rodColor)
                ctx.fill(rodRect)

                // Label above
                drawLabel(ctx: ctx, text: adjNames[i], x: rx + rodWidth / 2,
                          y: cy + radius + 6, font: labelFont, color: green)
            } else {
                // Bottom rods: extend upward from bottom of calandria
                let ry = cy - radius + 4
                let rodRect = CGRect(x: rx, y: ry, width: rodWidth, height: rodLength)
                ctx.setFillColor(rodColor)
                ctx.fill(rodRect)

                // Label below
                drawLabel(ctx: ctx, text: adjNames[i], x: rx + rodWidth / 2,
                          y: cy - radius - 16, font: labelFont, color: green)
            }
        }

        // 5. MCAs (2) — centered, wider bars, distinct color
        let mcaXOffsets: [CGFloat] = [-0.15, 0.15]
        let mcaWidth: CGFloat = 12.0

        for i in 0..<2 {
            let pos = max(0, min(data.mcaPositions[i], 1.0))
            let rodLength = maxRodLength * CGFloat(pos)
            let mx = cx + mcaXOffsets[i] * radius - mcaWidth / 2

            let mcaColor = pos > 0.5 ? amber : CGColor(red: 0.5, green: 0.25, blue: 0.0, alpha: 1.0)

            // MCAs enter from top
            let my = cy + radius - 4 - rodLength
            let mcaRect = CGRect(x: mx, y: my, width: mcaWidth, height: rodLength)
            ctx.setFillColor(mcaColor)
            ctx.fill(mcaRect)

            // Label
            let label = "M\(i + 1)"
            drawLabel(ctx: ctx, text: label, x: mx + mcaWidth / 2,
                      y: cy + radius + 18, font: labelFont, color: amber)
        }

        // 6. Shutoff rod indicators — row of small squares across bottom of calandria
        let sorCount = 28
        let sorSize: CGFloat = 8.0
        let sorSpacing: CGFloat = 2.0
        let totalSorWidth = CGFloat(sorCount) * sorSize + CGFloat(sorCount - 1) * sorSpacing
        let sorStartX = cx - totalSorWidth / 2
        let sorY = cy - radius * 0.7

        let sorInserted = data.shutoffInsertion > 0.5
        let sorColor = sorInserted ? red : brightGreen

        for s in 0..<sorCount {
            let sx = sorStartX + CGFloat(s) * (sorSize + sorSpacing)
            let sorRect = CGRect(x: sx, y: sorY, width: sorSize, height: sorSize)

            if data.scramActive {
                // Animated: fill proportional to insertion
                let insertFraction = data.shutoffInsertion
                if insertFraction > 0.1 {
                    ctx.setFillColor(red)
                } else {
                    ctx.setFillColor(brightGreen)
                }
                ctx.fill(sorRect)
            } else {
                ctx.setFillColor(sorColor)
                ctx.fill(sorRect)
            }
        }

        // SOR label
        drawLabel(ctx: ctx, text: "SOR", x: cx, y: sorY - 14, font: labelFont,
                  color: sorInserted ? red : dimGreen)

        // Title label
        let titleFont = CTFontCreateWithName("Menlo" as CFString, 12, nil)
        drawLabel(ctx: ctx, text: "CALANDRIA CROSS-SECTION", x: cx,
                  y: rect.maxY - 14, font: titleFont, color: green)

        ctx.restoreGState()
    }

    /// Draw a compact calandria cross-section as a tile grid (Chernobyl control room style).
    /// Each tile is a fuel channel indicator, colored by zone fill level.
    /// Rod positions shown as distinct-colored tiles. SOR as central indicator.
    static func drawCompact(data: CoreDiagramData, ctx: CGContext,
                            cellWidth: Int, cellHeight: Int, textureHeight: Int) {
        let pxOriginX = CGFloat(data.gridX * cellWidth)
        let pxOriginY = CGFloat(textureHeight - (data.gridY + data.gridHeight) * cellHeight)
        let pxWidth = CGFloat(data.gridWidth * cellWidth)
        let pxHeight = CGFloat(data.gridHeight * cellHeight)
        let rect = CGRect(x: pxOriginX, y: pxOriginY, width: pxWidth, height: pxHeight)

        ctx.saveGState()
        ctx.clip(to: [rect])

        let cx = rect.midX
        let cy = rect.midY
        let radius = min(pxWidth, pxHeight) * 0.45

        // (Colors are computed per-tile based on zone fill and rod state)

        // Tile grid parameters
        let tileSize: CGFloat = 8.0
        let tileGap: CGFloat = 2.5
        let tileStep = tileSize + tileGap
        let coreRadius = radius - 4

        // Rod tile positions (normalized by radius)
        // A,B top pair; C,D bottom pair
        let adjNorm: [(x: CGFloat, y: CGFloat)] = [
            (-0.32, 0.38), (0.32, 0.38),
            (-0.32, -0.38), (0.32, -0.38),
        ]
        let mcaNorm: [(x: CGFloat, y: CGFloat)] = [
            (-0.15, 0.12), (0.15, 0.12),
        ]
        let rodHitRadius = tileStep * 0.7

        // Shutoff rod positions (normalized) — 12 positions approximating 28 real SORs
        // Distributed across the core in a spread pattern
        let sorNorm: [(x: CGFloat, y: CGFloat)] = [
            (-0.55, 0.55), (0.0, 0.60), (0.55, 0.55),
            (-0.65, 0.15), (-0.20, 0.20), (0.20, 0.20), (0.65, 0.15),
            (-0.65, -0.15), (-0.20, -0.20), (0.20, -0.20), (0.65, -0.15),
            (-0.55, -0.55), (0.0, -0.60), (0.55, -0.55),
        ]

        // 1. Tile grid — each tile is a fuel channel indicator
        var dy = -coreRadius
        while dy <= coreRadius {
            var dx = -coreRadius
            while dx <= coreRadius {
                let dist = sqrt(dx * dx + dy * dy)
                if dist < coreRadius {
                    // Zone mapping: 3 cols × 2 rows
                    // Z1-Z3 top (CG Y-up: dy > 0), Z4-Z6 bottom
                    let col: Int
                    if dx < -radius * 0.33 { col = 0 }
                    else if dx > radius * 0.33 { col = 2 }
                    else { col = 1 }
                    let row = dy > 0 ? 0 : 1
                    let zoneIdx = row * 3 + col

                    let fill = max(0, min(data.zoneFills[zoneIdx], 100.0)) / 100.0
                    // Brightness: low fill = bright (reactive), high fill = dim (dampened)
                    let baseG = CGFloat(0.12 + (1.0 - fill) * 0.58)
                    var tileR: CGFloat = 0
                    var tileG: CGFloat = baseG
                    var tileB: CGFloat = 0

                    // Check shutoff rod proximity → red when inserted
                    let sorInsertion = CGFloat(max(0, min(data.shutoffInsertion, 1.0)))
                    if sorInsertion > 0.05 || data.scramActive {
                        for sor in sorNorm {
                            let rdx = dx - sor.x * radius
                            let rdy = dy - sor.y * radius
                            if sqrt(rdx * rdx + rdy * rdy) < rodHitRadius {
                                let intensity = CGFloat(0.30 + sorInsertion * 0.70)
                                tileR = intensity
                                tileG = intensity * 0.08
                                tileB = 0
                            }
                        }
                    }

                    // Check adjuster rod proximity → cyan-green tint
                    for i in 0..<4 {
                        let rdx = dx - adjNorm[i].x * radius
                        let rdy = dy - adjNorm[i].y * radius
                        if sqrt(rdx * rdx + rdy * rdy) < rodHitRadius {
                            let pos = CGFloat(max(0, min(data.adjusterPositions[i], 1.0)))
                            let intensity = CGFloat(0.20 + pos * 0.60)
                            tileR = 0
                            tileG = intensity
                            tileB = intensity * 0.7
                        }
                    }

                    // Check MCA proximity → amber tint
                    for i in 0..<2 {
                        let rdx = dx - mcaNorm[i].x * radius
                        let rdy = dy - mcaNorm[i].y * radius
                        if sqrt(rdx * rdx + rdy * rdy) < rodHitRadius {
                            let pos = CGFloat(max(0, min(data.mcaPositions[i], 1.0)))
                            let intensity = CGFloat(0.20 + pos * 0.60)
                            tileR = intensity
                            tileG = intensity * 0.5
                            tileB = 0
                        }
                    }

                    let tileX = cx + dx - tileSize / 2
                    let tileY = cy + dy - tileSize / 2
                    ctx.setFillColor(CGColor(red: tileR, green: tileG, blue: tileB, alpha: 1.0))
                    ctx.fill(CGRect(x: tileX, y: tileY, width: tileSize, height: tileSize))
                }
                dx += tileStep
            }
            dy += tileStep
        }

        ctx.restoreGState()
    }

    /// Draw a centered label at the given position.
    private static func drawLabel(ctx: CGContext, text: String, x: CGFloat, y: CGFloat,
                                   font: CTFont, color: CGColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        let textX = x - bounds.width / 2

        ctx.saveGState()
        ctx.textPosition = CGPoint(x: textX, y: y)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
