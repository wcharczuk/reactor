import SwiftUI
import MetalKit
import AppKit

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
    var adminServer: AdminServer?
    var currentView: ViewType = .overview
    var commandOutput: [String] = []
    var outputScrollOffset: Int = 0
    private var scrollAccumulator: CGFloat = 0

    // Thread-safe work queue: ALL state access is funnelled through the draw
    // loop so keyboard input (main thread), admin HTTP (background thread),
    // and the simulation update (CVDisplayLink thread) never race.
    private var pendingWork: [() -> Void] = []
    private let workLock = NSLock()

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
        renderer.onFrame = { [weak self] in
            self?.drainWorkQueue()
            self?.updateTerminal()
        }

        // Setup keyboard handling — queued to the draw loop so keyboard
        // events (main thread) never race with simulation (CVDisplayLink).
        metalView.onCharacterInput = { [weak self] char in
            self?.enqueueWork { self?.handleCharacterInput(char) }
        }
        metalView.onSpecialKey = { [weak self] key in
            self?.enqueueWork { self?.handleSpecialKey(key) }
        }
        metalView.onScrollWheel = { [weak self] deltaY in
            self?.enqueueWork { self?.handleScrollWheel(deltaY) }
        }

        // Initial terminal render
        updateTerminal()

        // Start admin HTTP server — callbacks use semaphore+queue so all
        // state access happens inside the draw loop (no thread races).
        let server = AdminServer()
        server.onCommand = { [weak self] commandText in
            guard let self = self else { return "Controller unavailable" }
            let semaphore = DispatchSemaphore(value: 0)
            var result = ""
            self.workLock.lock()
            self.pendingWork.append {
                let command = CommandParser.parse(commandText)
                result = self.commandDispatcher.dispatch(command)

                if case .view(let screen) = command {
                    if let vt = ViewType(rawValue: screen.lowercased()) {
                        self.currentView = vt
                    }
                }
                if case .speed(let mult) = command {
                    self.reactorState.timeAcceleration = mult
                }

                let ts = self.formatElapsedTime(self.reactorState.elapsedTime)
                self.commandOutput.append("\(ts)  > \(commandText)")
                for line in result.split(separator: "\n", omittingEmptySubsequences: false) {
                    self.commandOutput.append("\(ts)  \(line)")
                }
                if self.commandOutput.count > 500 {
                    self.commandOutput = Array(self.commandOutput.suffix(500))
                }

                semaphore.signal()
            }
            self.workLock.unlock()
            semaphore.wait()
            return result
        }
        server.onStateSnapshot = { [weak self] in
            guard let self = self else { return [:] }
            let semaphore = DispatchSemaphore(value: 0)
            var result: [String: Any] = [:]
            self.workLock.lock()
            self.pendingWork.append {
                result = self.buildStateSnapshot()
                semaphore.signal()
            }
            self.workLock.unlock()
            semaphore.wait()
            return result
        }
        server.onDisplayCapture = { [weak self] in
            guard let self = self else { return nil }
            let semaphore = DispatchSemaphore(value: 0)
            var result: Data?
            self.workLock.lock()
            self.pendingWork.append {
                result = self.renderer?.captureTerminalPNG()
                semaphore.signal()
            }
            self.workLock.unlock()
            semaphore.wait()
            return result
        }
        server.start()
        self.adminServer = server
    }

    func enqueueWork(_ work: @escaping () -> Void) {
        workLock.lock()
        pendingWork.append(work)
        workLock.unlock()
    }

    private func drainWorkQueue() {
        workLock.lock()
        let work = pendingWork
        pendingWork.removeAll()
        workLock.unlock()
        for item in work {
            item()
        }
    }

    func updateTerminal() {
        guard let buffer = terminalBuffer else { return }
        let dispatcher = commandDispatcher!
        let completions = intellisense.completions(for: commandLine?.currentText ?? "", valueLookup: { dispatcher.currentValueString(for: $0) })
        TerminalLayout.render(buffer: buffer,
                              state: reactorState,
                              commandLine: commandLine,
                              currentView: currentView,
                              intellisense: completions,
                              commandOutput: commandOutput,
                              scrollOffset: outputScrollOffset)
    }

    func handleCharacterInput(_ char: Character) {
        if commandLine.isSearching {
            commandLine.searchInsertCharacter(char)
        } else {
            commandLine.insertCharacter(char)
        }
        updateTerminal()
    }

    func handleSpecialKey(_ key: GameMTKView.SpecialKey) {
        // When in reverse-i-search mode, most keys exit search first
        if commandLine.isSearching {
            switch key {
            case .reverseSearch:
                commandLine.searchNext()
            case .enter:
                commandLine.acceptSearch()
                if let text = commandLine.submit() {
                    processCommand(text)
                }
            case .escape:
                commandLine.cancelSearch()
            case .backspace:
                commandLine.searchDeleteBackward()
            default:
                // Any other key accepts the search result, then processes normally
                commandLine.acceptSearch()
                handleSpecialKey(key)
                return
            }
            updateTerminal()
            return
        }

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
            let disp = commandDispatcher!
            let completions = intellisense.completions(for: commandLine.currentText, valueLookup: { disp.currentValueString(for: $0) })
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
        case .pageUp:
            let pageSize = 20
            let maxOffset = max(commandOutput.count - 1, 0)
            outputScrollOffset = min(outputScrollOffset + pageSize, maxOffset)
        case .pageDown:
            outputScrollOffset = max(outputScrollOffset - 20, 0)
        case .outputHome:
            outputScrollOffset = max(commandOutput.count - 1, 0)
        case .outputEnd:
            outputScrollOffset = 0
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
        case .reverseSearch:
            commandLine.beginSearch()
        }
        updateTerminal()
    }

    func handleScrollWheel(_ deltaY: CGFloat) {
        scrollAccumulator += deltaY
        let threshold: CGFloat = 3.0
        let lines = Int(scrollAccumulator / threshold)
        if lines != 0 {
            scrollAccumulator -= CGFloat(lines) * threshold
            let maxOffset = max(commandOutput.count - 1, 0)
            outputScrollOffset = min(max(outputScrollOffset + lines, 0), maxOffset)
            updateTerminal()
        }
    }

    func processCommand(_ text: String) {
        // Reset scroll to bottom on new command
        outputScrollOffset = 0

        let ts = formatElapsedTime(reactorState.elapsedTime)
        commandOutput.append("\(ts)  > \(text)")
        let command = CommandParser.parse(text)

        // Handle quit/exit
        if case .quit = command {
            NSApplication.shared.terminate(nil)
            return
        }

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
            commandOutput.append("\(ts)  \(line)")
        }

        // Keep only last 500 lines
        if commandOutput.count > 500 {
            commandOutput = Array(commandOutput.suffix(500))
        }

        updateTerminal()
    }

    private func formatElapsedTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    func buildStateSnapshot() -> [String: Any] {
        let s = reactorState!
        return [
            "time": [
                "elapsed": s.elapsedTime,
                "acceleration": s.timeAcceleration
            ],
            "order": s.currentOrder,
            "neutronics": [
                "neutronDensity": s.neutronDensity,
                "thermalPower": s.thermalPower,
                "thermalPowerFraction": s.thermalPowerFraction,
                "decayHeatPower": s.decayHeatPower
            ],
            "reactivity": [
                "total": s.totalReactivity,
                "rod": s.rodReactivity,
                "feedback": s.feedbackReactivity,
                "xenon": s.xenonReactivity
            ],
            "controlDevices": [
                "adjusterPositions": s.adjusterPositions,
                "adjusterTargetPositions": s.adjusterTargetPositions,
                "zoneControllerFills": s.zoneControllerFills,
                "mcaPositions": s.mcaPositions,
                "mcaTargetPositions": s.mcaTargetPositions,
                "shutoffRodsInserted": s.shutoffRodsInserted,
                "shutoffRodInsertionFraction": s.shutoffRodInsertionFraction
            ],
            "temperatures": [
                "fuel": s.fuelTemp,
                "cladding": s.claddingTemp,
                "primaryInlet": s.primaryInletTemp,
                "primaryOutlet": s.primaryOutletTemp,
                "steam": s.steamTemp,
                "feedwater": s.feedwaterTemp,
                "condenser": s.condenserTemp,
                "coolingWaterInlet": s.coolingWaterInletTemp,
                "coolingWaterOutlet": s.coolingWaterOutletTemp
            ],
            "pressures": [
                "primary": s.primaryPressure,
                "steam": s.steamPressure,
                "condenser": s.condenserPressure
            ],
            "flows": [
                "primary": s.primaryFlowRate,
                "steam": s.steamFlow,
                "coolingWater": s.coolingWaterFlow
            ],
            "primaryPumps": s.primaryPumps.enumerated().map { (i, p) in
                ["index": i, "rpm": p.rpm, "targetRPM": p.targetRPM, "running": p.running, "tripped": p.tripped] as [String: Any]
            },
            "coolingWaterPumps": s.coolingWaterPumps.enumerated().map { (i, p) in
                ["index": i, "rpm": p.rpm, "targetRPM": p.targetRPM, "running": p.running, "tripped": p.tripped] as [String: Any]
            },
            "feedPumps": s.feedPumps.enumerated().map { (i, p) in
                ["index": i, "running": p.running, "flowRate": p.flowRate] as [String: Any]
            },
            "steamGenerators": [
                "levels": s.sgLevels
            ],
            "turbine": [
                "rpm": s.turbineRPM,
                "governor": s.turbineGovernor
            ],
            "electrical": [
                "grossPower": s.grossPower,
                "netPower": s.netPower,
                "stationServiceLoad": s.stationServiceLoad,
                "emergencyServiceLoad": s.emergencyServiceLoad,
                "generatorFrequency": s.generatorFrequency,
                "generatorConnected": s.generatorConnected
            ],
            "dieselGenerators": s.dieselGenerators.enumerated().map { (i, d) in
                [
                    "index": i,
                    "running": d.running,
                    "loaded": d.loaded,
                    "available": d.available,
                    "power": d.power,
                    "fuelLevel": d.fuelLevel
                ] as [String: Any]
            },
            "xenon": [
                "concentration": s.xenonConcentration,
                "iodineConcentration": s.iodineConcentration,
                "reactivity": s.xenonReactivity
            ],
            "safety": [
                "scramActive": s.scramActive,
                "scramTime": s.scramTime
            ],
            "alarms": s.alarms.map { a in
                ["time": a.time, "message": a.message, "acknowledged": a.acknowledged] as [String: Any]
            },
            "moderator": [
                "circulating": s.moderatorCirculating,
                "heavyWaterInventory": s.heavyWaterInventory
            ]
        ]
    }
}
