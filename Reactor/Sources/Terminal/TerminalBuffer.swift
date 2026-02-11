import Foundation

// MARK: - Terminal Color

/// Color definitions for the green phosphor CRT terminal theme.
enum TerminalColor: Equatable, Hashable {
    case normal      // Standard green text
    case bright      // Bright green (highlighted)
    case dim         // Dim green (secondary info)
    case alarm       // Amber/red for alarms
    case input       // Slightly different green for input area
    case background  // Near-black with slight green tint

    /// RGB components as a tuple of Floats (0.0 - 1.0).
    var rgb: (r: Float, g: Float, b: Float) {
        switch self {
        case .normal:     return (0.0, 0.7, 0.0)
        case .bright:     return (0.0, 1.0, 0.0)
        case .dim:        return (0.0, 0.35, 0.0)
        case .alarm:      return (1.0, 0.3, 0.0)
        case .input:      return (0.0, 0.9, 0.2)
        case .background: return (0.0, 0.02, 0.0)
        }
    }
}

// MARK: - Terminal Cell

/// A single character cell in the terminal grid.
struct TerminalCell {
    var character: Character
    var foregroundColor: TerminalColor
    var backgroundColor: TerminalColor

    static let blank = TerminalCell(
        character: " ",
        foregroundColor: .normal,
        backgroundColor: .background
    )
}

// MARK: - Terminal Buffer

/// A 320x96 character cell grid that serves as the virtual CRT screen buffer.
/// Cells are stored in a flat array in row-major order for performance.
final class TerminalBuffer {

    // MARK: Constants

    static let width: Int = 320
    static let height: Int = 96

    // MARK: Storage

    /// Flat array of cells, row-major: index = y * width + x
    private(set) var cells: [TerminalCell]

    // MARK: Init

    init() {
        cells = [TerminalCell](repeating: .blank, count: TerminalBuffer.width * TerminalBuffer.height)
    }

    // MARK: Indexing

    /// Returns the flat index for (x, y). Returns nil if out of bounds.
    @inline(__always)
    private func index(x: Int, y: Int) -> Int? {
        guard x >= 0, x < TerminalBuffer.width, y >= 0, y < TerminalBuffer.height else {
            return nil
        }
        return y * TerminalBuffer.width + x
    }

    // MARK: Cell Access

    /// Read a cell at the given position.
    func cell(x: Int, y: Int) -> TerminalCell? {
        guard let idx = index(x: x, y: y) else { return nil }
        return cells[idx]
    }

    // MARK: Clear

    /// Fill the entire buffer with blank cells.
    func clear() {
        cells = [TerminalCell](repeating: .blank, count: TerminalBuffer.width * TerminalBuffer.height)
    }

    // MARK: Put Character

    /// Set a single cell at (x, y).
    func putChar(x: Int, y: Int, char: Character,
                 fg: TerminalColor = .normal, bg: TerminalColor = .background) {
        guard let idx = index(x: x, y: y) else { return }
        cells[idx] = TerminalCell(character: char, foregroundColor: fg, backgroundColor: bg)
    }

    // MARK: Put String

    /// Write a string horizontally starting at (x, y).
    /// Characters that fall outside the buffer are clipped.
    func putString(x: Int, y: Int, string: String,
                   fg: TerminalColor = .normal, bg: TerminalColor = .background) {
        var col = x
        for ch in string {
            if col >= TerminalBuffer.width { break }
            if col >= 0 {
                putChar(x: col, y: y, char: ch, fg: fg, bg: bg)
            }
            col += 1
        }
    }

    // MARK: Box Drawing

    /// Draw a box using Unicode box-drawing characters.
    /// The box occupies (x, y) to (x+width-1, y+height-1).
    func drawBox(x: Int, y: Int, width: Int, height: Int,
                 fg: TerminalColor = .normal, bg: TerminalColor = .background) {
        guard width >= 2, height >= 2 else { return }

        // Corners
        putChar(x: x, y: y, char: "\u{250C}", fg: fg, bg: bg)                         // ┌
        putChar(x: x + width - 1, y: y, char: "\u{2510}", fg: fg, bg: bg)              // ┐
        putChar(x: x, y: y + height - 1, char: "\u{2514}", fg: fg, bg: bg)             // └
        putChar(x: x + width - 1, y: y + height - 1, char: "\u{2518}", fg: fg, bg: bg) // ┘

        // Top and bottom edges
        for col in (x + 1)..<(x + width - 1) {
            putChar(x: col, y: y, char: "\u{2500}", fg: fg, bg: bg)                    // ─
            putChar(x: col, y: y + height - 1, char: "\u{2500}", fg: fg, bg: bg)       // ─
        }

        // Left and right edges
        for row in (y + 1)..<(y + height - 1) {
            putChar(x: x, y: row, char: "\u{2502}", fg: fg, bg: bg)                    // │
            putChar(x: x + width - 1, y: row, char: "\u{2502}", fg: fg, bg: bg)        // │
        }
    }

    // MARK: Horizontal Line

    /// Draw a horizontal line of ─ starting at (x, y) for `width` characters.
    func drawHorizontalLine(x: Int, y: Int, width: Int,
                            fg: TerminalColor = .normal, bg: TerminalColor = .background) {
        for col in x..<(x + width) {
            putChar(x: col, y: y, char: "\u{2500}", fg: fg, bg: bg) // ─
        }
    }

    // MARK: Vertical Line

    /// Draw a vertical line of │ starting at (x, y) for `height` characters.
    func drawVerticalLine(x: Int, y: Int, height: Int,
                          fg: TerminalColor = .normal, bg: TerminalColor = .background) {
        for row in y..<(y + height) {
            putChar(x: x, y: row, char: "\u{2502}", fg: fg, bg: bg) // │
        }
    }

    // MARK: Fill Rect

    /// Fill a rectangular region with a given character and colors.
    func fillRect(x: Int, y: Int, width: Int, height: Int,
                  char: Character = " ",
                  fg: TerminalColor = .normal, bg: TerminalColor = .background) {
        for row in y..<(y + height) {
            for col in x..<(x + width) {
                putChar(x: col, y: row, char: char, fg: fg, bg: bg)
            }
        }
    }

    // MARK: Progress Bar

    /// Draw a progress bar like ████░░░░.
    /// `value` is the current value, `max` is the maximum value.
    /// The bar fills `width` columns at (x, y).
    func drawProgressBar(x: Int, y: Int, width: Int, value: Double, maxValue: Double,
                         fg: TerminalColor = .bright, bg: TerminalColor = .background) {
        guard width > 0, maxValue > 0 else { return }
        let fraction = Swift.min(Swift.max(value / maxValue, 0.0), 1.0)
        let filledCount = Int(fraction * Double(width))

        for col in 0..<width {
            if col < filledCount {
                putChar(x: x + col, y: y, char: "\u{2588}", fg: fg, bg: bg)   // █ filled
            } else {
                putChar(x: x + col, y: y, char: "\u{2591}", fg: .dim, bg: bg) // ░ empty
            }
        }
    }
}
