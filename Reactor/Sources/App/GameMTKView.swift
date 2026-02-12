import AppKit
import MetalKit

/// Custom MTKView subclass that handles keyboard input for the terminal
class GameMTKView: MTKView {
    /// Callback for character input
    var onCharacterInput: ((Character) -> Void)?
    /// Callback for special key presses
    var onSpecialKey: ((SpecialKey) -> Void)?
    /// Callback for mouse scroll wheel (positive deltaY = scroll up)
    var onScrollWheel: ((CGFloat) -> Void)?

    enum SpecialKey {
        case enter
        case backspace
        case delete
        case tab
        case upArrow
        case downArrow
        case leftArrow
        case rightArrow
        case home
        case end
        case escape
        case pageUp
        case pageDown
        case outputHome   // Shift+Home — scroll to top of output
        case outputEnd    // Shift+End — scroll to bottom of output
        // Readline
        case killToEnd
        case killToStart
        case killWordBackward
        case transposeChars
        case yankKillBuffer
        case reverseSearch
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else { return }

        // Readline control key bindings
        if event.modifierFlags.contains(.control),
           let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "a": onSpecialKey?(.home); return
            case "e": onSpecialKey?(.end); return
            case "b": onSpecialKey?(.leftArrow); return
            case "f": onSpecialKey?(.rightArrow); return
            case "p": onSpecialKey?(.upArrow); return
            case "n": onSpecialKey?(.downArrow); return
            case "d": onSpecialKey?(.delete); return
            case "h": onSpecialKey?(.backspace); return
            case "k": onSpecialKey?(.killToEnd); return
            case "u": onSpecialKey?(.killToStart); return
            case "w": onSpecialKey?(.killWordBackward); return
            case "t": onSpecialKey?(.transposeChars); return
            case "y": onSpecialKey?(.yankKillBuffer); return
            case "r": onSpecialKey?(.reverseSearch); return
            case "g": onSpecialKey?(.escape); return  // C-g cancels like escape
            default: break
            }
        }

        // Check for special keys first
        switch event.keyCode {
        case 36: // Return/Enter
            onSpecialKey?(.enter)
            return
        case 51: // Backspace/Delete
            onSpecialKey?(.backspace)
            return
        case 117: // Forward Delete
            onSpecialKey?(.delete)
            return
        case 48: // Tab
            onSpecialKey?(.tab)
            return
        case 126: // Up Arrow
            onSpecialKey?(.upArrow)
            return
        case 125: // Down Arrow
            onSpecialKey?(.downArrow)
            return
        case 123: // Left Arrow
            onSpecialKey?(.leftArrow)
            return
        case 124: // Right Arrow
            onSpecialKey?(.rightArrow)
            return
        case 115: // Home
            if event.modifierFlags.contains(.shift) {
                onSpecialKey?(.outputHome)
            } else {
                onSpecialKey?(.home)
            }
            return
        case 119: // End
            if event.modifierFlags.contains(.shift) {
                onSpecialKey?(.outputEnd)
            } else {
                onSpecialKey?(.end)
            }
            return
        case 116: // Page Up
            onSpecialKey?(.pageUp)
            return
        case 121: // Page Down
            onSpecialKey?(.pageDown)
            return
        case 53: // Escape
            onSpecialKey?(.escape)
            return
        default:
            break
        }

        // Handle regular character input
        for char in characters {
            if char.isPrintableASCII {
                onCharacterInput?(char)
            }
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Could handle modifier keys here if needed
    }

    // Make sure we can become first responder and receive key events
    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func scrollWheel(with event: NSEvent) {
        onScrollWheel?(event.scrollingDeltaY)
    }

    override func mouseDown(with event: NSEvent) {
        // Ensure we grab focus when clicked
        window?.makeFirstResponder(self)
    }
}

// Helper extension
private extension Character {
    var isPrintableASCII: Bool {
        guard let ascii = asciiValue else { return false }
        return ascii >= 32 && ascii <= 126
    }
}
