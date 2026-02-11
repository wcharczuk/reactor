import Foundation
import Metal
import CoreGraphics
import CoreText

/// Renders the TerminalBuffer to a Metal texture using CoreGraphics/CoreText
class TerminalRenderer {
    // Terminal dimensions in characters
    static let cols = 320
    static let rows = 96

    // Pixel dimensions of the terminal texture
    // Each character cell is 8×16 pixels for a clean retro look
    static let cellWidth = 8
    static let cellHeight = 16
    static let textureWidth = cols * cellWidth   // 2560
    static let textureHeight = rows * cellHeight // 1536

    private let device: MTLDevice
    private(set) var texture: MTLTexture!
    private var cgContext: CGContext!
    private var pixelData: UnsafeMutablePointer<UInt8>!
    private let bytesPerRow: Int
    private let font: CTFont
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
                    ctx.textPosition = CGPoint(x: px + 1, y: py + 3)
                    CTLineDraw(line, ctx)
                    ctx.restoreGState()
                }
            }
        }

        // Upload to Metal texture
        let region = MTLRegionMake2D(0, 0, TerminalRenderer.textureWidth, TerminalRenderer.textureHeight)
        texture.replace(region: region, mipmapLevel: 0,
                        withBytes: pixelData,
                        bytesPerRow: bytesPerRow)
    }

    private func cgColor(for color: TerminalColor) -> CGColor {
        let (r, g, b) = color.rgb
        return CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
    }

    deinit {
        pixelData?.deallocate()
    }
}
