import Foundation
import Metal
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

/// Renders the TerminalBuffer to a Metal texture using CoreGraphics/CoreText
class TerminalRenderer {
    // Terminal dimensions in characters
    static let cols = 213
    static let rows = 70

    // Pixel dimensions of the terminal texture
    // Each character cell is 12×22 pixels for readable text on retina displays
    static let cellWidth = 12
    static let cellHeight = 22
    static let textureWidth = cols * cellWidth   // 2560
    static let textureHeight = rows * cellHeight // 1536

    private let device: MTLDevice
    private(set) var texture: MTLTexture!
    private var cgContext: CGContext!
    private var pixelData: UnsafeMutablePointer<UInt8>!
    private let bytesPerRow: Int
    private let font: CTFont
    private let fontDescent: CGFloat
    private let compactFont: CTFont
    private let compactFontDescent: CGFloat
    private let colorSpace: CGColorSpace

    init(device: MTLDevice) {
        self.device = device
        self.colorSpace = CGColorSpaceCreateDeviceRGB()
        self.bytesPerRow = TerminalRenderer.textureWidth * 4

        // Create a monospace font
        // Try to use Menlo or Monaco, fall back to Courier
        if let menlo = CTFontCreateWithName("Menlo" as CFString, CGFloat(TerminalRenderer.cellHeight - 2), nil) as CTFont? {
            self.font = menlo
        } else {
            self.font = CTFontCreateWithName("Courier" as CFString, CGFloat(TerminalRenderer.cellHeight - 2), nil)
        }
        // Cache the font descent so descenders (g, y, p, etc.) are fully visible
        self.fontDescent = ceil(CTFontGetDescent(font))

        // Compact font for hint text (~60% of normal size, fits more chars per cell)
        let compactSize = CGFloat(TerminalRenderer.cellHeight - 2) * 0.6
        if let menloCompact = CTFontCreateWithName("Menlo" as CFString, compactSize, nil) as CTFont? {
            self.compactFont = menloCompact
        } else {
            self.compactFont = CTFontCreateWithName("Courier" as CFString, compactSize, nil)
        }
        self.compactFontDescent = ceil(CTFontGetDescent(compactFont))

        setupTexture()
        setupContext()
    }

    private func setupTexture() {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: TerminalRenderer.textureWidth,
            height: TerminalRenderer.textureHeight,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .managed
        texture = device.makeTexture(descriptor: descriptor)
    }

    private func setupContext() {
        let totalBytes = bytesPerRow * TerminalRenderer.textureHeight
        pixelData = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
        pixelData.initialize(repeating: 0, count: totalBytes)

        cgContext = CGContext(
            data: pixelData,
            width: TerminalRenderer.textureWidth,
            height: TerminalRenderer.textureHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// Render the terminal buffer contents to the Metal texture
    func render(buffer: TerminalBuffer) {
        guard let ctx = cgContext else { return }

        // Clear to near-black
        ctx.setFillColor(CGColor(red: 0.0, green: 0.01, blue: 0.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0,
                        width: TerminalRenderer.textureWidth,
                        height: TerminalRenderer.textureHeight))

        // Render each character cell
        let cellW = CGFloat(TerminalRenderer.cellWidth)
        let cellH = CGFloat(TerminalRenderer.cellHeight)

        for row in 0..<TerminalBuffer.height {
            for col in 0..<TerminalBuffer.width {
                guard let cell = buffer.cell(x: col, y: row) else { continue }

                // Skip space characters with default background for performance
                if cell.character == " " && cell.backgroundColor == .background {
                    continue
                }

                // Calculate pixel position (CoreGraphics has Y=0 at bottom)
                let px = CGFloat(col) * cellW
                let py = CGFloat(TerminalRenderer.textureHeight) - CGFloat(row + 1) * cellH

                // Draw background if not default
                if cell.backgroundColor != .background {
                    let bgColor = cgColor(for: cell.backgroundColor)
                    ctx.setFillColor(bgColor)
                    ctx.fill(CGRect(x: px, y: py, width: cellW, height: cellH))
                }

                // Draw character
                if cell.character != " " {
                    let fgColor = cgColor(for: cell.foregroundColor)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: fgColor
                    ]
                    let str = NSAttributedString(string: String(cell.character), attributes: attrs)
                    let line = CTLineCreateWithAttributedString(str)

                    ctx.saveGState()
                    ctx.textPosition = CGPoint(x: px + 1, y: py + fontDescent)
                    CTLineDraw(line, ctx)
                    ctx.restoreGState()
                }
            }
        }

        // Render raster core diagram if present
        if let diagramData = buffer.coreDiagram {
            CoreDiagramRenderer.draw(data: diagramData, ctx: ctx,
                                     cellWidth: TerminalRenderer.cellWidth,
                                     cellHeight: TerminalRenderer.cellHeight,
                                     textureHeight: TerminalRenderer.textureHeight)
        }

        // Render compact overview diagram if present
        if let overviewData = buffer.overviewDiagram {
            CoreDiagramRenderer.drawCompact(data: overviewData, ctx: ctx,
                                            cellWidth: TerminalRenderer.cellWidth,
                                            cellHeight: TerminalRenderer.cellHeight,
                                            textureHeight: TerminalRenderer.textureHeight)
        }

        // Render compact text strings (smaller font, more chars per line)
        for entry in buffer.compactStrings {
            let px = CGFloat(entry.x) * cellW
            let py = CGFloat(TerminalRenderer.textureHeight) - CGFloat(entry.y + 1) * cellH
            let fgColor = cgColor(for: entry.fg)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: compactFont,
                .foregroundColor: fgColor
            ]
            let str = NSAttributedString(string: entry.text, attributes: attrs)
            let line = CTLineCreateWithAttributedString(str)

            ctx.saveGState()
            ctx.textPosition = CGPoint(x: px + 1, y: py + compactFontDescent)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }

        // Upload to Metal texture
        let region = MTLRegionMake2D(0, 0, TerminalRenderer.textureWidth, TerminalRenderer.textureHeight)
        texture.replace(region: region, mipmapLevel: 0,
                        withBytes: pixelData,
                        bytesPerRow: bytesPerRow)
    }

    func cgColor(for color: TerminalColor) -> CGColor {
        let (r, g, b) = color.rgb
        return CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
    }

    /// Capture the current terminal texture as PNG data.
    func capturePNG() -> Data? {
        guard let image = cgContext?.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    deinit {
        pixelData?.deallocate()
    }
}
