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

        // Display current order in compact font (fits ~55 chars — no wrapping needed)
        var nextRow = ordersTop + 1
        buffer.compactStrings.append((x: 2, y: nextRow, text: String(state.currentOrder.prefix(55)), fg: .normal))
        nextRow += 1

        // Display contextual hints in compact font, dimmer than the order
        let hints = orderHint(state: state)
        for hint in hints {
            if nextRow >= ordersTop + ordersHeight - 1 { break }
            buffer.compactStrings.append((x: 2, y: nextRow, text: String(hint.prefix(55)), fg: .dim))
            nextRow += 1
        }
    }

    private static func renderAlarmsBox(buffer: TerminalBuffer, state: ReactorState) {
        let alarmBoxColor: TerminalColor = state.alarms.isEmpty ? .dim :
            (state.alarms.contains { $0.message.contains("[TRIP]") } ? .danger :
             state.alarms.contains { $0.message.contains("[ALARM]") } ? .alarm : .warning)
        buffer.drawBox(x: 0, y: alarmsTop, width: leftPanelWidth, height: alarmsHeight, fg: alarmBoxColor)
        buffer.putString(x: 2, y: alarmsTop, string: " ALARMS ", fg: alarmBoxColor)

        let maxLines = alarmsHeight - 2

        // Show most recent alarms in compact font (fits ~55 chars per line)
        let recentAlarms = state.alarms.suffix(maxLines).reversed()
        var row = alarmsTop + 1
        for alarm in recentAlarms {
            if row >= alarmsTop + alarmsHeight - 1 { break }
            let timeStr = formatElapsedTime(alarm.time)
            let msg = "\(timeStr) \(alarm.message)"
            let color: TerminalColor = alarm.message.contains("[TRIP]") ? .danger :
                                       alarm.message.contains("[ALARM]") ? .alarm : .normal
            buffer.compactStrings.append((x: 2, y: row, text: String(msg.prefix(55)), fg: color))
            row += 1
        }

        if state.alarms.isEmpty {
            buffer.compactStrings.append((x: 2, y: alarmsTop + 1, text: "No active alarms.", fg: .dim))
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
        let bankLabels = ["1", "2", "3", "4"]
        let adjStr = bankLabels.enumerated().map { (i, name) in
            let moving = abs(state.adjusterPositions[i] - state.adjusterTargetPositions[i]) > 0.001
            let suffix = moving ? "*" : " "
            return String(format: "%@:%2.0f%%%@", name, (1.0 - state.adjusterPositions[i]) * 100.0, suffix)
        }.joined(separator: "")
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Adj:", value: adjStr, maxWidth: maxWidth)
        row += 1

        // Shutoff rods (0%=out, 100%=in — same convention as adjusters)
        let sorPct = state.shutoffRodInsertionFraction * 100.0
        let sorStr = state.scramActive ? String(format: "SCRAM %.0f%%", sorPct) : String(format: "%.0f%%", sorPct)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "SORs:", value: sorStr, maxWidth: maxWidth,
                      fg: state.scramActive ? .danger : (sorPct > 50 ? .warning : .dim))
        row += 1

        // Xenon worth
        let xenonStr = String(format: "%.2f mk", nz(state.xenonReactivity, 2))
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Xenon:", value: xenonStr, maxWidth: maxWidth)
        row += 1

        // Total reactivity
        let reactStr = String(format: "%+.2f mk", nz(state.totalReactivity, 2))
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
            let mkStr = String(format: "%+.2f mk", nz(zoneMk, 2))
            let mkColor = deviationColor(value: zoneMk, nominal: 0, warning: 0.15, danger: 0.3)
            buffer.putString(x: zoneTextX + 3 + zoneBarWidth + 1, y: coreRow, string: pctStr, fg: .normal)
            buffer.putString(x: zoneTextX + 3 + zoneBarWidth + 6, y: coreRow, string: mkStr, fg: mkColor)
            coreRow += 1
        }

        // Rod + SOR summary line
        let ovBankLabels = ["1", "2", "3", "4"]
        var adjLine = "Adj "
        for (i, name) in ovBankLabels.enumerated() {
            let adjMoving = abs(state.adjusterPositions[i] - state.adjusterTargetPositions[i]) > 0.001
            adjLine += String(format: "%@:%2.0f%%%@", name, (1.0 - state.adjusterPositions[i]) * 100.0, adjMoving ? "*" : " ")
        }
        adjLine += " "
        for i in 0..<2 {
            let mcaMoving = abs(state.mcaPositions[i] - state.mcaTargetPositions[i]) > 0.001
            adjLine += String(format: "MCA%d:%2.0f%%%@", i + 1, (1.0 - state.mcaPositions[i]) * 100.0, mcaMoving ? "*" : " ")
        }
        buffer.putString(x: zoneTextX, y: coreRow, string: adjLine, fg: .normal)
        coreRow += 1

        let ovSorPct = state.shutoffRodInsertionFraction * 100.0
        let ovSorStr = state.scramActive ? String(format: "SCRAM %.0f%%", ovSorPct) : String(format: "%.0f%%", ovSorPct)
        let ovSorColor: TerminalColor = state.scramActive ? .danger : (ovSorPct > 50 ? .warning : .dim)
        let ovXeStr = String(format: "Xe:%+.1f mk", nz(state.xenonReactivity, 1))
        let ovTotalStr = String(format: "Total:%+.2f mk", nz(state.totalReactivity, 2))
        let ovTotalColor = deviationColor(value: state.totalReactivity, nominal: 0, warning: 3, danger: 7)
        buffer.putString(x: zoneTextX, y: coreRow, string: "SOR: \(ovSorStr)", fg: ovSorColor)
        buffer.putString(x: zoneTextX + 14, y: coreRow, string: ovXeStr, fg: .normal)
        buffer.putString(x: zoneTextX + 28, y: coreRow, string: ovTotalStr, fg: ovTotalColor)

        // ── Flow Diagram Section (below core section) ──
        let flowTop = top + 13
        let topY    = flowTop       // top row of boxes
        let arrowY  = topY + bh / 2 // arrow row (midpoint of boxes)
        let botY    = topY + bh + 2 // bottom row of boxes

        // ── Top row: Core → Primary Pumps → Steam Generators → Turbine → Generator ──

        // Core
        let thermalPower = String(format: "%.0f MW(th)", state.thermalPower)
        let powerPct = String(format: "%.1f%% FP", state.thermalPowerFraction * 100.0)
        let fuelT = String(format: "Fuel: %.0f\u{00B0}C", state.fuelTemp)
        let reactStr = String(format: "%+.2f mk", nz(state.totalReactivity, 2))
        let coreActive = state.thermalPower > 1.0
        let coreFuelColor = coreActive ? thresholdColor(value: state.fuelTemp, warning: 2200, danger: 2600) : .normal
        let coreReactColor = coreActive ? deviationColor(value: state.totalReactivity, nominal: 0, warning: 3, danger: 7) : .normal
        let corePowerColor = coreActive ? thresholdColor(value: state.thermalPowerFraction, warning: 1.03, danger: 1.08) : .normal
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
        let phtAvgRPM = phtRunning > 0
            ? state.primaryPumps.filter { $0.running }.map { $0.rpm }.reduce(0, +) / Double(phtRunning)
            : 0.0
        let phtRPMStr = String(format: "%.0f RPM", phtAvgRPM)
        let phtFlow = String(format: "%.0f kg/s", state.primaryFlowRate)
        let phtPressure = String(format: "%.1f MPa", state.primaryPressure)
        let phtPressColor = deviationColor(value: state.primaryPressure, nominal: CANDUConstants.primaryPressureRated, warning: 1.5, danger: 3.0)
        let phtPumpColor: TerminalColor = phtTripped > 0 ? .danger : (phtRunning == 0 && state.thermalPower > 10 ? .warning : .normal)
        let phtBorder: TerminalColor? = phtTripped > 0 ? .danger : (phtRunning == 0 && state.thermalPower > 10 ? .warning : nil)
        drawComponent(buffer: buffer, x: phtX, y: topY, w: bw, h: bh,
                      title: "PHT PUMPS",
                      lines: [
                          ("P:" + phtSpinners, phtRunning > 0 ? .bright : .dim),
                          (phtRPMStr + "  " + phtFlow, .normal),
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
        let netMW = String(format: "Net: %.1f MW(e)", state.netPower)
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
        let totalFeedFlow = state.feedPumps.reduce(0.0) { $0 + $1.flowRate }
        let fpFlowStr = String(format: "%.0f kg/s", totalFeedFlow)
        drawComponent(buffer: buffer, x: sgX, y: botY, w: bw, h: bh,
                      title: "FEED PUMPS",
                      lines: [
                          ("P:" + fpSpinners, fpRunning > 0 ? .bright : .dim),
                          ("\(fpRunning)/3 running", .normal),
                          (fpFlowStr, .normal),
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
        let cwAvgRPM = cwRunning > 0
            ? state.coolingWaterPumps.filter { $0.running }.map { $0.rpm }.reduce(0, +) / Double(cwRunning)
            : 0.0
        let cwRPMStr = String(format: "%.0f RPM", cwAvgRPM)
        let cwFlowStr = String(format: "%.0f kg/s", state.coolingWaterFlow)
        drawComponent(buffer: buffer, x: genX, y: botY, w: bw, h: bh,
                      title: "CW PUMPS",
                      lines: [
                          ("P:" + cwSpinners, cwRunning > 0 ? .bright : .dim),
                          (cwRPMStr, .normal),
                          (cwFlowStr, .normal),
                      ], active: cwRunning > 0)

        // ── Diesels (small note below diagram) ──
        let dieselY = botY + bh + 1
        if dieselY < top + height {
            let d1 = state.dieselGenerators[0]
            let d2 = state.dieselGenerators[1]
            let d1status = d1.running ? (d1.available ? "RUN" : "START") : "OFF"
            let d2status = d2.running ? (d2.available ? "RUN" : "START") : "OFF"
            let d1Color: TerminalColor = d1.available ? .normal : (d1.running ? .dim : .dim)
            let d2Color: TerminalColor = d2.available ? .normal : (d2.running ? .dim : .dim)
            buffer.putString(x: left, y: dieselY, string: "DG-1: ", fg: .dim)
            buffer.putString(x: left + 6, y: dieselY, string: d1status, fg: d1Color)
            buffer.putString(x: left + 12, y: dieselY, string: "DG-2: ", fg: .dim)
            buffer.putString(x: left + 18, y: dieselY, string: d2status, fg: d2Color)
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
        let bankNames = ["1", "2", "3", "4"]
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

        // Shutoff rods (0%=out, 100%=in)
        buffer.putString(x: left, y: row, string: "SHUTOFF RODS (0%=OUT 100%=IN)", fg: .bright)
        row += 1
        let sorDetailPct = state.shutoffRodInsertionFraction * 100.0
        let sorStatus: String
        let sorColor: TerminalColor
        if state.scramActive {
            sorStatus = String(format: "SCRAM — %.0f%%", sorDetailPct)
            sorColor = .danger
        } else {
            sorStatus = String(format: "%.0f%%", sorDetailPct)
            sorColor = sorDetailPct > 50 ? .warning : .dim
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

        let adjStr = String(format: "Adj:%+6.1f", nz(adjMk, 1))
        let mcaStr = String(format: "MCA:%+6.1f", nz(mcaMk, 1))
        let zoneStr = String(format: "Zone:%+5.1f", nz(zoneMk, 1))
        buffer.putString(x: left + 2, y: row, string: adjStr, fg: .normal)
        buffer.putString(x: left + 16, y: row, string: mcaStr, fg: .normal)
        buffer.putString(x: left + 30, y: row, string: zoneStr, fg: .normal)
        row += 1

        let sorStr = String(format: "SOR:%+6.1f", nz(sorMk, 1))
        let fdbkStr = String(format: "Fdbk:%+5.1f", nz(state.feedbackReactivity, 1))
        let xeStr = String(format: "Xe:%+6.1f", nz(state.xenonReactivity, 1))
        let sorMkColor: TerminalColor = sorMk < -1 ? .danger : .normal
        buffer.putString(x: left + 2, y: row, string: sorStr, fg: sorMkColor)
        buffer.putString(x: left + 16, y: row, string: fdbkStr, fg: .normal)
        buffer.putString(x: left + 30, y: row, string: xeStr, fg: .normal)
        row += 1

        let totalStr = String(format: "TOTAL: %+.2f mk", nz(state.totalReactivity, 2))
        let totalColor = deviationColor(value: state.totalReactivity, nominal: 0, warning: 3, danger: 7)
        buffer.putString(x: left + 2, y: row, string: totalStr, fg: totalColor)

        // --- Right half: raster tile-grid diagram (same style as overview, but larger) ---
        let diagramGridX = left + textWidth + 2
        let diagramGridY = top
        let diagramGridWidth = left + width - diagramGridX
        let diagramGridHeight = height

        buffer.overviewDiagram = CoreDiagramData(
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
            let powerStr = String(format: "%4.1f MW", estimatedPower)
            let flowStr = String(format: "%5.0f kg/s", estimatedFlow)

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
        buffer.putString(x: left, y: row, string: "FEED PUMPS", fg: .bright)
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

        let baseLoadStr = String(format: "%.0f", CANDUConstants.stationServiceBase)
        buffer.putString(x: left + 4, y: row, string: "Base: \(baseLoadStr) MW", fg: .dim)
        row += 1
        let phtPumpsRunning = state.primaryPumps.filter({ $0.running }).count
        var phtPumpLoad: Double = 0
        for pump in state.primaryPumps where pump.running {
            let rpmFrac = pump.rpm / CANDUConstants.pumpRatedRPM
            phtPumpLoad += CANDUConstants.pumpMotorPower * pow(rpmFrac, 3)
        }
        let phtLoadStr = String(format: "%.1f", phtPumpLoad)
        buffer.putString(x: left + 4, y: row, string: "PHT (\(phtPumpsRunning)): \(phtLoadStr) MW", fg: .dim)
        row += 1
        let cwPumpsRunning = state.coolingWaterPumps.filter({ $0.running }).count
        var cwPumpLoad: Double = 0
        for pump in state.coolingWaterPumps where pump.running {
            let rpmFrac = pump.rpm / CANDUConstants.pumpRatedRPM
            cwPumpLoad += CANDUConstants.coolingWaterPumpPower * pow(rpmFrac, 3)
        }
        let cwLoadStr = String(format: "%.1f", cwPumpLoad)
        buffer.putString(x: left + 4, y: row, string: "CW (\(cwPumpsRunning)):  \(cwLoadStr) MW", fg: .dim)
        row += 1
        let fpRunningCount = state.feedPumps.filter({ $0.running }).count
        let fpLoadStr = String(format: "%.1f", Double(fpRunningCount) * 3.0)
        buffer.putString(x: left + 4, y: row, string: "Feed (\(fpRunningCount)): \(fpLoadStr) MW", fg: .dim)
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
            buffer.putString(x: left + 2, y: row, string: "DG-\(i+1): \(status) \(power) MW", fg: statusColor)
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
        buffer.putString(x: left, y: row, string: "TIME      MESSAGE", fg: .dim)
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
                                       alarm.message.contains("[ALARM]") ? .alarm : .normal
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

            if inputText.isEmpty {
                // Blinking cursor then placeholder text
                buffer.putChar(x: left + 4, y: promptRow, char: " ", fg: .background, bg: .input)
                buffer.putString(x: left + 5, y: promptRow, string: "enter command", fg: .dim)
            } else {
                let displayText = String(inputText.prefix(maxInputWidth))
                buffer.putString(x: left + 4, y: promptRow, string: displayText, fg: .input)

                // Cursor (shown as a bright block character)
                let cursorX = left + 4 + min(commandLine.cursorPosition, maxInputWidth)
                if cursorX < left + width - 2 {
                    let cursorChar: Character = commandLine.cursorPosition < inputText.count
                        ? Character(String(inputText[inputText.index(inputText.startIndex, offsetBy: commandLine.cursorPosition)]))
                        : " "
                    buffer.putChar(x: cursorX, y: promptRow, char: cursorChar, fg: .background, bg: .input)
                }

                // Inline ghost text: show first completion suffix after cursor
                if !intellisense.isEmpty, let first = intellisense.first {
                    let lower = inputText.lowercased()
                    let firstLower = first.lowercased()
                    if firstLower.hasPrefix(lower) && first.count > inputText.count {
                        let suffixStart = first.index(first.startIndex, offsetBy: inputText.count)
                        let ghost = String(first[suffixStart...])
                        let ghostX = left + 4 + displayText.count
                        let maxGhost = (left + width - 2) - ghostX
                        if maxGhost > 0 {
                            buffer.putString(x: ghostX, y: promptRow, string: String(ghost.prefix(maxGhost)), fg: .dim)
                        }
                    }
                }
            }
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
            // Primary pumps at minimal RPM (all 4, negligible load at 150)
            let phtRunning = state.primaryPumps.filter { $0.running }.count
            if phtRunning < 4 {
                return ["> set primary.pump.*.rpm 150",
                        "  (all 4, low RPM on diesel)"]
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
                return ["> set primary.pump.*.rpm 150",
                        "  (need flow before rods!)"]
            }

            // After bank 1, ensure adequate cooling flow before adding more reactivity
            let banksOut = state.adjusterTargetPositions.filter { $0 > 0.9 }.count
            let flowFraction = state.primaryFlowRate / CANDUConstants.totalRatedFlow
            if banksOut >= 1 && flowFraction < 0.40 {
                let flowPct = Int(flowFraction * 100)
                return ["> set primary.pump.*.rpm 900",
                        "  (flow \(flowPct)% — need >40% for power rise)"]
            }

            // Withdraw adjuster banks 1-2 (enough for ~30% power with zones at 100%)
            for i in 0..<2 {
                let target = state.adjusterTargetPositions[i]
                let actual = state.adjusterPositions[i]
                if target > 0.9 && actual < 0.9 {
                    let pct = Int(actual * 100)
                    return ["Bank \(i+1) withdrawing... \(pct)%",
                            "  (~\(Int(Double(100 - pct) * 0.6))s remaining)"]
                }
                if target < 0.9 {
                    var lines = ["> set core.adjuster-rods.\(i+1).pos 0"]
                    if state.timeAcceleration > 1.0 {
                        lines.append("  (consider: time 0.5)")
                    }
                    return lines
                }
            }
            // Both banks out — wait for neutron density to rise
            return ["Approaching criticality...",
                    "  (waiting for power to build)"]
        }

        if order.contains("ACHIEVE") && order.contains("FULL POWER") {
            let pct = state.thermalPowerFraction * 100.0
            if let target = extractPowerTarget(from: order) {
                // Before grid sync: get turbine going
                if !state.generatorConnected {
                    if state.turbineGovernor < 0.1 {
                        return ["> set secondary.turbine.governor 1.0"]
                    }
                    let freq = state.generatorFrequency
                    if freq > 59.5 && freq < 60.5 {
                        return ["> start electrical.grid.sync"]
                    }
                    if state.turbineRPM < 100 {
                        return ["Need 0.5 MPa steam to spin turbine",
                                "  wait for power to build"]
                    }
                    return ["Turbine spinning up...",
                            "  \(String(format: "%.1f", freq)) Hz (need 60 Hz)"]
                }
                // After grid sync: stop diesels if still running
                let dieselsRunning = state.dieselGenerators.filter { $0.running }.count
                if dieselsRunning > 0 {
                    return ["> stop aux.diesel.*",
                            "  (grid is supplying station service)"]
                }
                // Start additional feed pumps (need 3 for full power)
                let fpRunning = state.feedPumps.filter { $0.running }.count
                if fpRunning < 3 {
                    let avgSGLevel = state.sgLevels.reduce(0.0, +) / 4.0
                    if fpRunning < 2 || avgSGLevel < 45 {
                        return ["> start secondary.feed-pump.\(fpRunning + 1).auto",
                                "  (need \(3 - fpRunning) more for full power)"]
                    }
                }
                // Ramp pumps to full flow now that grid is available
                let phtFlowFrac = state.primaryFlowRate / CANDUConstants.totalRatedFlow
                if phtFlowFrac < 0.90 {
                    let flowPct = Int(phtFlowFrac * 100)
                    return ["> set primary.pump.*.rpm 1500",
                            "  (flow \(flowPct)% — need full flow)"]
                }
                let cwFlowFrac = state.coolingWaterFlow / CANDUConstants.coolingWaterFlowRated
                if cwFlowFrac < 0.80 {
                    return ["> set tertiary.pump.*.rpm 1500"]
                }
                // Check if more feed pumps needed (SG levels dropping)
                if fpRunning < 3 {
                    let avgSGLevel2 = state.sgLevels.reduce(0.0, +) / 4.0
                    if avgSGLevel2 < 40 {
                        return ["> start secondary.feed-pump.\(fpRunning + 1).auto",
                                "  (SG levels low — add feed pump)"]
                    }
                }
                // Raise power / compensate xenon by lowering zones and withdrawing rods
                let diff = pct - target
                let avgZone = state.zoneControllerFills.reduce(0.0, +) / 6.0
                let banksOut = state.adjusterTargetPositions.filter { $0 > 0.9 }.count
                let mcasOut = state.mcaTargetPositions.filter { $0 > 0.9 }.count
                let xenonMk = state.xenonReactivity
                let needMoreReactivity = diff < -5
                // Proactive: xenon is building and we have unused rods
                let xenonBuilding = xenonMk < -2.0
                    && (banksOut < 4 || mcasOut < 2 || avgZone > 10)

                if needMoreReactivity || xenonBuilding {
                    let reason = needMoreReactivity
                        ? "raise power"
                        : "compensate Xe \(String(format: "%.1f", xenonMk)) mk"
                    // Step size depends on power — large steps at high power cause LOG RATE trip
                    let step: Int = pct > 60 ? 5 : (pct > 30 ? 10 : 20)
                    // First: lower zones from 100 toward 50
                    if avgZone > 55 {
                        let newFill = max(Int(avgZone) - step, 50)
                        var lines = ["> set core.zone-controllers.*.fill \(newFill)",
                                     "  (\(reason))"]
                        if pct > 30 {
                            lines.append("  small steps — LOG RATE trip >15%/s")
                        }
                        return lines
                    }
                    // Then: withdraw more adj banks
                    if banksOut < 4 {
                        let nextBank = banksOut + 1
                        return ["> set core.adjuster-rods.\(nextBank).pos 0",
                                "  (\(reason))"]
                    }
                    // Then: withdraw MCAs
                    if mcasOut < 2 {
                        let nextMCA = mcasOut + 1
                        return ["> set core.mca.\(nextMCA).pos 0",
                                "  (\(reason))"]
                    }
                    // All rods out: lower zones further
                    if avgZone > 10 {
                        let newFill = max(Int(avgZone) - step, 0)
                        var lines = ["> set core.zone-controllers.*.fill \(newFill)",
                                     "  (\(reason))"]
                        if pct > 30 {
                            lines.append("  small steps — LOG RATE trip >15%/s")
                        }
                        return lines
                    }
                    if needMoreReactivity {
                        return ["Power rising..."]
                    }
                } else if diff > 5 {
                    // Power above target — suggest ways to reduce
                    let raiseStep: Int = pct > 60 ? 5 : (pct > 30 ? 10 : 20)
                    if avgZone < 90 {
                        let newFill = min(Int(avgZone) + raiseStep, 100)
                        return ["> set core.zone-controllers.*.fill \(newFill)",
                                "  (reduce power — small steps)"]
                    }
                    if banksOut > 0 {
                        return ["> set core.adjuster-rods.\(banksOut).pos 100",
                                "  (insert rods to reduce power)"]
                    }
                    return ["Power above target — stabilizing"]
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

    /// Returns 0.0 if the value would display as negative zero at the given decimal places.
    private static func nz(_ value: Double, _ decimals: Int) -> Double {
        let scale = pow(10.0, Double(decimals))
        if abs(value * scale) < 0.5 { return 0.0 }
        return value
    }

    /// Format elapsed time as HH:MM:SS.
    private static func formatElapsedTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
