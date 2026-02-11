import Foundation

/// Layout manager that renders the current view to the TerminalBuffer.
///
/// Layout regions:
/// - Left panel (cols 0-59): STATUS/ALARMS area
///   - Orders box (rows 2-5)
///   - Alarms box (rows 7-30)
///   - Key Status box (rows 32-45)
/// - Right top (cols 62-319, rows 0-85): Main display area
/// - Right bottom (cols 62-319, rows 87-95): Command input area
struct TerminalLayout {

    // MARK: - Layout Constants

    // Left panel
    private static let leftPanelLeft = 0
    private static let leftPanelRight = 59
    private static let leftPanelWidth = 60

    // Orders box
    private static let ordersTop = 2
    private static let ordersBottom = 5
    private static let ordersHeight = 4

    // Alarms box
    private static let alarmsTop = 7
    private static let alarmsBottom = 30
    private static let alarmsHeight = 24

    // Key Status box
    private static let keyStatusTop = 32
    private static let keyStatusBottom = 45
    private static let keyStatusHeight = 14

    // Right panel
    private static let rightPanelLeft = 62
    private static let rightPanelRight = 319
    private static let rightPanelWidth = 258

    // Main display area
    private static let mainDisplayTop = 0
    private static let mainDisplayBottom = 49
    private static let mainDisplayHeight = 50

    // Command input area (full width, bottom half)
    private static let commandAreaTop = 51
    private static let commandAreaBottom = 95
    private static let commandAreaHeight = 45

    // MARK: - Render

    /// Render the complete terminal display to the buffer.
    static func render(
        buffer: TerminalBuffer,
        state: ReactorState,
        commandLine: TerminalCommandLine,
        currentView: ViewType,
        intellisense: [String],
        commandOutput: [String]
    ) {
        buffer.clear()

        // Draw left panel
        renderLeftPanel(buffer: buffer, state: state)

        // Draw divider between left and right panels (top section only)
        buffer.drawVerticalLine(x: 60, y: 0, height: commandAreaTop - 1, fg: .dim)

        // Draw main display area
        renderMainDisplay(buffer: buffer, state: state, currentView: currentView)

        // Draw horizontal divider above command area
        buffer.drawHorizontalLine(x: 0, y: commandAreaTop - 1, width: TerminalBuffer.width, fg: .dim)

        // Draw command input area (full width)
        renderCommandArea(buffer: buffer, commandLine: commandLine, intellisense: intellisense, commandOutput: commandOutput)
    }

    // MARK: - Left Panel

    private static func renderLeftPanel(buffer: TerminalBuffer, state: ReactorState) {
        // Title
        buffer.putString(x: 1, y: 0, string: " CANDU-6 REACTOR CONTROL ", fg: .bright)
        buffer.drawHorizontalLine(x: 0, y: 1, width: leftPanelWidth, fg: .dim)

        // Orders box
        renderOrdersBox(buffer: buffer, state: state)

        // Alarms box
        renderAlarmsBox(buffer: buffer, state: state)

        // Key Status box
        renderKeyStatusBox(buffer: buffer, state: state)
    }

    private static func renderOrdersBox(buffer: TerminalBuffer, state: ReactorState) {
        buffer.drawBox(x: 0, y: ordersTop, width: leftPanelWidth, height: ordersHeight, fg: .dim)
        buffer.putString(x: 2, y: ordersTop, string: " ORDERS ", fg: .bright)

        // Display current order (wrap if needed)
        let orderText = state.currentOrder
        let maxWidth = leftPanelWidth - 4
        if orderText.count <= maxWidth {
            buffer.putString(x: 2, y: ordersTop + 1, string: orderText, fg: .bright)
        } else {
            let line1 = String(orderText.prefix(maxWidth))
            let line2 = String(orderText.dropFirst(maxWidth).prefix(maxWidth))
            buffer.putString(x: 2, y: ordersTop + 1, string: line1, fg: .bright)
            buffer.putString(x: 2, y: ordersTop + 2, string: line2, fg: .bright)
        }
    }

    private static func renderAlarmsBox(buffer: TerminalBuffer, state: ReactorState) {
        buffer.drawBox(x: 0, y: alarmsTop, width: leftPanelWidth, height: alarmsHeight, fg: .dim)
        buffer.putString(x: 2, y: alarmsTop, string: " ALARMS ", fg: state.alarms.isEmpty ? .dim : .alarm)

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
            let color: TerminalColor = alarm.message.contains("[TRIP]") ? .alarm :
                                       alarm.message.contains("[ALARM]") ? .alarm : .normal
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
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Power:", value: "\(powerPct)%", maxWidth: maxWidth,
                      fg: state.thermalPowerFraction > 1.05 ? .alarm : .normal)
        row += 1

        // Rod positions summary
        let avgRodPos = state.adjusterPositions.reduce(0.0, +) / Double(state.adjusterPositions.count)
        let rodStr = String(format: "%.0f%%", avgRodPos * 100.0)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Adj Rods:", value: rodStr, maxWidth: maxWidth)
        row += 1

        // MCA positions
        let avgMCA = state.mcaPositions.reduce(0.0, +) / Double(state.mcaPositions.count)
        let mcaStr = String(format: "%.0f%%", avgMCA * 100.0)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "MCA:", value: mcaStr, maxWidth: maxWidth)
        row += 1

        // Shutoff rods
        let sorStr = state.scramActive ? "SCRAM" : (state.shutoffRodsInserted ? "INSERTED" : "WITHDRAWN")
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Shutoff:", value: sorStr, maxWidth: maxWidth,
                      fg: state.scramActive ? .alarm : .normal)
        row += 1

        // Xenon worth
        let xenonStr = String(format: "%.2f mk", state.xenonReactivity)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Xenon:", value: xenonStr, maxWidth: maxWidth)
        row += 1

        // Total reactivity
        let reactStr = String(format: "%.2f mk", state.totalReactivity)
        let reactColor: TerminalColor = abs(state.totalReactivity) > 5.0 ? .alarm : .normal
        putStatusLine(buffer: buffer, x: col1, y: row, label: "React.:", value: reactStr, maxWidth: maxWidth, fg: reactColor)
        row += 1

        // Primary pressure
        let pressStr = String(format: "%.2f MPa", state.primaryPressure)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "P.Press:", value: pressStr, maxWidth: maxWidth)
        row += 1

        // Net power
        let netStr = String(format: "%.1f MW(e)", state.netPower)
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Net Out:", value: netStr, maxWidth: maxWidth)
        row += 1

        // Time and speed
        let timeStr = formatElapsedTime(state.elapsedTime)
        let speedStr = "\(state.timeAcceleration)x"
        putStatusLine(buffer: buffer, x: col1, y: row, label: "Time:", value: "\(timeStr) (\(speedStr))", maxWidth: maxWidth)
    }

    private static func putStatusLine(buffer: TerminalBuffer, x: Int, y: Int, label: String, value: String, maxWidth: Int, fg: TerminalColor = .normal) {
        buffer.putString(x: x, y: y, string: label, fg: .dim)
        let valueX = x + label.count + 1
        let availableWidth = maxWidth - label.count - 1
        let truncatedValue = String(value.prefix(max(availableWidth, 0)))
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
        title: String, lines: [(String, TerminalColor)], active: Bool
    ) {
        buffer.drawBox(x: x, y: y, width: w, height: h, fg: active ? .normal : .dim)
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
        let bw = 24  // box width
        let bh = 7   // box height
        let gap = 6  // gap between boxes for arrows

        // X positions for top-row component boxes
        let coreX   = left
        let phtX    = coreX + bw + gap
        let sgX     = phtX + bw + gap
        let turbX   = sgX + bw + gap
        let genX    = turbX + bw + gap

        // Y positions
        let topY    = top + 2       // top row of boxes
        let arrowY  = topY + bh / 2 // arrow row (midpoint of boxes)
        let botY    = topY + bh + 3 // bottom row of boxes

        // Title
        buffer.putString(x: left, y: top, string: "CANDU-6 PLANT OVERVIEW", fg: .bright)

        // ── Top row: Core → PHT Pumps → Steam Gen → Turbine → Generator ──

        // Core
        let thermalPower = String(format: "%.0f MW(th)", state.thermalPower)
        let powerPct = String(format: "%.1f%%", state.thermalPowerFraction * 100.0)
        let fuelT = String(format: "Fuel: %.0f\u{00B0}C", state.fuelTemp)
        let reactStr = String(format: "React: %+.2f mk", state.totalReactivity)
        let coreActive = state.thermalPower > 1.0
        drawComponent(buffer: buffer, x: coreX, y: topY, w: bw, h: bh,
                      title: "REACTOR CORE",
                      lines: [
                          (thermalPower, coreActive ? .bright : .normal),
                          (powerPct, .normal),
                          (fuelT, state.fuelTemp > 1500 ? .alarm : .normal),
                          (reactStr, abs(state.totalReactivity) > 5 ? .alarm : .normal),
                          (state.scramActive ? "!! SCRAM !!" : (state.shutoffRodsInserted ? "SORs: IN" : "SORs: OUT"),
                           state.scramActive ? .alarm : .normal),
                      ], active: coreActive)

        // Arrow Core → PHT
        let hasFlow = state.primaryFlowRate > 10
        drawArrow(buffer: buffer, x: coreX + bw, y: arrowY, length: gap, label: "D2O", flowing: hasFlow)

        // PHT Pumps
        let phtRunning = state.primaryPumps.filter { $0.running }.count
        var phtSpinners = ""
        for i in 0..<4 {
            let ch = state.primaryPumps[i].running ? String(spinner(t, offset: i)) : "\u{00B7}"
            phtSpinners += " \(ch)"
        }
        let phtFlow = String(format: "%.0f kg/s", state.primaryFlowRate)
        let phtPressure = String(format: "%.2f MPa", state.primaryPressure)
        drawComponent(buffer: buffer, x: phtX, y: topY, w: bw, h: bh,
                      title: "PHT PUMPS",
                      lines: [
                          ("Pumps:" + phtSpinners, phtRunning > 0 ? .bright : .dim),
                          ("\(phtRunning)/4 running", phtRunning == 0 && state.thermalPower > 10 ? .alarm : .normal),
                          (phtFlow, .normal),
                          (phtPressure, .normal),
                      ], active: phtRunning > 0)

        // Arrow PHT → SG
        drawArrow(buffer: buffer, x: phtX + bw, y: arrowY, length: gap, label: "D2O", flowing: hasFlow)

        // Steam Generators
        let sgLevelAvg = state.sgLevels.reduce(0.0, +) / Double(state.sgLevels.count)
        let sgLevel = String(format: "Level: %.1f%%", sgLevelAvg)
        let sgPress = String(format: "%.2f MPa", state.steamPressure)
        let sgTemp = String(format: "%.0f\u{00B0}C", state.steamTemp)
        let sgFlowStr = String(format: "%.0f kg/s steam", state.steamFlow)
        let sgActive = state.steamPressure > 0.2
        drawComponent(buffer: buffer, x: sgX, y: topY, w: bw, h: bh,
                      title: "STEAM GEN",
                      lines: [
                          (sgPress, .normal),
                          (sgTemp, .normal),
                          (sgLevel, sgLevelAvg < 20 || sgLevelAvg > 80 ? .alarm : .normal),
                          (sgFlowStr, .normal),
                      ], active: sgActive)

        // Arrow SG → Turbine
        let hasSteam = state.steamFlow > 1
        drawArrow(buffer: buffer, x: sgX + bw, y: arrowY, length: gap, label: "STM", flowing: hasSteam)

        // Turbine
        let turbSpin = state.turbineRPM > 10 ? String(spinner(t)) : "\u{00B7}"
        let turbRPM = String(format: "%.0f RPM", state.turbineRPM)
        let govStr = String(format: "Gov: %.0f%%", state.turbineGovernor * 100.0)
        let turbActive = state.turbineRPM > 10
        drawComponent(buffer: buffer, x: turbX, y: topY, w: bw, h: bh,
                      title: "TURBINE",
                      lines: [
                          ("     [ \(turbSpin) ]", turbActive ? .bright : .dim),
                          (turbRPM, .normal),
                          (govStr, .normal),
                      ], active: turbActive)

        // Arrow Turbine → Generator
        drawArrow(buffer: buffer, x: turbX + bw, y: arrowY, length: gap, label: "", flowing: turbActive)

        // Generator
        let grossMW = String(format: "%.1f MW(e)", state.grossPower)
        let netMW = String(format: "Net: %.1f MW(e)", state.netPower)
        let freqStr = String(format: "%.2f Hz", state.generatorFrequency)
        let gridStr = state.generatorConnected ? "GRID: SYNCED" : "GRID: OFFLINE"
        let genActive = state.grossPower > 0.1
        drawComponent(buffer: buffer, x: genX, y: topY, w: bw, h: bh,
                      title: "GENERATOR",
                      lines: [
                          (grossMW, genActive ? .bright : .normal),
                          (netMW, state.netPower < 0 ? .alarm : .normal),
                          (freqStr, .normal),
                          (gridStr, state.generatorConnected ? .bright : .dim),
                      ], active: genActive)

        // Arrow Generator → Grid
        if genX + bw + 2 < left + width {
            let gridArrowLen = min(8, left + width - genX - bw)
            drawArrow(buffer: buffer, x: genX + bw, y: arrowY, length: gridArrowLen, label: "", flowing: state.generatorConnected)
            buffer.putString(x: genX + bw + gridArrowLen, y: arrowY, string: " GRID", fg: state.generatorConnected ? .bright : .dim)
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

        // ── Bottom row: Feed Pumps ← Condenser ← CW Pumps ──

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
                          ("Pumps:" + fpSpinners, fpRunning > 0 ? .bright : .dim),
                          ("\(fpRunning)/3 running", .normal),
                          (String(format: "FW: %.0f\u{00B0}C", state.feedwaterTemp), .normal),
                      ], active: fpRunning > 0)

        // Arrow Condenser → Feed Pumps (left-pointing)
        drawArrowLeft(buffer: buffer, x: sgX + bw, y: botY + bh / 2, length: gap, label: "H2O", flowing: fpRunning > 0)

        // Condenser (aligned under Turbine)
        let condPress = String(format: "%.4f MPa", state.condenserPressure)
        let condTemp = String(format: "%.1f\u{00B0}C", state.condenserTemp)
        drawComponent(buffer: buffer, x: turbX, y: botY, w: bw, h: bh,
                      title: "CONDENSER",
                      lines: [
                          (condPress, .normal),
                          (condTemp, .normal),
                      ], active: hasSteam)

        // Arrow CW Pumps → Condenser (left-pointing)
        let cwRunning = state.coolingWaterPumps.filter { $0.running }.count
        drawArrowLeft(buffer: buffer, x: turbX + bw, y: botY + bh / 2, length: gap, label: "CW", flowing: cwRunning > 0)

        // CW Pumps (aligned under Generator)
        var cwSpinners = ""
        for i in 0..<2 {
            let ch = state.coolingWaterPumps[i].running ? String(spinner(t, offset: i + 8)) : "\u{00B7}"
            cwSpinners += " \(ch)"
        }
        let cwFlowStr = String(format: "%.0f kg/s", state.coolingWaterFlow)
        drawComponent(buffer: buffer, x: genX, y: botY, w: bw, h: bh,
                      title: "CW PUMPS",
                      lines: [
                          ("Pumps:" + cwSpinners, cwRunning > 0 ? .bright : .dim),
                          ("\(cwRunning)/2 running", .normal),
                          (cwFlowStr, .normal),
                      ], active: cwRunning > 0)

        // Arrow Lake → CW Pumps
        if genX + bw + 2 < left + width {
            let lakeArrowLen = min(8, left + width - genX - bw)
            drawArrowLeft(buffer: buffer, x: genX + bw, y: botY + bh / 2, length: lakeArrowLen, label: "", flowing: cwRunning > 0)
            buffer.putString(x: genX + bw + lakeArrowLen, y: botY + bh / 2, string: " LAKE", fg: .dim)
        }

        // ── Diesels (small note below diagram) ──
        let dieselY = botY + bh + 1
        if dieselY < top + height {
            let d1 = state.dieselGenerators[0]
            let d2 = state.dieselGenerators[1]
            let d1status = d1.available ? "RUN" : (d1.running ? "START" : "OFF")
            let d2status = d2.available ? "RUN" : (d2.running ? "START" : "OFF")
            buffer.putString(x: left, y: dieselY, string: "DIESEL GEN: DG-1 \(d1status) | DG-2 \(d2status)", fg: .dim)
        }
    }

    // MARK: - Core View

    private static func renderCore(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        var row = top

        // Temperatures
        buffer.putString(x: left, y: row, string: "CORE TEMPERATURES", fg: .bright)
        row += 1
        let fuelT = String(format: "%.1f", state.fuelTemp)
        let cladT = String(format: "%.1f", state.claddingTemp)
        buffer.putString(x: left + 2, y: row, string: "Fuel:     \(fuelT) degC", fg: state.fuelTemp > 2000 ? .alarm : .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Cladding: \(cladT) degC", fg: state.claddingTemp > 800 ? .alarm : .normal)
        row += 2

        // Adjuster rod positions (bar charts)
        buffer.putString(x: left, y: row, string: "ADJUSTER ROD POSITIONS (0%=IN, 100%=OUT)", fg: .bright)
        row += 1
        let bankNames = ["Bank A", "Bank B", "Bank C", "Bank D"]
        let barWidth = 40
        for (i, name) in bankNames.enumerated() {
            let pos = state.adjusterPositions[i]
            let posStr = String(format: "%5.1f%%", pos * 100.0)
            buffer.putString(x: left + 2, y: row, string: "\(name): ", fg: .normal)
            buffer.drawProgressBar(x: left + 12, y: row, width: barWidth, value: pos, maxValue: 1.0, fg: .bright)
            buffer.putString(x: left + 12 + barWidth + 2, y: row, string: posStr, fg: .normal)
            row += 1
        }
        row += 1

        // MCA positions
        buffer.putString(x: left, y: row, string: "MECHANICAL CONTROL ABSORBERS", fg: .bright)
        row += 1
        for i in 0..<2 {
            let pos = state.mcaPositions[i]
            let posStr = String(format: "%5.1f%%", pos * 100.0)
            buffer.putString(x: left + 2, y: row, string: "MCA-\(i+1): ", fg: .normal)
            buffer.drawProgressBar(x: left + 12, y: row, width: barWidth, value: pos, maxValue: 1.0, fg: .bright)
            buffer.putString(x: left + 12 + barWidth + 2, y: row, string: posStr, fg: .normal)
            row += 1
        }
        row += 1

        // Shutoff rods
        buffer.putString(x: left, y: row, string: "SHUTOFF RODS", fg: .bright)
        row += 1
        let sorStatus: String
        let sorColor: TerminalColor
        if state.scramActive {
            sorStatus = "SCRAM ACTIVE - Insertion: \(String(format: "%.0f%%", state.shutoffRodInsertionFraction * 100.0))"
            sorColor = .alarm
        } else if state.shutoffRodsInserted {
            sorStatus = "FULLY INSERTED"
            sorColor = .normal
        } else {
            sorStatus = "WITHDRAWN"
            sorColor = .bright
        }
        buffer.putString(x: left + 2, y: row, string: sorStatus, fg: sorColor)
        row += 2

        // Zone controllers
        buffer.putString(x: left, y: row, string: "ZONE CONTROLLERS (fill %)", fg: .bright)
        row += 1
        let zonesPerRow = 3
        for zoneStart in stride(from: 0, to: state.zoneControllerFills.count, by: zonesPerRow) {
            var col = left + 2
            for z in zoneStart..<min(zoneStart + zonesPerRow, state.zoneControllerFills.count) {
                let fill = state.zoneControllerFills[z]
                let fillStr = String(format: "Z%d: %5.1f%%", z + 1, fill)
                buffer.putString(x: col, y: row, string: fillStr, fg: .normal)
                buffer.drawProgressBar(x: col + 13, y: row, width: 20, value: fill, maxValue: 100.0, fg: .bright)
                col += 38
            }
            row += 1
        }
        row += 1

        // Reactivity breakdown table
        buffer.putString(x: left, y: row, string: "REACTIVITY BREAKDOWN", fg: .bright)
        row += 1
        buffer.putString(x: left + 2, y: row, string: String(format: "Rod Reactivity:      %+8.3f mk", state.rodReactivity), fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: String(format: "Feedback Reactivity: %+8.3f mk", state.feedbackReactivity), fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: String(format: "Xenon Reactivity:    %+8.3f mk", state.xenonReactivity), fg: .normal)
        row += 1
        buffer.drawHorizontalLine(x: left + 2, y: row, width: 35, fg: .dim)
        row += 1
        let totalReact = state.totalReactivity
        let totalColor: TerminalColor = abs(totalReact) > 5.0 ? .alarm : .normal
        buffer.putString(x: left + 2, y: row, string: String(format: "TOTAL:               %+8.3f mk", totalReact), fg: totalColor)
        row += 2

        // Xenon / Iodine
        buffer.putString(x: left, y: row, string: "XENON / IODINE", fg: .bright)
        row += 1
        let xenon = String(format: "%.6f", state.xenonConcentration)
        let iodine = String(format: "%.6f", state.iodineConcentration)
        let xenonMk = String(format: "%+.3f mk", state.xenonReactivity)
        buffer.putString(x: left + 2, y: row, string: "Xe-135: \(xenon)  (\(xenonMk))", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "I-135:  \(iodine)", fg: .normal)
    }

    // MARK: - Primary View

    private static func renderPrimary(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        var row = top

        buffer.putString(x: left, y: row, string: "PRIMARY HEAT TRANSPORT SYSTEM (D2O)", fg: .bright)
        row += 2

        // Header temperatures and pressure
        buffer.putString(x: left, y: row, string: "SYSTEM PARAMETERS", fg: .bright)
        row += 1
        let inletT = String(format: "%.1f", state.primaryInletTemp)
        let outletT = String(format: "%.1f", state.primaryOutletTemp)
        let pressure = String(format: "%.2f", state.primaryPressure)
        let flow = String(format: "%.0f", state.primaryFlowRate)
        let ratedFlow = String(format: "%.0f", CANDUConstants.totalRatedFlow)
        buffer.putString(x: left + 2, y: row, string: "Inlet Header (Cold Leg):  \(inletT) degC", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Outlet Header (Hot Leg):  \(outletT) degC", fg: .normal)
        row += 1
        let deltaT = state.primaryOutletTemp - state.primaryInletTemp
        let deltaTStr = String(format: "%.1f", deltaT)
        buffer.putString(x: left + 2, y: row, string: "Core Delta-T:             \(deltaTStr) degC", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "System Pressure:          \(pressure) MPa (rated: \(String(format: "%.1f", CANDUConstants.primaryPressureRated)))", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Total Flow Rate:          \(flow) / \(ratedFlow) kg/s", fg: .normal)
        row += 2

        // Pump details
        buffer.putString(x: left, y: row, string: "PRIMARY HEAT TRANSPORT PUMPS", fg: .bright)
        row += 1

        // Header
        buffer.putString(x: left + 2, y: row, string: "Pump     Status    RPM       Power     Flow", fg: .dim)
        row += 1
        buffer.drawHorizontalLine(x: left + 2, y: row, width: 55, fg: .dim)
        row += 1

        for (i, pump) in state.primaryPumps.enumerated() {
            let status: String
            let statusColor: TerminalColor
            if pump.tripped {
                status = "TRIPPED "
                statusColor = .alarm
            } else if pump.running {
                status = "RUNNING "
                statusColor = .bright
            } else {
                status = "STOPPED "
                statusColor = .dim
            }

            let rpmStr = String(format: "%7.0f", pump.rpm)
            // Estimate power and flow from RPM
            let rpmFraction = pump.rpm / CANDUConstants.pumpRatedRPM
            let estimatedPower = CANDUConstants.pumpMotorPower * pow(rpmFraction, 3)
            let estimatedFlow = CANDUConstants.pumpRatedFlow * rpmFraction
            let powerStr = String(format: "%5.1f MW", estimatedPower)
            let flowStr = String(format: "%6.0f kg/s", estimatedFlow)

            buffer.putString(x: left + 2, y: row, string: "PHT-\(i+1)    ", fg: .normal)
            buffer.putString(x: left + 12, y: row, string: status, fg: statusColor)
            buffer.putString(x: left + 22, y: row, string: rpmStr, fg: .normal)
            buffer.putString(x: left + 32, y: row, string: powerStr, fg: .normal)
            buffer.putString(x: left + 42, y: row, string: flowStr, fg: .normal)
            row += 1
        }
        row += 1

        // RPM bar charts
        buffer.putString(x: left, y: row, string: "PUMP RPM", fg: .bright)
        row += 1
        for (i, pump) in state.primaryPumps.enumerated() {
            let label = String(format: "PHT-%d: ", i + 1)
            buffer.putString(x: left + 2, y: row, string: label, fg: .normal)
            buffer.drawProgressBar(x: left + 10, y: row, width: 40, value: pump.rpm, maxValue: CANDUConstants.pumpRatedRPM, fg: .bright)
            let pctStr = String(format: " %.0f%%", (pump.rpm / CANDUConstants.pumpRatedRPM) * 100.0)
            buffer.putString(x: left + 52, y: row, string: pctStr, fg: .normal)
            row += 1
        }
    }

    // MARK: - Secondary View

    private static func renderSecondary(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        var row = top

        buffer.putString(x: left, y: row, string: "SECONDARY SYSTEM (STEAM CYCLE)", fg: .bright)
        row += 2

        // Steam generators
        buffer.putString(x: left, y: row, string: "STEAM GENERATORS", fg: .bright)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "SG       Level    Pressure  Steam Temp", fg: .dim)
        row += 1
        buffer.drawHorizontalLine(x: left + 2, y: row, width: 50, fg: .dim)
        row += 1

        for i in 0..<state.sgLevels.count {
            let level = state.sgLevels[i]
            let levelStr = String(format: "%5.1f%%", level)
            let pressStr = String(format: "%5.2f MPa", state.steamPressure)
            let tempStr = String(format: "%5.1f degC", state.steamTemp)
            let levelColor: TerminalColor = level < 20 || level > 80 ? .alarm : .normal

            buffer.putString(x: left + 2, y: row, string: "SG-\(i+1)     ", fg: .normal)
            buffer.putString(x: left + 12, y: row, string: levelStr, fg: levelColor)
            buffer.putString(x: left + 22, y: row, string: pressStr, fg: .normal)
            buffer.putString(x: left + 34, y: row, string: tempStr, fg: .normal)
            row += 1
        }
        row += 1

        // SG Level bars
        buffer.putString(x: left, y: row, string: "SG LEVELS", fg: .bright)
        row += 1
        for i in 0..<state.sgLevels.count {
            let label = String(format: "SG-%d: ", i + 1)
            buffer.putString(x: left + 2, y: row, string: label, fg: .normal)
            let barColor: TerminalColor = state.sgLevels[i] < 20 || state.sgLevels[i] > 80 ? .alarm : .bright
            buffer.drawProgressBar(x: left + 10, y: row, width: 40, value: state.sgLevels[i], maxValue: 100.0, fg: barColor)
            let pctStr = String(format: " %.1f%%", state.sgLevels[i])
            buffer.putString(x: left + 52, y: row, string: pctStr, fg: .normal)
            row += 1
        }
        row += 1

        // Feed pumps
        buffer.putString(x: left, y: row, string: "FEED WATER PUMPS", fg: .bright)
        row += 1
        for (i, pump) in state.feedPumps.enumerated() {
            let status = pump.running ? "RUNNING" : "STOPPED"
            let statusColor: TerminalColor = pump.running ? .bright : .dim
            let flowStr = String(format: "%.0f kg/s", pump.flowRate)
            buffer.putString(x: left + 2, y: row, string: "FW-\(i+1): \(status)  Flow: \(flowStr)", fg: statusColor)
            row += 1
        }
        row += 1

        // Feedwater temperature
        let fwTemp = String(format: "%.1f", state.feedwaterTemp)
        buffer.putString(x: left + 2, y: row, string: "Feedwater Temperature: \(fwTemp) degC", fg: .normal)
        row += 2

        // Turbine
        buffer.putString(x: left, y: row, string: "TURBINE / GOVERNOR", fg: .bright)
        row += 1
        let turbRPM = String(format: "%.0f", state.turbineRPM)
        let ratedRPM = String(format: "%.0f", CANDUConstants.turbineRatedRPM)
        buffer.putString(x: left + 2, y: row, string: "Turbine RPM:   \(turbRPM) / \(ratedRPM)", fg: .normal)
        row += 1
        let govPos = String(format: "%.1f%%", state.turbineGovernor * 100.0)
        buffer.putString(x: left + 2, y: row, string: "Governor Valve: \(govPos)", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Governor: ", fg: .normal)
        buffer.drawProgressBar(x: left + 12, y: row, width: 40, value: state.turbineGovernor, maxValue: 1.0, fg: .bright)
        row += 2

        // Condenser
        buffer.putString(x: left, y: row, string: "CONDENSER", fg: .bright)
        row += 1
        let condP = String(format: "%.4f", state.condenserPressure)
        let condT = String(format: "%.1f", state.condenserTemp)
        buffer.putString(x: left + 2, y: row, string: "Pressure:    \(condP) MPa", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Temperature: \(condT) degC", fg: .normal)
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
        buffer.putString(x: left + 2, y: row, string: "Gross Output:  \(gross) / \(rated) MW(e)", fg: .normal)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Output: ", fg: .normal)
        buffer.drawProgressBar(x: left + 10, y: row, width: 50, value: state.grossPower, maxValue: CANDUConstants.ratedGrossElectrical, fg: .bright)
        row += 1
        let freq = String(format: "%.2f", state.generatorFrequency)
        let freqColor: TerminalColor = abs(state.generatorFrequency - 60.0) > 1.0 && state.generatorFrequency > 0 ? .alarm : .normal
        buffer.putString(x: left + 2, y: row, string: "Frequency:     \(freq) Hz (target: 60.00 Hz)", fg: freqColor)
        row += 1
        let connected = state.generatorConnected ? "YES" : "NO"
        buffer.putString(x: left + 2, y: row, string: "Grid Sync:     \(connected)", fg: .normal)
        row += 2

        // Turbine
        buffer.putString(x: left, y: row, string: "TURBINE", fg: .bright)
        row += 1
        let turbRPM = String(format: "%.0f", state.turbineRPM)
        buffer.putString(x: left + 2, y: row, string: "Speed: \(turbRPM) RPM", fg: .normal)
        row += 1
        let turbPower = String(format: "%.1f", state.grossPower / max(CANDUConstants.generatorEfficiency, 0.01))
        buffer.putString(x: left + 2, y: row, string: "Shaft Power: \(turbPower) MW", fg: .normal)
        row += 2

        // Station service
        buffer.putString(x: left, y: row, string: "STATION SERVICE", fg: .bright)
        row += 1
        let service = String(format: "%.1f", state.stationServiceLoad)
        buffer.putString(x: left + 2, y: row, string: "Station Service Load: \(service) MW", fg: .normal)
        row += 1

        // Itemize major loads
        let pumpPower = state.primaryPumps.filter({ $0.running }).count
        let phtLoad = String(format: "%.1f", Double(pumpPower) * CANDUConstants.pumpMotorPower)
        buffer.putString(x: left + 4, y: row, string: "PHT Pumps (\(pumpPower) running): \(phtLoad) MW", fg: .dim)
        row += 1
        let cwPumps = state.coolingWaterPumps.filter({ $0.running }).count
        let cwLoad = String(format: "%.1f", Double(cwPumps) * CANDUConstants.coolingWaterPumpPower)
        buffer.putString(x: left + 4, y: row, string: "CW Pumps (\(cwPumps) running):  \(cwLoad) MW", fg: .dim)
        row += 2

        // Net output
        buffer.putString(x: left, y: row, string: "NET ELECTRICAL OUTPUT", fg: .bright)
        row += 1
        let net = String(format: "%.1f", state.netPower)
        let netRated = String(format: "%.0f", CANDUConstants.ratedNetElectrical)
        let netColor: TerminalColor = state.netPower < 0 ? .alarm : .normal
        buffer.putString(x: left + 2, y: row, string: "Net: \(net) / \(netRated) MW(e)", fg: netColor)
        row += 1
        buffer.putString(x: left + 2, y: row, string: "Net:  ", fg: .normal)
        buffer.drawProgressBar(x: left + 8, y: row, width: 50, value: max(state.netPower, 0), maxValue: CANDUConstants.ratedNetElectrical, fg: netColor == .alarm ? .alarm : .bright)
        row += 2

        // Diesel generators
        buffer.putString(x: left, y: row, string: "DIESEL GENERATORS", fg: .bright)
        row += 1
        for (i, dg) in state.dieselGenerators.enumerated() {
            let status: String
            let statusColor: TerminalColor
            if dg.available {
                status = "AVAILABLE"
                statusColor = .bright
            } else if dg.running {
                let elapsed = state.elapsedTime - dg.startTime
                let remaining = max(CANDUConstants.dieselStartTime - elapsed, 0)
                status = "STARTING (\(String(format: "%.0f", remaining))s)"
                statusColor = .normal
            } else {
                status = "OFFLINE"
                statusColor = .dim
            }
            let power = String(format: "%.1f", dg.power)
            let rated = String(format: "%.0f", CANDUConstants.dieselPower)
            buffer.putString(x: left + 2, y: row, string: "DG-\(i+1): \(status)  Output: \(power)/\(rated) MW", fg: statusColor)
            row += 1
        }
        row += 1

        // Grid power
        let gridStatus = state.generatorConnected ? "SYNCED" : "OFFLINE"
        let gridColor: TerminalColor = state.generatorConnected ? .bright : .dim
        buffer.putString(x: left + 2, y: row, string: "Generator Grid Sync: \(gridStatus)", fg: gridColor)
    }

    // MARK: - Alarm Log View

    private static func renderAlarmLog(buffer: TerminalBuffer, state: ReactorState, left: Int, top: Int, width: Int, height: Int) {
        var row = top

        buffer.putString(x: left, y: row, string: "ALARM LOG (\(state.alarms.count) entries)", fg: .bright)
        row += 1
        buffer.drawHorizontalLine(x: left, y: row, width: min(width, 120), fg: .dim)
        row += 1

        // Header
        buffer.putString(x: left, y: row, string: "TIME        MESSAGE", fg: .dim)
        row += 1

        let maxLines = height - 4
        let maxMsgWidth = min(width - 14, 240)

        // Show alarms from most recent to oldest
        let displayAlarms = state.alarms.suffix(maxLines).reversed()
        for alarm in displayAlarms {
            if row >= top + height { break }
            let timeStr = formatElapsedTime(alarm.time)
            let msg = String(alarm.message.prefix(maxMsgWidth))
            let color: TerminalColor = alarm.message.contains("[TRIP]") ? .alarm :
                                       alarm.message.contains("[ALARM]") ? .alarm : .normal
            buffer.putString(x: left, y: row, string: timeStr, fg: .dim)
            buffer.putString(x: left + 12, y: row, string: msg, fg: color)
            row += 1
        }

        if state.alarms.isEmpty {
            buffer.putString(x: left, y: row, string: "No alarms recorded.", fg: .dim)
        }
    }

    // MARK: - Command Area

    private static func renderCommandArea(buffer: TerminalBuffer, commandLine: TerminalCommandLine, intellisense: [String], commandOutput: [String]) {
        let left = 0
        let top = commandAreaTop
        let width = TerminalBuffer.width
        let height = commandAreaHeight

        // Draw border
        buffer.drawBox(x: left, y: top, width: width, height: height, fg: .dim)
        buffer.putString(x: left + 2, y: top, string: " COMMAND ", fg: .input)

        // Command output (last lines that fit)
        let outputLines = height - 4
        let recentOutput = commandOutput.suffix(outputLines)
        var row = top + 1
        for line in recentOutput {
            let truncated = String(line.prefix(width - 4))
            buffer.putString(x: left + 2, y: row, string: truncated, fg: .dim)
            row += 1
        }

        // Horizontal separator above input
        let inputRow = top + height - 3
        buffer.drawHorizontalLine(x: left + 1, y: inputRow, width: width - 2, fg: .dim)

        // Command prompt and input
        let promptRow = top + height - 2
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
