import Foundation

/// Layout manager that renders the current view to the TerminalBuffer.
///
/// Layout regions (213×70 grid):
/// - Left panel (cols 0-39): STATUS/ALARMS area
///   - Orders box (rows 2-9)
///   - Alarms box (rows 11-23)
///   - Reactor Status box (rows 25-36)
/// - Right panel (cols 42-212, rows 0-37): Main display area
/// - Command area (cols 0-212, rows 39-69): Full-width command input
struct TerminalLayout {

    // MARK: - Layout Constants

    // Left panel
    private static let leftPanelLeft = 0
    private static let leftPanelRight = 39
    private static let leftPanelWidth = 40

    // Orders box
    private static let ordersTop = 2
    private static let ordersBottom = 9
    private static let ordersHeight = 8

    // Alarms box
    private static let alarmsTop = 11
    private static let alarmsBottom = 23
    private static let alarmsHeight = 13

    // Reactor Status box
    private static let keyStatusTop = 25
    private static let keyStatusBottom = 36
    private static let keyStatusHeight = 12

    // Right panel
    private static let rightPanelLeft = 42
    private static let rightPanelRight = 212
    private static let rightPanelWidth = 171

    // Main display area
    private static let mainDisplayTop = 0
    private static let mainDisplayBottom = 37
    private static let mainDisplayHeight = 38

    // Command input area (full width, bottom section)
    private static let commandAreaTop = 39
    private static let commandAreaBottom = 69
    private static let commandAreaHeight = 31

    // MARK: - Render

    /// Render the complete terminal display to the buffer.
    static func render(
        buffer: TerminalBuffer,
        state: ReactorState,
        commandLine: TerminalCommandLine,
        currentView: ViewType,
        intellisense: [String],
        commandOutput: [String],
        scrollOffset: Int = 0
    ) {
        buffer.clear()

        // Draw left panel
        renderLeftPanel(buffer: buffer, state: state)

        // Draw divider between left and right panels (top section only)
        buffer.drawVerticalLine(x: 40, y: 0, height: commandAreaTop - 1, fg: .dim)

        // Draw main display area
        renderMainDisplay(buffer: buffer, state: state, currentView: currentView)

        // Draw horizontal divider above command area
        buffer.drawHorizontalLine(x: 0, y: commandAreaTop - 1, width: TerminalBuffer.width, fg: .dim)

        // Draw command input area (full width)
        renderCommandArea(buffer: buffer, commandLine: commandLine, intellisense: intellisense, commandOutput: commandOutput, scrollOffset: scrollOffset)
    }

    // MARK: - Left Panel

    private static func renderLeftPanel(buffer: TerminalBuffer, state: ReactorState) {
        // Title
        buffer.putString(x: 1, y: 0, string: " REACTOR CONTROL ", fg: .bright)
        buffer.drawHorizontalLine(x: 0, y: 1, width: leftPanelWidth, fg: .dim)

        // Orders box
        renderOrdersBox(buffer: buffer, state: state)

        // Alarms box
        renderAlarmsBox(buffer: buffer, state: state)

        // Reactor Status box
        renderKeyStatusBox(buffer: buffer, state: state)
    }

    private static func renderOrdersBox(buffer: TerminalBuffer, state: ReactorState) {
        buffer.drawBox(x: 0, y: ordersTop, width: leftPanelWidth, height: ordersHeight, fg: .dim)
        buffer.putString(x: 2, y: ordersTop, string: " ORDERS ", fg: .bright)

        // Display current order (wrap if needed)
        let orderText = state.currentOrder
        let maxWidth = leftPanelWidth - 4
        var nextRow = ordersTop + 1
        if orderText.count <= maxWidth {
            buffer.putString(x: 2, y: nextRow, string: orderText, fg: .bright)
            nextRow += 1
        } else {
            let line1 = String(orderText.prefix(maxWidth))
            let line2 = String(orderText.dropFirst(maxWidth).prefix(maxWidth))
            buffer.putString(x: 2, y: nextRow, string: line1, fg: .bright)
            nextRow += 1
            buffer.putString(x: 2, y: nextRow, string: line2, fg: .bright)
            nextRow += 1
        }

        // Display contextual hint
        let hints = orderHint(state: state)
        for hint in hints {
            if nextRow >= ordersTop + ordersHeight - 1 { break }
            let truncated = String(hint.prefix(maxWidth))
            buffer.putString(x: 2, y: nextRow, string: truncated, fg: .normal)
            nextRow += 1
        }
    }

    private static func renderAlarmsBox(buffer: TerminalBuffer, state: ReactorState) {
        let alarmBoxColor: TerminalColor = state.alarms.isEmpty ? .dim :
            (state.alarms.contains { $0.message.contains("[TRIP]") } ? .danger : .warning)
        buffer.drawBox(x: 0, y: alarmsTop, width: leftPanelWidth, height: alarmsHeight, fg: alarmBoxColor)
        let alarmTitleColor: TerminalColor = state.alarms.isEmpty ? .dim :
            (state.alarms.contains { $0.message.contains("[TRIP]") } ? .danger : .warning)
        buffer.putString(x: 2, y: alarmsTop, string: " ALARMS ", fg: alarmTitleColor)

        let maxLines = alarmsHeight - 2
        let maxWidth = leftPanelWidth - 4

        // Show most recent alarms (reversed so newest is at top)
        let recentAlarms = state.alarms.suffix(maxLines).reversed()
        var row = alarmsTop + 1
        for alarm in recentAlarms {
            if row >= alarmsTop + alarmsHeight - 1 { break }
            let timeStr = formatElapsedTime(alarm.time)
            let msg = "\(timeStr) \(alarm.message)"
            let truncated = String(msg.prefix(maxWidth))
            let color: TerminalColor = alarm.message.contains("[TRIP]") ? .danger :
                                       alarm.message.contains("[ALARM]") ? .warning : .normal
            buffer.putString(x: 2, y: row, string: truncated, fg: color)
            row += 1
        }

        if state.alarms.isEmpty {
            buffer.putString(x: 2, y: alarmsTop + 1, string: "No active alarms.", fg: .dim)
        }
    }

    private static func renderKeyStatusBox(buffer: TerminalBuffer, state: ReactorState) {
        buffer.drawBox(x: 0, y: keyStatusTop, width: leftPanelWidth, height: keyStatusHeight, fg: .dim)
        buffer.putString(x: 2, y: keyStatusTop, string: " REACTOR STATUS ", fg: .bright)

        let col1 = 2
        var row = keyStatusTop + 1
        let maxWidth = leftPanelWidth - 4

        // Power
        let powerPct = String(format: "%.1f", state.thermalPowerFraction * 100.0)
        let powerColor = thresholdColor(value: state.thermalPowerFraction, warning: 1.03, danger: 1.08)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Power:", value: "\(powerPct)%", maxWidth: maxWidth, fg: powerColor)
        row += 1

        // Adjuster rod positions by bank
        let bankLabels = ["A", "B", "C", "D"]
        let adjStr = bankLabels.enumerated().map { (i, name) in
            String(format: "%@:%02.0f", name, (1.0 - state.adjusterPositions[i]) * 100.0)
        }.joined(separator: " ")
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Adj:", value: adjStr, maxWidth: maxWidth)
        row += 1

        // Shutoff rods
        let sorStr = state.scramActive ? "SCRAM" : (state.shutoffRodsInserted ? "IN" : "OUT")
        putStatusLine(buffer: buffer, x: col1, y: row, label: "SORs:", value: sorStr, maxWidth: maxWidth,
                      fg: state.scramActive ? .danger : .normal)
        row += 1

        // Xenon worth
        let xenonVal = abs(state.xenonReactivity) < 0.005 ? 0.0 : state.xenonReactivity
        let xenonStr = String(format: "%.2f mk", xenonVal)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Xenon:", value: xenonStr, maxWidth: maxWidth)
        row += 1

        // Total reactivity
        let reactStr = String(format: "%+.2f mk", state.totalReactivity)
        let reactColor = deviationColor(value: state.totalReactivity, nominal: 0.0, warning: 3.0, danger: 7.0)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "React:", value: reactStr, maxWidth: maxWidth, fg: reactColor)
        row += 1

        // Primary pressure
        let pressStr = String(format: "%.1f MPa", state.primaryPressure)
        let pressColor = deviationColor(value: state.primaryPressure, nominal: CANDUConstants.primaryPressureRated, warning: 1.5, danger: 3.0)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Press:", value: pressStr, maxWidth: maxWidth, fg: pressColor)
        row += 1

        // Power source line: context-dependent
        if state.generatorConnected {
            // On-grid: show net power exported
            let netStr = String(format: "%.1f MW", state.netPower)
            let netColor: TerminalColor = state.netPower < 0 ? .danger : .normal
            putStatusLine(buffer: buffer, x: col1, y: row, label: "Net:", value: netStr, maxWidth: maxWidth, fg: netColor)
        } else {
            let totalDieselPower = state.dieselGenerators.reduce(0.0) { $0 + $1.power }
            let totalDieselCapacity = state.availableDieselCapacity
            if totalDieselCapacity > 0 {
                // Off-grid with diesels: show load vs capacity
                let dgStr = String(format: "%.1f/%.0f MW", totalDieselPower, totalDieselCapacity)
                let loadRatio = state.emergencyServiceLoad / totalDieselCapacity
                let dgColor: TerminalColor = loadRatio > 0.95 ? .danger : (loadRatio > 0.80 ? .warning : .normal)
                putStatusLine(buffer: buffer, x: col1, y: row, label: "DG:", value: dgStr, maxWidth: maxWidth, fg: dgColor)
            } else {
                // No power at all
                putStatusLine(buffer: buffer, x: col1, y: row, label: "Pwr:", value: "NONE", maxWidth: maxWidth, fg: .danger)
            }
        }
        row += 1

        // Diesel fuel level (show when diesels are relevant — not on grid)
        if !state.generatorConnected {
            let minFuel = state.dieselGenerators.filter { $0.running }.map { $0.fuelLevel }.min()
            if let fuel = minFuel {
                let fuelPct = fuel * 100.0
                let fuelStr = String(format: "%.0f%%", fuelPct)
                let fuelColor = thresholdColorLow(value: fuelPct, warning: 25.0, danger: 10.0)
                putStatusLine(buffer: buffer, x: col1, y: row, label: "DFuel:", value: fuelStr, maxWidth: maxWidth, fg: fuelColor)
                row += 1
            }
        }

        // Time and speed
        let timeStr = formatElapsedTime(state.elapsedTime)
        let speedStr = state.timeAcceleration == Double(Int(state.timeAcceleration))
            ? "\(Int(state.timeAcceleration))x"
            : "\(state.timeAcceleration)x"
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Time:", value: "\(timeStr) \(speedStr)", maxWidth: maxWidth)
    }

    private static func putStatusLine(buffer: TerminalBuffer, x: Int, y: Int, label: String, value: String, maxWidth: Int, fg: TerminalColor = .normal) {
        buffer.putString(x: x, y: y, string: label, fg: .dim)
        let truncatedValue = String(value.prefix(max(maxWidth - label.count - 1, 0)))
        let valueX = x + maxWidth - truncatedValue.count
        buffer.putString(x: valueX, y: y, string: truncatedValue, fg: fg)
    }

    // MARK: - Main Display Area

    private static func renderMainDisplay(buffer: TerminalBuffer, state: ReactorState, currentView: ViewType) {
        let left = rightPanelLeft
        let top = mainDisplayTop
        let width = rightPanelWidth
        let height = mainDisplayHeight

        // Draw border
        buffer.drawBox(x: left, y: top, width: width, height: height, fg: .dim)

        // Title bar
        let title = " \(currentView.rawValue.uppercased()) "
        buffer.putString(x: left + 2, y: top, string: title, fg: .bright)

        switch currentView {
        case .overview:
            renderOverview(buffer: buffer, state: state, left: left + 2, top: top + 2, width: width - 4, height: height - 4)
        case .core:
            renderCore(buffer: buffer, state: state, left: left + 2, top: top + 2, width: width - 4, height: height - 4)
        case .primary:
            renderPrimary(buffer: buffer, state: state, left: left + 2, top: top + 2, width: width - 4, height: height - 4)
        case .secondary:
            renderSecondary(buffer: buffer, state: state, left: left + 2, top: top + 2, width: width - 4, height: height - 4)
        case .electrical:
            renderElectrical(buffer: buffer, state: state, left: left + 2, top: top + 2, width: width - 4, height: height - 4)
        case .alarms:
            renderAlarmLog(buffer: buffer, state: state, left: left + 2, top: top + 2, width: width - 4, height: height - 4)
        }
    }

    // MARK: - Overview View

    /// Animated spinner for running equipment.
    private static func spinner(_ time: Double, offset: Int = 0) -> Character {
        let frames: [Character] = ["|", "/", "-", "\\"]
        return frames[(Int(time * 4) + offset) & 3]
    }

    /// Draw a labelled component box with content lines.
    private static func drawComponent(
        buffer: TerminalBuffer, x: Int, y: Int, w: Int, h: Int,
        title: String, lines: [(String, TerminalColor)], active: Bool,
        borderColor: TerminalColor? = nil
    ) {
        let boxColor = borderColor ?? (active ? .normal : .dim)
        buffer.drawBox(x: x, y: y, width: w, height: h, fg: boxColor)
        buffer.putString(x: x + 1, y: y, string: " \(title) ", fg: .bright)
        for (i, (text, color)) in lines.enumerated() {
            let row = y + 1 + i
            if row < y + h - 1 {
                let truncated = String(text.prefix(w - 2))
                buffer.putString(x: x + 1, y: row, string: truncated, fg: color)
            }
        }
    }

    /// Draw a horizontal flow arrow.
    private static func drawArrow(buffer: TerminalBuffer, x: Int, y: Int, length: Int, label: String, flowing: Bool) {
        let fg: TerminalColor = flowing ? .normal : .dim
        if length >= 2 {
            for i in 0..<(length - 1) {
                buffer.putChar(x: x + i, y: y, char: "\u{2500}", fg: fg) // ─
            }
            buffer.putChar(x: x + length - 1, y: y, char: "\u{25B6}", fg: fg) // ▶
        }
        if !label.isEmpty {
            let lx = x + (length - label.count) / 2
            buffer.putString(x: lx, y: y - 1, string: label, fg: .dim)
        }
    }

    /// Draw a left-pointing flow arrow.
    private static func drawArrowLeft(buffer: TerminalBuffer, x: Int, y: Int, length: Int, label: String, flowing: Bool) {
        let fg: TerminalColor = flowing ? .normal : .dim
        if length >= 2 {
            buffer.putChar(x: x, y: y, char: "\u{25C0}", fg: fg) // ◀
            for i in 1..<length {
                buffer.putChar(x: x + i, y: y, char: "\u{2500}", fg: fg) // ─
            }
        }
        if !label.isEmpty {
            let lx = x + (length - label.count) / 2
            buffer.putString(x: lx, y: y - 1, string: label, fg: .dim)
        }
    }

    private static func renderOverview(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        let t = state.elapsedTime
        let bw = 26  // box width
        let bh = 8   // box height
        let gap = 3  // gap between boxes for arrows

        // X positions for top-row component boxes
        let coreX   = left
        let phtX    = coreX + bw + gap
        let sgX     = phtX + bw + gap
        let turbX   = sgX + bw + gap
        let genX    = turbX + bw + gap

        // Title
        buffer.putString(x: left, y: top, string: "CANDU-6 PLANT OVERVIEW", fg: .bright)

        // ── Core Diagram Section (centered, rows top+2 through top+9) ──
        let diagramCols = 16
        let diagramRows = 8
        let coreSecTop = top + 2

        // Center the diagram + text as a block
        let zoneTextWidth = 40
        let coreBlockWidth = diagramCols + 2 + zoneTextWidth
        let coreBlockLeft = left + (width - coreBlockWidth) / 2

        // Raster calandria (heat-map sectors)
        buffer.overviewDiagram = CoreDiagramData(
            gridX: coreBlockLeft,
            gridY: coreSecTop,
            gridWidth: diagramCols,
            gridHeight: diagramRows,
            adjusterPositions: state.adjusterPositions,
            mcaPositions: state.mcaPositions,
            zoneFills: state.zoneControllerFills,
            shutoffInsertion: state.shutoffRodInsertionFraction,
            scramActive: state.scramActive
        )

        // Zone readouts to the right of diagram
        let zoneTextX = coreBlockLeft + diagramCols + 2
        var coreRow = coreSecTop

        buffer.putString(x: zoneTextX, y: coreRow, string: "ZONES", fg: .bright)
        coreRow += 1

        let zoneWorthPerUnit = CANDUConstants.zoneControlTotalWorth / 6.0
        let zoneBarWidth = 16
        for i in 0..<6 {
            let fill = state.zoneControllerFills[i]
            let dev = (50.0 - fill) / 50.0
            let zoneMk = zoneWorthPerUnit * dev * 0.5

            buffer.putString(x: zoneTextX, y: coreRow, string: "Z\(i + 1) ", fg: .dim)
            buffer.drawProgressBar(x: zoneTextX + 3, y: coreRow, width: zoneBarWidth,
                                   value: fill, maxValue: 100.0, fg: .bright)
            let pctStr = String(format: "%3.0f%%", fill)
            let mkStr = String(format: "%+.2fmk", zoneMk)
            let mkColor = deviationColor(value: zoneMk, nominal: 0, warning: 0.15, danger: 0.3)
            buffer.putString(x: zoneTextX + 3 + zoneBarWidth + 1, y: coreRow, string: pctStr, fg: .normal)
            buffer.putString(x: zoneTextX + 3 + zoneBarWidth + 6, y: coreRow, string: mkStr, fg: mkColor)
            coreRow += 1
        }

        // Rod + SOR summary line
        let ovBankLabels = ["A", "B", "C", "D"]
        var adjLine = "Adj "
        for (i, name) in ovBankLabels.enumerated() {
            adjLine += String(format: "%@:%02.0f%%", name, (1.0 - state.adjusterPositions[i]) * 100.0)
            if i < 3 { adjLine += " " }
        }
        adjLine += "  "
        for i in 0..<2 {
            adjLine += String(format: "MCA%d:%02.0f%%", i + 1, (1.0 - state.mcaPositions[i]) * 100.0)
            if i < 1 { adjLine += " " }
        }
        buffer.putString(x: zoneTextX, y: coreRow, string: adjLine, fg: .normal)
        coreRow += 1

        let ovSorStr: String
        let ovSorColor: TerminalColor
        if state.scramActive {
            ovSorStr = "SCRAM"
            ovSorColor = .danger
        } else if state.shutoffRodsInserted {
            ovSorStr = "IN"
            ovSorColor = .warning
        } else {
            ovSorStr = "OUT"
            ovSorColor = .dim
        }
        let ovTotalStr = String(format: "Total: %+.2f mk", state.totalReactivity)
        let ovTotalColor = deviationColor(value: state.totalReactivity, nominal: 0, warning: 3, danger: 7)
        buffer.putString(x: zoneTextX, y: coreRow, string: "SOR: \(ovSorStr)", fg: ovSorColor)
        buffer.putString(x: zoneTextX + 14, y: coreRow, string: ovTotalStr, fg: ovTotalColor)

        // ── Flow Diagram Section (below core section) ──
        let flowTop = top + 13
        let topY    = flowTop       // top row of boxes
        let arrowY  = topY + bh / 2 // arrow row (midpoint of boxes)
        let botY    = topY + bh + 2 // bottom row of boxes

        // ── Top row: Core → Primary Pumps → Steam Generators → Turbine → Generator ──

        // Core
        let thermalPower = String(format: "%.0f MW", state.thermalPower)
        let powerPct = String(format: "%.1f%% FP", state.thermalPowerFraction * 100.0)
        let fuelT = String(format: "Fuel: %.0f\u{00B0}C", state.fuelTemp)
        let reactStr = String(format: "%+.2f mk", state.totalReactivity)
        let coreActive = state.thermalPower > 1.0
        let coreFuelColor = thresholdColor(value: state.fuelTemp, warning: 2200, danger: 2600)
        let coreReactColor = deviationColor(value: state.totalReactivity, nominal: 0, warning: 3, danger: 7)
        let corePowerColor = thresholdColor(value: state.thermalPowerFraction, warning: 1.03, danger: 1.08)
        let coreBorder: TerminalColor? = coreFuelColor == .danger || coreReactColor == .danger || corePowerColor == .danger ? .danger :
                                          coreFuelColor == .warning || coreReactColor == .warning || corePowerColor == .warning ? .warning : nil
        drawComponent(buffer: buffer, x: coreX, y: topY, w: bw, h: bh,
                      title: "CORE",
                      lines: [
                          (thermalPower, coreActive ? .bright : .normal),
                          (powerPct, corePowerColor),
                          (fuelT, coreFuelColor),
                          (reactStr, coreReactColor),
                      ], active: coreActive, borderColor: coreBorder)

        // Arrow Core → Primary Pumps
        let hasFlow = state.primaryFlowRate > 10
        drawArrow(buffer: buffer, x: coreX + bw, y: arrowY, length: gap, label: "", flowing: hasFlow)

        // Primary Pumps
        let phtRunning = state.primaryPumps.filter { $0.running }.count
        let phtTripped = state.primaryPumps.filter { $0.tripped }.count
        var phtSpinners = ""
        for i in 0..<4 {
            let ch = state.primaryPumps[i].running ? String(spinner(t, offset: i)) : "\u{00B7}"
            phtSpinners += " \(ch)"
        }
        let phtFlow = String(format: "%.0f kg/s", state.primaryFlowRate)
        let phtPressure = String(format: "%.1f MPa", state.primaryPressure)
        let phtPressColor = deviationColor(value: state.primaryPressure, nominal: CANDUConstants.primaryPressureRated, warning: 1.5, danger: 3.0)
        let phtPumpColor: TerminalColor = phtTripped > 0 ? .danger : (phtRunning == 0 && state.thermalPower > 10 ? .warning : .normal)
        let phtBorder: TerminalColor? = phtTripped > 0 ? .danger : (phtRunning == 0 && state.thermalPower > 10 ? .warning : nil)
        drawComponent(buffer: buffer, x: phtX, y: topY, w: bw, h: bh,
                      title: "PRIMARY PUMPS",
                      lines: [
                          ("P:" + phtSpinners, phtRunning > 0 ? .bright : .dim),
                          (phtFlow, .normal),
                          (phtPressure, phtPressColor),
                          ("\(phtRunning)/4 running", phtPumpColor),
                      ], active: phtRunning > 0, borderColor: phtBorder)

        // Arrow Primary Pumps → SG
        drawArrow(buffer: buffer, x: phtX + bw, y: arrowY, length: gap, label: "", flowing: hasFlow)

        // Steam Generators
        let sgLevelAvg = state.sgLevels.reduce(0.0, +) / Double(state.sgLevels.count)
        let sgLevel = String(format: "Lvl: %.0f%%", sgLevelAvg)
        let sgPress = String(format: "%.1f MPa", state.steamPressure)
        let sgTemp = String(format: "%.0f\u{00B0}C", state.steamTemp)
        let sgActive = state.steamPressure > 0.2
        let sgLvlColor = sgLevelColor(sgLevelAvg)
        let sgBorder: TerminalColor? = sgLvlColor == .danger ? .danger : (sgLvlColor == .warning ? .warning : nil)
        drawComponent(buffer: buffer, x: sgX, y: topY, w: bw, h: bh,
                      title: "STEAM GENERATORS",
                      lines: [
                          (sgPress, .normal),
                          (sgTemp, .normal),
                          (sgLevel, sgLvlColor),
                          (String(format: "%.0f kg/s", state.steamFlow), .normal),
                      ], active: sgActive, borderColor: sgBorder)

        // Arrow SG → Turbine
        let hasSteam = state.steamFlow > 1
        drawArrow(buffer: buffer, x: sgX + bw, y: arrowY, length: gap, label: "", flowing: hasSteam)

        // Turbine
        let turbSpin = state.turbineRPM > 10 ? String(spinner(t)) : "\u{00B7}"
        let turbRPM = String(format: "%.0f RPM", state.turbineRPM)
        let govStr = String(format: "Gov: %.0f%%", state.turbineGovernor * 100.0)
        let turbActive = state.turbineRPM > 10
        drawComponent(buffer: buffer, x: turbX, y: topY, w: bw, h: bh,
                      title: "TURBINE",
                      lines: [
                          ("   [ \(turbSpin) ]", turbActive ? .bright : .dim),
                          (turbRPM, .normal),
                          (govStr, .normal),
                      ], active: turbActive)

        // Arrow Turbine → Generator
        drawArrow(buffer: buffer, x: turbX + bw, y: arrowY, length: gap, label: "", flowing: turbActive)

        // Generator
        let grossMW = String(format: "%.1f MW(e)", state.grossPower)
        let netMW = String(format: "Net: %.1f MW", state.netPower)
        let freqStr = String(format: "%.2f Hz", state.generatorFrequency)
        let gridStr = state.generatorConnected ? "GRID: SYNC" : "GRID: OFF"
        let genActive = state.grossPower > 0.1
        let genFreqColor = state.generatorFrequency > 0.1 ? deviationColor(value: state.generatorFrequency, nominal: 60.0, warning: 0.5, danger: 1.5) : .normal
        let genNetColor: TerminalColor = state.netPower < 0 ? .danger : .normal
        let genBorder: TerminalColor? = genFreqColor == .danger || genNetColor == .danger ? .danger :
                                         genFreqColor == .warning ? .warning : nil
        drawComponent(buffer: buffer, x: genX, y: topY, w: bw, h: bh,
                      title: "GENERATOR",
                      lines: [
                          (grossMW, genActive ? .bright : .normal),
                          (netMW, genNetColor),
                          (freqStr, genFreqColor),
                          (gridStr, state.generatorConnected ? .bright : .dim),
                      ], active: genActive, borderColor: genBorder)

        // Arrow Generator → Grid
        if genX + bw + 2 < left + width {
            let gridArrowLen = min(5, left + width - genX - bw)
            drawArrow(buffer: buffer, x: genX + bw, y: arrowY, length: gridArrowLen, label: "", flowing: state.generatorConnected)
        }

        // ── Vertical connections ──

        // Turbine exhaust down to Condenser
        let turbMidX = turbX + bw / 2
        for row in (topY + bh)..<botY {
            buffer.putChar(x: turbMidX, y: row, char: "\u{2502}", fg: hasSteam ? .normal : .dim) // │
        }
        buffer.putChar(x: turbMidX, y: botY - 1, char: "\u{25BC}", fg: hasSteam ? .normal : .dim) // ▼

        // Feed pumps up to Steam Gen
        let sgMidX = sgX + bw / 2
        for row in (topY + bh)..<botY {
            buffer.putChar(x: sgMidX, y: row, char: "\u{2502}", fg: hasFlow ? .normal : .dim) // │
        }
        buffer.putChar(x: sgMidX, y: topY + bh, char: "\u{25B2}", fg: hasFlow ? .normal : .dim) // ▲

        // ── Bottom row: Feed Pumps ← Condenser ← Tertiary Pumps ──

        // Feed Pumps (aligned under SG)
        let fpRunning = state.feedPumps.filter { $0.running }.count
        var fpSpinners = ""
        for i in 0..<3 {
            let ch = state.feedPumps[i].running ? String(spinner(t, offset: i + 5)) : "\u{00B7}"
            fpSpinners += " \(ch)"
        }
        drawComponent(buffer: buffer, x: sgX, y: botY, w: bw, h: bh,
                      title: "FEED PUMPS",
                      lines: [
                          ("P:" + fpSpinners, fpRunning > 0 ? .bright : .dim),
                          ("\(fpRunning)/3 running", .normal),
                          (String(format: "FW: %.0f\u{00B0}C", state.feedwaterTemp), .normal),
                      ], active: fpRunning > 0)

        // Arrow Condenser → Feed Pumps (left-pointing)
        drawArrowLeft(buffer: buffer, x: sgX + bw, y: botY + bh / 2, length: gap, label: "", flowing: fpRunning > 0)

        // Condenser (aligned under Turbine)
        let condPress = String(format: "%.3f MPa", state.condenserPressure)
        let condTemp = String(format: "%.1f\u{00B0}C", state.condenserTemp)
        drawComponent(buffer: buffer, x: turbX, y: botY, w: bw, h: bh,
                      title: "CONDENSER",
                      lines: [
                          (condPress, .normal),
                          (condTemp, .normal),
                      ], active: hasSteam)

        // Arrow Tertiary Pumps → Condenser (left-pointing)
        let cwRunning = state.coolingWaterPumps.filter { $0.running }.count
        drawArrowLeft(buffer: buffer, x: turbX + bw, y: botY + bh / 2, length: gap, label: "", flowing: cwRunning > 0)

        // Tertiary Pumps (aligned under Generator)
        var cwSpinners = ""
        for i in 0..<2 {
            let ch = state.coolingWaterPumps[i].running ? String(spinner(t, offset: i + 8)) : "\u{00B7}"
            cwSpinners += " \(ch)"
        }
        let cwFlowStr = String(format: "%.0f kg/s", state.coolingWaterFlow)
        drawComponent(buffer: buffer, x: genX, y: botY, w: bw, h: bh,
                      title: "TERTIARY PUMPS",
                      lines: [
                          ("P:" + cwSpinners, cwRunning > 0 ? .bright : .dim),
                          ("\(cwRunning)/2 running", .normal),
                          (cwFlowStr, .normal),
                      ], active: cwRunning > 0)

        // ── Diesels (small note below diagram) ──
        let dieselY = botY + bh + 1
        if dieselY < top + height {
            let d1 = state.dieselGenerators[0]
            let d2 = state.dieselGenerators[1]
            let d1status = d1.available ? "RUN" : (d1.running ? "START" : "OFF")
            let d2status = d2.available ? "RUN" : (d2.running ? "START" : "OFF")
            buffer.putString(x: left, y: dieselY, string: "DG-1:\(d1status) DG-2:\(d2status)", fg: .dim)
        }

    }

    // MARK: - Core View

    private static func renderCore(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        // Split layout: left text (80 cols), right raster diagram
        let textWidth = 78
        var row = top

        // --- Left half: condensed text data ---

        // Temperatures
        buffer.putString(x: left, y: row, string: "CORE TEMPERATURES", fg: .bright)
        row += 1
        let fuelT = String(format: "%.1f", state.fuelTemp)
        let cladT = String(format: "%.1f", state.claddingTemp)
        let fuelTColor = thresholdColor(value: state.fuelTemp, warning: 2200, danger: 2600)
        let cladTColor = thresholdColor(value: state.claddingTemp, warning: 400, danger: 800)
        buffer.putString(x: left + 2, y: row, string: "Fuel: \(fuelT) \u{00B0}C", fg: fuelTColor)
        buffer.putString(x: left + 24, y: row, string: "Cladding: \(cladT) \u{00B0}C", fg: cladTColor)
        row += 2

        // Adjuster rod positions (compact, no progress bars)
        buffer.putString(x: left, y: row, string: "ADJUSTER RODS (0%=OUT 100%=IN)", fg: .bright)
        row += 1
        let bankNames = ["A", "B", "C", "D"]
        var adjLine = "  "
        for (i, name) in bankNames.enumerated() {
            let pos = 1.0 - state.adjusterPositions[i]
            adjLine += String(format: "%@:%6.1f%%", name, pos * 100.0)
            if i < 3 { adjLine += "   " }
        }
        buffer.putString(x: left, y: row, string: adjLine, fg: .normal)
        row += 2

        // MCA positions (compact)
        buffer.putString(x: left, y: row, string: "MECHANICAL CONTROL ABSORBERS (0%=OUT 100%=IN)", fg: .bright)
        row += 1
        var mcaLine = "  "
        for i in 0..<2 {
            let pos = 1.0 - state.mcaPositions[i]
            mcaLine += String(format: "MCA-%d:%6.1f%%", i + 1, pos * 100.0)
            if i < 1 { mcaLine += "   " }
        }
        buffer.putString(x: left, y: row, string: mcaLine, fg: .normal)
        row += 2

        // Shutoff rods
        buffer.putString(x: left, y: row, string: "SHUTOFF RODS", fg: .bright)
        row += 1
        let sorStatus: String
        let sorColor: TerminalColor
        if state.scramActive {
            sorStatus = "SCRAM - \(String(format: "%.0f%%", state.shutoffRodInsertionFraction * 100.0)) ins."
            sorColor = .danger
        } else if state.shutoffRodsInserted {
            sorStatus = "FULLY INSERTED"
            sorColor = .normal
        } else {
            sorStatus = "WITHDRAWN"
            sorColor = .bright
        }
        buffer.putString(x: left + 2, y: row, string: sorStatus, fg: sorColor)
        row += 2

        // Zone controllers (compact, no progress bars)
        buffer.putString(x: left, y: row, string: "ZONE CONTROLLERS (fill %)", fg: .bright)
        row += 1
        let zonesPerRow = 3
        for zoneStart in stride(from: 0, to: state.zoneControllerFills.count, by: zonesPerRow) {
            var line = "  "
            for z in zoneStart..<min(zoneStart + zonesPerRow, state.zoneControllerFills.count) {
                let fill = state.zoneControllerFills[z]
                line += String(format: "Z%d:%4.0f%%", z + 1, fill)
                if z < min(zoneStart + zonesPerRow, state.zoneControllerFills.count) - 1 { line += "   " }
            }
            buffer.putString(x: left, y: row, string: line, fg: .normal)
            row += 1
        }
        row += 1

        // Reactivity breakdown
        buffer.putString(x: left, y: row, string: "REACTIVITY (mk)", fg: .bright)
        row += 1

        // Compute individual components
        var adjMk: Double = 0.0
        for i in 0..<4 {
            adjMk += CANDUConstants.adjusterBankWorth * Reactivity.rodWorthExtracted(state.adjusterPositions[i])
        }
        var mcaMk: Double = 0.0
        for i in 0..<2 {
            mcaMk += CANDUConstants.mcaWorth * Reactivity.rodWorthExtracted(state.mcaPositions[i])
        }
        let zoneWorthPerUnit = CANDUConstants.zoneControlTotalWorth / 6.0
        var zoneMk: Double = 0.0
        for i in 0..<6 {
            let dev = (50.0 - state.zoneControllerFills[i]) / 50.0
            zoneMk += zoneWorthPerUnit * dev * 0.5
        }
        var sorMk: Double = 0.0
        if state.shutoffRodInsertionFraction > 0.0 {
            sorMk = -CANDUConstants.shutoffRodWorth * Reactivity.rodWorthExtracted(state.shutoffRodInsertionFraction)
        }

        let adjStr = String(format: "Adj:%+6.1f", adjMk)
        let mcaStr = String(format: "MCA:%+6.1f", mcaMk)
        let zoneStr = String(format: "Zone:%+5.1f", zoneMk)
        buffer.putString(x: left + 2, y: row, string: adjStr, fg: .normal)
        buffer.putString(x: left + 16, y: row, string: mcaStr, fg: .normal)
        buffer.putString(x: left + 30, y: row, string: zoneStr, fg: .normal)
        row += 1

        let sorStr = String(format: "SOR:%+6.1f", sorMk)
        let fdbkStr = String(format: "Fdbk:%+5.1f", state.feedbackReactivity)
        let xeStr = String(format: "Xe:%+6.1f", state.xenonReactivity)
        let sorMkColor: TerminalColor = sorMk < -1 ? .danger : .normal
        buffer.putString(x: left + 2, y: row, string: sorStr, fg: sorMkColor)
        buffer.putString(x: left + 16, y: row, string: fdbkStr, fg: .normal)
        buffer.putString(x: left + 30, y: row, string: xeStr, fg: .normal)
        row += 1

        let totalStr = String(format: "TOTAL: %+.2f mk", state.totalReactivity)
        let totalColor = deviationColor(value: state.totalReactivity, nominal: 0, warning: 3, danger: 7)
        buffer.putString(x: left + 2, y: row, string: totalStr, fg: totalColor)

        // --- Right half: raster diagram ---
        // The diagram region starts after the text area
        let diagramGridX = left + textWidth + 2
        let diagramGridY = top
        let diagramGridWidth = left + width - diagramGridX
        let diagramGridHeight = height

        // Convert from content-area coords to absolute grid coords
        // renderCore receives left/top as content offsets within the right panel box
        // (left = rightPanelLeft + 2, top = mainDisplayTop + 2)
        // The grid coords passed to CoreDiagramData must be absolute buffer positions
        buffer.coreDiagram = CoreDiagramData(
            gridX: diagramGridX,
            gridY: diagramGridY,
            gridWidth: diagramGridWidth,
            gridHeight: diagramGridHeight,
            adjusterPositions: state.adjusterPositions,
            mcaPositions: state.mcaPositions,
            zoneFills: state.zoneControllerFills,
            shutoffInsertion: state.shutoffRodInsertionFraction,
            scramActive: state.scramActive
        )
    }

    // MARK: - Primary View

    private static func renderPrimary(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        var row = top

        buffer.putString(x: left, y: row, string: "PRIMARY HEAT TRANSPORT (D2O)", fg: .bright)
        row += 2

        // System parameters
        let inletT = String(format: "%.1f", state.primaryInletTemp)
        let outletT = String(format: "%.1f", state.primaryOutletTemp)
        let pressure = String(format: "%.2f", state.primaryPressure)
        let flow = String(format: "%.0f", state.primaryFlowRate)
        let deltaT = state.primaryOutletTemp - state.primaryInletTemp
        let deltaTStr = String(format: "%.1f", deltaT)
        let pPressColor = deviationColor(value: state.primaryPressure, nominal: CANDUConstants.primaryPressureRated, warning: 1.5, danger: 3.0)
        buffer.putString(x: left + 2, y: row, string: "Inlet:    \(inletT) \u{00B0}C", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Outlet:   \(outletT) \u{00B0}C", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Delta-T:  \(deltaTStr) \u{00B0}C", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Pressure: \(pressure) MPa", fg: pPressColor)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Flow:     \(flow) kg/s", fg: .normal)
        row += 2

        // Pump details
        buffer.putString(x: left, y: row, string: "PHT PUMPS", fg: .bright)
        row += 1

        // Header
        buffer.putString(x: left + 2, y: row, string: "Pump   Status   RPM     Power   Flow", fg: .dim)
        row += 1
        buffer.drawHorizontalLine(x: left + 2, y: row, width: 42, fg: .dim)
        row += 1

        for (i, pump) in state.primaryPumps.enumerated() {
            let status: String
            let statusColor: TerminalColor
            if pump.tripped {
                status = "TRIP  "
                statusColor = .danger
            } else if pump.running {
                status = "RUN   "
                statusColor = .bright
            } else {
                status = "STOP  "
                statusColor = state.thermalPower > 10 ? .warning : .dim
            }

            let rpmStr = String(format: "%6.0f", pump.rpm)
            let rpmFraction = pump.rpm / CANDUConstants.pumpRatedRPM
            let estimatedPower = CANDUConstants.pumpMotorPower * pow(rpmFraction, 3)
            let estimatedFlow = CANDUConstants.pumpRatedFlow * rpmFraction
            let powerStr = String(format: "%4.1fMW", estimatedPower)
            let flowStr = String(format: "%5.0fkg/s", estimatedFlow)

            buffer.putString(x: left + 2, y: row, string: "P-\(i+1)    ", fg: .normal)
            buffer.putString(x: left + 9, y: row, string: status, fg: statusColor)
            buffer.putString(x: left + 17, y: row, string: rpmStr, fg: .normal)
            buffer.putString(x: left + 25, y: row, string: powerStr, fg: .normal)
            buffer.putString(x: left + 33, y: row, string: flowStr, fg: .normal)
            row += 1
        }
        row += 1

        // RPM bar charts
        buffer.putString(x: left, y: row, string: "PUMP RPM", fg: .bright)
        row += 1
        let barWidth = 22
        for (i, pump) in state.primaryPumps.enumerated() {
            let label = String(format: "P-%d:", i + 1)
            buffer.putString(x: left + 2, y: row, string: label, fg: .normal)
            buffer.drawProgressBar(x: left + 6, y: row, width: barWidth, value: pump.rpm, maxValue: CANDUConstants.pumpRatedRPM, fg: .bright)
            let pctStr = String(format: " %.0f%%", (pump.rpm / CANDUConstants.pumpRatedRPM) * 100.0)
            buffer.putString(x: left + 6 + barWidth, y: row, string: pctStr, fg: .normal)
            row += 1
        }
    }

    // MARK: - Secondary View

    private static func renderSecondary(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        var row = top

        buffer.putString(x: left, y: row, string: "SECONDARY SYSTEM (STEAM)", fg: .bright)
        row += 2

        // Steam generators
        buffer.putString(x: left, y: row, string: "STEAM GENERATORS", fg: .bright)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "SG    Level   Press     Temp", fg: .dim)
        row += 1
        buffer.drawHorizontalLine(x: left + 2, y: row, width: 35, fg: .dim)
        row += 1

        for i in 0..<state.sgLevels.count {
            let level = state.sgLevels[i]
            let levelStr = String(format: "%5.1f%%", level)
            let pressStr = String(format: "%5.2f MPa", state.steamPressure)
            let tempStr = String(format: "%5.1f\u{00B0}C", state.steamTemp)
            let levelColor = sgLevelColor(level)

            buffer.putString(x: left + 2, y: row, string: "SG-\(i+1)  ", fg: .normal)
            buffer.putString(x: left + 8, y: row, string: levelStr, fg: levelColor)
            buffer.putString(x: left + 16, y: row, string: pressStr, fg: .normal)
            buffer.putString(x: left + 26, y: row, string: tempStr, fg: .normal)
            row += 1
        }
        row += 1

        // SG Level bars
        buffer.putString(x: left, y: row, string: "SG LEVELS", fg: .bright)
        row += 1
        let barWidth = 22
        for i in 0..<state.sgLevels.count {
            let label = String(format: "SG-%d:", i + 1)
            buffer.putString(x: left + 2, y: row, string: label, fg: .normal)
            let sgc = sgLevelColor(state.sgLevels[i])
            let barColor: TerminalColor = sgc == .normal ? .bright : sgc
            buffer.drawProgressBar(x: left + 7, y: row, width: barWidth, value: state.sgLevels[i], maxValue: 100.0, fg: barColor)
            let pctStr = String(format: " %.1f%%", state.sgLevels[i])
            buffer.putString(x: left + 7 + barWidth, y: row, string: pctStr, fg: .normal)
            row += 1
        }
        row += 1

        // Feed pumps
        buffer.putString(x: left, y: row, string: "FEED WATER PUMPS", fg: .bright)
        row += 1
        for (i, pump) in state.feedPumps.enumerated() {
            let status = pump.running ? "RUN" : "STOP"
            let statusColor: TerminalColor = pump.running ? .bright : (state.thermalPower > 10 ? .warning : .dim)
            let flowStr = String(format: "%.0f kg/s", pump.flowRate)
            buffer.putString(x: left + 2, y: row, string: "FW-\(i+1): \(status)  \(flowStr)", fg: statusColor)
            row += 1
        }
        row += 1

        // Turbine
        buffer.putString(x: left, y: row, string: "TURBINE / GOVERNOR", fg: .bright)
        row += 1
        let turbRPM = String(format: "%.0f", state.turbineRPM)
        buffer.putString(x: left + 2, y: row, string: "RPM: \(turbRPM) / \(String(format: "%.0f", CANDUConstants.turbineRatedRPM))", fg: .normal)
        row += 1
        let govPos = String(format: "%.1f%%", state.turbineGovernor * 100.0)
        buffer.putString(x: left + 2, y: row, string: "Governor: \(govPos)", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Gov: ", fg: .normal)
        buffer.drawProgressBar(x: left + 7, y: row, width: barWidth, value: state.turbineGovernor, maxValue: 1.0, fg: .bright)
        row += 2

        // Condenser
        buffer.putString(x: left, y: row, string: "CONDENSER", fg: .bright)
        row += 1
        let condP = String(format: "%.4f", state.condenserPressure)
        let condT = String(format: "%.1f", state.condenserTemp)
        buffer.putString(x: left + 2, y: row, string: "Press: \(condP) MPa", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Temp:  \(condT) \u{00B0}C", fg: .normal)
    }

    // MARK: - Electrical View

    private static func renderElectrical(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        var row = top

        buffer.putString(x: left, y: row, string: "ELECTRICAL SYSTEMS", fg: .bright)
        row += 2

        // Generator
        buffer.putString(x: left, y: row, string: "MAIN GENERATOR", fg: .bright)
        row += 1
        let gross = String(format: "%.1f", state.grossPower)
        let rated = String(format: "%.0f", CANDUConstants.ratedGrossElectrical)
        buffer.putString(x: left + 2, y: row, string: "Gross: \(gross) / \(rated) MW(e)", fg: .normal)
        row += 1
        let barWidth = 25
        buffer.putString(x: left + 2, y: row, string: "Out: ", fg: .normal)
        buffer.drawProgressBar(x: left + 7, y: row, width: barWidth, value: state.grossPower, maxValue: CANDUConstants.ratedGrossElectrical, fg: .bright)
        row += 1
        let freq = String(format: "%.2f", state.generatorFrequency)
        let freqColor: TerminalColor = state.generatorFrequency > 0.1 ? deviationColor(value: state.generatorFrequency, nominal: 60.0, warning: 0.5, danger: 1.5) : .normal
        buffer.putString(x: left + 2, y: row, string: "Freq: \(freq) Hz (60.00)", fg: freqColor)
        row += 1
        let connected = state.generatorConnected ? "YES" : "NO"
        buffer.putString(x: left + 2, y: row, string: "Grid Sync: \(connected)", fg: .normal)
        row += 2

        // Station service
        buffer.putString(x: left, y: row, string: "STATION SERVICE", fg: .bright)
        row += 1
        let service = String(format: "%.1f", state.stationServiceLoad)
        buffer.putString(x: left + 2, y: row, string: "Load: \(service) MW", fg: .normal)
        row += 1

        let pumpPower = state.primaryPumps.filter({ $0.running }).count
        let phtLoad = String(format: "%.1f", Double(pumpPower) * CANDUConstants.pumpMotorPower)
        buffer.putString(x: left + 4, y: row, string: "PHT (\(pumpPower)): \(phtLoad) MW", fg: .dim)
        row += 1
        let cwPumps = state.coolingWaterPumps.filter({ $0.running }).count
        let cwLoad = String(format: "%.1f", Double(cwPumps) * CANDUConstants.coolingWaterPumpPower)
        buffer.putString(x: left + 4, y: row, string: "CW (\(cwPumps)):  \(cwLoad) MW", fg: .dim)
        row += 2

        // Net output
        buffer.putString(x: left, y: row, string: "NET OUTPUT", fg: .bright)
        row += 1
        let net = String(format: "%.1f", state.netPower)
        let netRated = String(format: "%.0f", CANDUConstants.ratedNetElectrical)
        let netColor: TerminalColor = state.netPower < 0 ? .danger : .normal
        buffer.putString(x: left + 2, y: row, string: "Net: \(net) / \(netRated) MW(e)", fg: netColor)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Net: ", fg: .normal)
        buffer.drawProgressBar(x: left + 7, y: row, width: barWidth, value: max(state.netPower, 0), maxValue: CANDUConstants.ratedNetElectrical, fg: netColor == .danger ? .danger : .bright)
        row += 2

        // Diesel generators
        buffer.putString(x: left, y: row, string: "DIESEL GENERATORS", fg: .bright)
        row += 1
        for (i, dg) in state.dieselGenerators.enumerated() {
            let status: String
            let statusColor: TerminalColor
            if dg.available {
                status = "AVAIL"
                statusColor = .bright
            } else if dg.running {
                let elapsed = state.elapsedTime - dg.startTime
                let remaining = max(CANDUConstants.dieselStartTime - elapsed, 0)
                status = "START(\(String(format: "%.0f", remaining))s)"
                statusColor = .normal
            } else {
                status = "OFF"
                statusColor = .dim
            }
            let power = String(format: "%.1f", dg.power)
            let fuelPct = String(format: "%.0f", dg.fuelLevel * 100.0)
            let fuelColor: TerminalColor = dg.fuelLevel < 0.10 ? .danger : (dg.fuelLevel < 0.25 ? .warning : .dim)
            buffer.putString(x: left + 2, y: row, string: "DG-\(i+1): \(status) \(power)MW", fg: statusColor)
            buffer.putString(x: left + 30, y: row, string: "Fuel: \(fuelPct)%", fg: fuelColor)
            row += 1
        }
    }

    // MARK: - Alarm Log View

    private static func renderAlarmLog(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        var row = top

        buffer.putString(x: left, y: row, string: "ALARM LOG (\(state.alarms.count))", fg: .bright)
        row += 1
        buffer.drawHorizontalLine(x: left, y: row, width: min(width, 80), fg: .dim)
        row += 1

        // Header
        buffer.putString(x: left, y: row, string: "TIME        MESSAGE", fg: .dim)
        row += 1

        let maxLines = height - 4
        let maxMsgWidth = min(width - 14, 100)

        // Show alarms from most recent to oldest
        let displayAlarms = state.alarms.suffix(maxLines).reversed()
        for alarm in displayAlarms {
            if row >= top + height { break }
            let timeStr = formatElapsedTime(alarm.time)
            let msg = String(alarm.message.prefix(maxMsgWidth))
            let color: TerminalColor = alarm.message.contains("[TRIP]") ? .danger :
                                       alarm.message.contains("[ALARM]") ? .warning : .normal
            buffer.putString(x: left, y: row, string: timeStr, fg: .dim)
            buffer.putString(x: left + 10, y: row, string: msg, fg: color)
            row += 1
        }

        if state.alarms.isEmpty {
            buffer.putString(x: left, y: row, string: "No alarms recorded.", fg: .dim)
        }
    }

    // MARK: - Command Area

    private static func renderCommandArea(buffer: TerminalBuffer, commandLine: TerminalCommandLine, intellisense: [String], commandOutput: [String], scrollOffset: Int = 0) {
        let left = 0
        let top = commandAreaTop
        let width = TerminalBuffer.width
        let height = commandAreaHeight

        // Draw border
        buffer.drawBox(x: left, y: top, width: width, height: height, fg: .dim)

        // Title with scroll indicator
        if scrollOffset > 0 {
            buffer.putString(x: left + 2, y: top, string: " COMMAND [\(scrollOffset)\u{2191}] ", fg: .input)
        } else {
            buffer.putString(x: left + 2, y: top, string: " COMMAND ", fg: .input)
        }

        // Command output with scroll offset
        let outputLines = height - 4
        let endIndex = max(commandOutput.count - scrollOffset, 0)
        let startIndex = max(endIndex - outputLines, 0)
        let visibleOutput = startIndex < endIndex ? Array(commandOutput[startIndex..<endIndex]) : []
        var row = top + 1
        for line in visibleOutput {
            let truncated = String(line.prefix(width - 4))
            buffer.putString(x: left + 2, y: row, string: truncated, fg: .dim)
            row += 1
        }

        // Horizontal separator above input
        let inputRow = top + height - 3
        buffer.drawHorizontalLine(x: left + 1, y: inputRow, width: width - 2, fg: .dim)

        // Command prompt and input
        let promptRow = top + height - 2

        if commandLine.isSearching {
            // Reverse incremental search mode
            let query = commandLine.searchQuery
            let prefix = "(search)'\(query)': "
            let matchText = commandLine.searchMatch ?? ""
            let maxMatchWidth = width - 4 - prefix.count
            let displayMatch = String(matchText.prefix(max(maxMatchWidth, 0)))

            buffer.putString(x: left + 2, y: promptRow, string: prefix, fg: .dim)
            buffer.putString(x: left + 2 + prefix.count, y: promptRow, string: displayMatch, fg: .input)

            // Cursor on the search query
            let cursorX = left + 2 + 9 + query.count  // after "(search)'"
            if cursorX < left + width - 2 {
                buffer.putChar(x: cursorX, y: promptRow, char: "'", fg: .background, bg: .input)
            }
        } else {
            buffer.putString(x: left + 2, y: promptRow, string: "> ", fg: .input)

            let inputText = commandLine.currentText
            let maxInputWidth = width - 6
            let displayText = String(inputText.prefix(maxInputWidth))
            buffer.putString(x: left + 4, y: promptRow, string: displayText, fg: .input)

            // Cursor (shown as a bright block character)
            let cursorX = left + 4 + min(commandLine.cursorPosition, maxInputWidth)
            if cursorX < left + width - 2 {
                let cursorChar: Character = commandLine.cursorPosition < inputText.count
                    ? Character(String(inputText[inputText.index(inputText.startIndex, offsetBy: commandLine.cursorPosition)]))
                    : "_"
                buffer.putChar(x: cursorX, y: promptRow, char: cursorChar, fg: .background, bg: .input)
            }
        }

        // Intellisense suggestions (bottom row)
        if !intellisense.isEmpty {
            let suggestRow = top + height - 1
            // Combine suggestions into a single line
            let maxSuggestions = 5
            let suggestions = intellisense.prefix(maxSuggestions)
            var suggestStr = suggestions.joined(separator: "  |  ")
            if intellisense.count > maxSuggestions {
                suggestStr += "  | ..."
            }
            let truncated = String(suggestStr.prefix(width - 4))
            // Overwrite over the box border line for the suggestions
            buffer.fillRect(x: left + 1, y: suggestRow, width: width - 2, height: 1, char: " ", fg: .dim, bg: .background)
            buffer.putString(x: left + 2, y: suggestRow, string: truncated, fg: .dim)
        }
    }

    // MARK: - Order Hints

    /// Returns contextual hint lines for the current order based on reactor state.
    private static func orderHint(state: ReactorState) -> [String] {
        let order = state.currentOrder

        if order.contains("SCRAM ACTIVE") {
            return ["Maintain cooling water flow"]
        }

        if order.contains("SHUTDOWN COMPLETE") {
            return ["Monitor decay heat removal"]
        }

        if order.contains("COMMENCE REACTOR STARTUP") {
            // Guide through graduated startup prerequisites
            // On diesel (10 MW): use minimal pump RPM to conserve power
            let dieselsRunning = state.dieselGenerators.filter { $0.available }.count
            if dieselsRunning == 0 {
                return ["> start aux.diesel.*"]
            }
            if dieselsRunning < 2 && !state.dieselGenerators.allSatisfy({ $0.running || $0.startTime >= 0 }) {
                return ["> start aux.diesel.*"]
            }
            // Cooling water pump at minimal RPM (trivial load on diesel)
            let cwRunning = state.coolingWaterPumps.filter { $0.running }.count
            if cwRunning == 0 {
                return ["> set tertiary.pump.1.rpm 150",
                        "  (low RPM — stay under 10 MW DG)"]
            }
            // Primary pumps at minimal RPM, one at a time
            let phtRunning = state.primaryPumps.filter { $0.running }.count
            if phtRunning == 0 {
                return ["> set primary.pump.1.rpm 150",
                        "  (low RPM — stay under 10 MW DG)"]
            }
            if phtRunning < 2 {
                for i in 0..<4 {
                    if !state.primaryPumps[i].running {
                        return ["> set primary.pump.\(i+1)",
                                "  .rpm 150"]
                    }
                }
            }
            // Feed pump is the largest single load (~3 MW)
            let fpRunning = state.feedPumps.filter { $0.running }.count
            if fpRunning == 0 {
                return ["> start secondary.feed-pump.1.auto"]
            }
            // Withdraw shutoff rods to begin approach to criticality
            if state.shutoffRodsInserted {
                return ["> set core.shutoff-rods.pos 0"]
            }
            return ["Waiting for conditions..."]
        }

        if order.contains("ACHIEVE CRITICALITY") {
            // Ensure cooling flow is established before adding reactivity
            let phtRunning = state.primaryPumps.filter { $0.running }.count
            if phtRunning == 0 {
                return ["> set primary.pump.1.rpm 150",
                        "  (need flow before rods!)"]
            }
            let cwRunning = state.coolingWaterPumps.filter { $0.running }.count
            if cwRunning == 0 {
                return ["> set tertiary.pump.1.rpm 150",
                        "  (need CW flow before rods!)"]
            }

            // Withdraw adjuster banks one at a time
            // (all at once adds ~15 mk instantly → high log rate SCRAM)
            let bankNames = ["a", "b", "c", "d"]
            for (i, name) in bankNames.enumerated() {
                let target = state.adjusterTargetPositions[i]
                let actual = state.adjusterPositions[i]
                // Bank is still moving toward target
                if target > 0.9 && actual < 0.9 {
                    let pct = Int(actual * 100)
                    return ["Bank \(name.uppercased()) withdrawing... \(pct)%"]
                }
                // Bank hasn't been commanded yet
                if target < 0.9 {
                    let pct = state.thermalPowerFraction * 100.0
                    if pct > 0.5 {
                        return ["Power rising — wait for it",
                                "to stabilize before bank \(name.uppercased())"]
                    }
                    var lines = ["> set core.adjuster-rods",
                                 "  .bank-\(name).pos 0"]
                    if state.timeAcceleration > 1.0 {
                        lines.append("  (consider: speed 0.5)")
                    }
                    return lines
                }
            }
            // MCAs — one at a time
            for i in 0..<2 {
                let target = state.mcaTargetPositions[i]
                let actual = state.mcaPositions[i]
                if target > 0.9 && actual < 0.9 {
                    let pct = Int(actual * 100)
                    return ["MCA-\(i+1) withdrawing... \(pct)%"]
                }
                if target < 0.9 {
                    let pct = state.thermalPowerFraction * 100.0
                    if pct > 0.5 {
                        return ["Power rising — wait for it",
                                "to stabilize before MCA-\(i+1)"]
                    }
                    return ["> set core.mca.\(i+1).pos 0"]
                }
            }
            let zoneFillHigh = state.zoneControllerFills.allSatisfy { $0 > 60 }
            if zoneFillHigh {
                return ["> set core.zone-controllers",
                        "  .zone-*.fill 50"]
            }
            return ["Monitoring neutron density..."]
        }

        if order.contains("ACHIEVE") && order.contains("FULL POWER") {
            // Extract target percentage
            let pct = state.thermalPowerFraction * 100.0
            if let target = extractPowerTarget(from: order) {
                if state.turbineGovernor < 0.1 && target >= 25.0 {
                    return ["> set secondary.turbine",
                            "  .governor 0.5"]
                }
                if !state.generatorConnected && pct > 5 {
                    return ["Sync generator to grid"]
                }
                // After grid sync: ramp pumps to match power target
                if state.generatorConnected {
                    let pumpRPMTarget: Double
                    if target >= 85 {
                        pumpRPMTarget = 1500
                    } else if target >= 75 {
                        pumpRPMTarget = 1200
                    } else if target >= 50 {
                        pumpRPMTarget = 1000
                    } else {
                        pumpRPMTarget = 500
                    }
                    let maxPrimaryRPM = state.primaryPumps.filter { $0.running }.map { $0.targetRPM }.max() ?? 0
                    if maxPrimaryRPM < pumpRPMTarget {
                        let rpm = Int(pumpRPMTarget)
                        return ["> set primary.pump.*.rpm \(rpm)",
                                "  (ramp flow for \(Int(target))% power)"]
                    }
                    let maxCWRPM = state.coolingWaterPumps.filter { $0.running }.map { $0.targetRPM }.max() ?? 0
                    if maxCWRPM < pumpRPMTarget {
                        let rpm = Int(pumpRPMTarget)
                        return ["> set tertiary.pump.1",
                                "  .rpm \(rpm)"]
                    }
                }
                let diff = pct - target
                if diff < -5 {
                    return ["Withdraw rods / lower zone",
                            "fills to raise power"]
                } else if diff > 5 {
                    return ["Insert rods / raise zone",
                            "fills to lower power"]
                } else {
                    return ["Hold steady — stabilizing"]
                }
            }
            return []
        }

        if order.contains("MAINTAIN 100%") {
            return ["Monitor and hold parameters"]
        }

        if order.contains("REDUCE POWER") {
            let pct = state.thermalPowerFraction * 100.0
            if pct > 65 {
                return ["Insert rods / raise zone",
                        "fills to lower power"]
            }
            return ["Hold steady — stabilizing"]
        }

        if order.contains("ORDERLY SHUTDOWN") {
            if !state.scramActive {
                return ["Insert all rods or 'scram'"]
            }
            return ["Shutting down..."]
        }

        return []
    }

    /// Extract numeric power target from an order string like "ACHIEVE 25% FULL POWER".
    private static func extractPowerTarget(from order: String) -> Double? {
        let parts = order.split(separator: " ")
        for part in parts {
            if part.hasSuffix("%"), let val = Double(part.dropLast()) {
                return val
            }
        }
        return nil
    }

    // MARK: - Threshold Colors

    /// Returns a color based on whether a value exceeds warning/danger thresholds (high = bad).
    private static func thresholdColor(value: Double, warning: Double, danger: Double) -> TerminalColor {
        if value >= danger { return .danger }
        if value >= warning { return .warning }
        return .normal
    }

    /// Returns a color based on whether a value drops below warning/danger thresholds (low = bad).
    private static func thresholdColorLow(value: Double, warning: Double, danger: Double) -> TerminalColor {
        if value <= danger { return .danger }
        if value <= warning { return .warning }
        return .normal
    }

    /// Returns a color based on deviation from a nominal value.
    private static func deviationColor(value: Double, nominal: Double, warning: Double, danger: Double) -> TerminalColor {
        let dev = abs(value - nominal)
        if dev >= danger { return .danger }
        if dev >= warning { return .warning }
        return .normal
    }

    /// Returns a color for SG level (both high and low are bad).
    private static func sgLevelColor(_ level: Double) -> TerminalColor {
        if level < 15 || level > 85 { return .danger }
        if level < 30 || level > 70 { return .warning }
        return .normal
    }

    // MARK: - Utilities

    /// Format elapsed time as HH:MM:SS.
    private static func formatElapsedTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
