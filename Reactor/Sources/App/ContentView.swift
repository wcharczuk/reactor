import SwiftUI
import MetalKit

/// Main content view that hosts the Metal rendering view and manages the game
struct ContentView: View {
    @StateObject private var gameController = GameController()

    var body: some View {
        MetalView(gameController: gameController)
            .ignoresSafeArea()
    }
}

/// NSViewRepresentable wrapper for GameMTKView
struct MetalView: NSViewRepresentable {
    let gameController: GameController

    func makeNSView(context: Context) -> GameMTKView {
        let metalView = GameMTKView()
        metalView.device = MTLCreateSystemDefaultDevice()

        // Initialize the renderer
        guard let renderer = Renderer(metalView: metalView) else {
            fatalError("Failed to initialize Metal renderer")
        }

        // Initialize game systems
        gameController.setup(renderer: renderer, metalView: metalView)

        return metalView
    }

    func updateNSView(_ nsView: GameMTKView, context: Context) {
        // Nothing to update
    }
}

/// Manages game state and connects terminal, simulation, and rendering
class GameController: ObservableObject {
    var renderer: Renderer?
    var reactorState: ReactorState!
    var gameLoop: GameLoop!
    var terminalBuffer: TerminalBuffer!
    // TerminalLayout is a struct with static methods, no instance needed
    var commandLine: TerminalCommandLine!
    var commandParser: CommandParser!
    var commandDispatcher: CommandDispatcher!
    var intellisense: Intellisense!
    var currentView: ViewType = .overview
    var commandOutput: [String] = []

    func setup(renderer: Renderer, metalView: GameMTKView) {
        self.renderer = renderer

        // Initialize simulation
        reactorState = ReactorState.coldShutdown()
        gameLoop = GameLoop(state: reactorState)

        // Initialize terminal
        terminalBuffer = TerminalBuffer()
        commandLine = TerminalCommandLine()
        commandParser = CommandParser()
        intellisense = Intellisense()
        commandDispatcher = CommandDispatcher(state: reactorState, intellisense: intellisense)

        // Connect to renderer
        renderer.terminalBuffer = terminalBuffer
        renderer.gameLoop = gameLoop

        // Setup keyboard handling
        metalView.onCharacterInput = { [weak self] char in
            self?.handleCharacterInput(char)
        }
        metalView.onSpecialKey = { [weak self] key in
            self?.handleSpecialKey(key)
        }

        // Initial terminal render
        updateTerminal()
    }

    func updateTerminal() {
        guard let buffer = terminalBuffer else { return }
        let completions = intellisense.completions(for: commandLine?.currentText ?? "")
        TerminalLayout.render(buffer: buffer,
                              state: reactorState,
                              commandLine: commandLine,
                              currentView: currentView,
                              intellisense: completions,
                              commandOutput: commandOutput)
    }

    func handleCharacterInput(_ char: Character) {
        commandLine.insertCharacter(char)
        updateTerminal()
    }

    func handleSpecialKey(_ key: GameMTKView.SpecialKey) {
        switch key {
        case .enter:
            if let text = commandLine.submit() {
                processCommand(text)
            }
        case .backspace:
            commandLine.deleteBackward()
        case .delete:
            commandLine.deleteForward()
        case .tab:
            let completions = intellisense.completions(for: commandLine.currentText)
            commandLine.tabComplete(completions: completions)
        case .upArrow:
            commandLine.historyUp()
        case .downArrow:
            commandLine.historyDown()
        case .leftArrow:
            commandLine.moveCursorLeft()
        case .rightArrow:
            commandLine.moveCursorRight()
        case .home:
            commandLine.moveCursorToStart()
        case .end:
            commandLine.moveCursorToEnd()
        case .escape:
            break
        case .killToEnd:
            commandLine.killToEnd()
        case .killToStart:
            commandLine.killToStart()
        case .killWordBackward:
            commandLine.killWordBackward()
        case .transposeChars:
            commandLine.transposeChars()
        case .yankKillBuffer:
            commandLine.yank()
        }
        updateTerminal()
    }

    func processCommand(_ text: String) {
        commandOutput.append("> \(text)")
        let command = CommandParser.parse(text)
        let response = commandDispatcher.dispatch(command)

        // Handle view changes
        if case .view(let screen) = command {
            if let vt = ViewType(rawValue: screen.lowercased()) {
                currentView = vt
            }
        }

        // Handle speed changes
        if case .speed(let mult) = command {
            reactorState.timeAcceleration = mult
        }

        for line in response.split(separator: "\n", omittingEmptySubsequences: false) {
            commandOutput.append(String(line))
        }

        // Keep only last 50 lines
        if commandOutput.count > 50 {
            commandOutput = Array(commandOutput.suffix(50))
        }

        updateTerminal()
    }
}
