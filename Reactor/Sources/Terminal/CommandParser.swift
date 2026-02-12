import Foundation

/// Represents a parsed terminal command.
enum Command {
    /// Set a value at a given path. e.g. `set core.adjuster-rods.bank-a.pos 0`
    case set(path: String, value: String)

    /// Get (read) the current value at a given path. e.g. `get primary.pump.1.rpm`
    case get(path: String)

    /// Start a component. e.g. `start aux.diesel.1`
    case start(path: String)

    /// Stop a component. e.g. `stop aux.diesel.1`
    case stop(path: String)

    /// Emergency SCRAM: fully insert all control rods.
    case scram

    /// Switch the display to a named view. e.g. `view core`
    case view(screen: String)

    /// Set the time acceleration multiplier. e.g. `speed 5` or `speed 0.5`
    case speed(multiplier: Double)

    /// Show general status summary.
    case status

    /// Show help, optionally for a specific topic.
    case help(topic: String?)

    /// Quit / exit the application.
    case quit

    /// Unrecognized command.
    case unknown(text: String)
}

/// Parses raw command strings into structured `Command` values.
///
/// Expected format: `<verb> <noun-path> [value]`
struct CommandParser {

    /// Parse a raw input string into a `Command`.
    ///
    /// - Parameter input: The raw command string from the terminal input.
    /// - Returns: A structured `Command`.
    static func parse(_ input: String) -> Command {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .unknown(text: "")
        }

        // Split on whitespace, collapsing multiple spaces
        let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }

        guard let verb = tokens.first else {
            return .unknown(text: trimmed)
        }

        let verbLower = verb.lowercased()

        switch verbLower {

        case "set":
            guard tokens.count >= 3 else {
                if tokens.count == 2 {
                    return .unknown(text: "set requires a value: set <path> <value>")
                }
                return .unknown(text: "set requires a path and value: set <path> <value>")
            }
            let path = tokens[1].lowercased()
            // Value may contain spaces in theory, but for numeric values it won't.
            // Join remaining tokens as value to be safe.
            let value = tokens[2...].joined(separator: " ")
            return .set(path: path, value: value)

        case "get":
            guard tokens.count >= 2 else {
                return .unknown(text: "get requires a path: get <path>")
            }
            let path = tokens[1].lowercased()
            return .get(path: path)

        case "start":
            guard tokens.count >= 2 else {
                return .unknown(text: "start requires a path: start <component>")
            }
            let path = tokens[1].lowercased()
            return .start(path: path)

        case "stop":
            guard tokens.count >= 2 else {
                return .unknown(text: "stop requires a path: stop <component>")
            }
            let path = tokens[1].lowercased()
            return .stop(path: path)

        case "scram":
            return .scram

        case "view":
            guard tokens.count >= 2 else {
                return .unknown(text: "view requires a screen name: view <screen>")
            }
            let screen = tokens[1].lowercased()
            return .view(screen: screen)

        case "speed":
            guard tokens.count >= 2 else {
                return .unknown(text: "speed requires a multiplier: speed <0.1|0.25|0.5|1|2|5|10>")
            }
            if let multiplier = Double(tokens[1]) {
                return .speed(multiplier: multiplier)
            } else {
                return .unknown(text: "speed multiplier must be a number: speed <0.1|0.25|0.5|1|2|5|10>")
            }

        case "status":
            return .status

        case "help":
            if tokens.count >= 2 {
                let topic = tokens[1...].joined(separator: " ").lowercased()
                return .help(topic: topic)
            }
            return .help(topic: nil)

        case "quit", "exit":
            return .quit

        default:
            return .unknown(text: trimmed)
        }
    }
}
