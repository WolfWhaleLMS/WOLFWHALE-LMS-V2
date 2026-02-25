import SwiftUI

// MARK: - Models

enum UnitCategory: String, CaseIterable, Identifiable {
    case length = "Length"
    case weight = "Weight/Mass"
    case volume = "Volume"
    case temperature = "Temperature"
    case area = "Area"
    case speed = "Speed"
    case time = "Time"
    case data = "Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .length: return "ruler"
        case .weight: return "scalemass"
        case .volume: return "drop.fill"
        case .temperature: return "thermometer.medium"
        case .area: return "square.dashed"
        case .speed: return "gauge.with.dots.needle.67percent"
        case .time: return "clock.fill"
        case .data: return "internaldrive.fill"
        }
    }

    var color: Color {
        switch self {
        case .length: return .blue
        case .weight: return .orange
        case .volume: return .cyan
        case .temperature: return .red
        case .area: return .green
        case .speed: return .purple
        case .time: return .indigo
        case .data: return .orange
        }
    }

    var units: [UnitInfo] {
        switch self {
        case .length:
            return [
                UnitInfo(name: "Millimetres", symbol: "mm", toBase: 0.001),
                UnitInfo(name: "Centimetres", symbol: "cm", toBase: 0.01),
                UnitInfo(name: "Metres", symbol: "m", toBase: 1.0),
                UnitInfo(name: "Kilometres", symbol: "km", toBase: 1000.0),
                UnitInfo(name: "Inches", symbol: "in", toBase: 0.0254),
                UnitInfo(name: "Feet", symbol: "ft", toBase: 0.3048),
                UnitInfo(name: "Yards", symbol: "yd", toBase: 0.9144),
                UnitInfo(name: "Miles", symbol: "mi", toBase: 1609.344)
            ]
        case .weight:
            return [
                UnitInfo(name: "Milligrams", symbol: "mg", toBase: 0.000001),
                UnitInfo(name: "Grams", symbol: "g", toBase: 0.001),
                UnitInfo(name: "Kilograms", symbol: "kg", toBase: 1.0),
                UnitInfo(name: "Ounces", symbol: "oz", toBase: 0.0283495),
                UnitInfo(name: "Pounds", symbol: "lb", toBase: 0.453592)
            ]
        case .volume:
            return [
                UnitInfo(name: "Millilitres", symbol: "mL", toBase: 0.001),
                UnitInfo(name: "Litres", symbol: "L", toBase: 1.0),
                UnitInfo(name: "Cups", symbol: "cup", toBase: 0.236588),
                UnitInfo(name: "Pints", symbol: "pt", toBase: 0.473176),
                UnitInfo(name: "Quarts", symbol: "qt", toBase: 0.946353),
                UnitInfo(name: "Gallons", symbol: "gal", toBase: 3.78541)
            ]
        case .temperature:
            return [
                UnitInfo(name: "Celsius", symbol: "°C", toBase: 1.0),
                UnitInfo(name: "Fahrenheit", symbol: "°F", toBase: 1.0),
                UnitInfo(name: "Kelvin", symbol: "K", toBase: 1.0)
            ]
        case .area:
            return [
                UnitInfo(name: "Square mm", symbol: "mm²", toBase: 0.000001),
                UnitInfo(name: "Square cm", symbol: "cm²", toBase: 0.0001),
                UnitInfo(name: "Square m", symbol: "m²", toBase: 1.0),
                UnitInfo(name: "Square km", symbol: "km²", toBase: 1_000_000),
                UnitInfo(name: "Acres", symbol: "ac", toBase: 4046.86),
                UnitInfo(name: "Hectares", symbol: "ha", toBase: 10_000)
            ]
        case .speed:
            return [
                UnitInfo(name: "Metres/sec", symbol: "m/s", toBase: 1.0),
                UnitInfo(name: "Km/hour", symbol: "km/h", toBase: 0.277778),
                UnitInfo(name: "Miles/hour", symbol: "mph", toBase: 0.44704),
                UnitInfo(name: "Knots", symbol: "kn", toBase: 0.514444)
            ]
        case .time:
            return [
                UnitInfo(name: "Seconds", symbol: "sec", toBase: 1.0),
                UnitInfo(name: "Minutes", symbol: "min", toBase: 60.0),
                UnitInfo(name: "Hours", symbol: "hr", toBase: 3600.0),
                UnitInfo(name: "Days", symbol: "day", toBase: 86400.0),
                UnitInfo(name: "Weeks", symbol: "wk", toBase: 604800.0)
            ]
        case .data:
            return [
                UnitInfo(name: "Bytes", symbol: "B", toBase: 1.0),
                UnitInfo(name: "Kilobytes", symbol: "KB", toBase: 1024.0),
                UnitInfo(name: "Megabytes", symbol: "MB", toBase: 1_048_576.0),
                UnitInfo(name: "Gigabytes", symbol: "GB", toBase: 1_073_741_824.0),
                UnitInfo(name: "Terabytes", symbol: "TB", toBase: 1_099_511_627_776.0)
            ]
        }
    }
}

struct UnitInfo: Identifiable, Hashable {
    let name: String
    let symbol: String
    let toBase: Double

    var id: String { symbol }
}

struct ConversionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let category: String
    let fromValue: Double
    let fromUnit: String
    let toValue: Double
    let toUnit: String
}

// MARK: - Main View

struct UnitConverterView: View {
    @State private var selectedCategory: UnitCategory = .length
    @State private var fromUnitIndex: Int = 0
    @State private var toUnitIndex: Int = 2
    @State private var inputValue: String = ""
    @State private var showHistory = false
    @State private var showFormula = false
    @State private var hapticTrigger = false

    @AppStorage("conversionHistory") private var historyData: Data = Data()

    private var history: [ConversionRecord] {
        (try? JSONDecoder().decode([ConversionRecord].self, from: historyData)) ?? []
    }

    private var units: [UnitInfo] {
        selectedCategory.units
    }

    private var fromUnit: UnitInfo {
        guard fromUnitIndex < units.count else { return units[0] }
        return units[fromUnitIndex]
    }

    private var toUnit: UnitInfo {
        guard toUnitIndex < units.count else { return units.count > 1 ? units[1] : units[0] }
        return units[toUnitIndex]
    }

    private var inputDouble: Double {
        Double(inputValue) ?? 0
    }

    private var convertedValue: Double {
        convert(inputDouble, from: fromUnit, to: toUnit, category: selectedCategory)
    }

    private var formulaText: String {
        formulaDescription(from: fromUnit, to: toUnit, category: selectedCategory)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    categoryPicker
                    converterCard
                    if showFormula {
                        formulaCard
                    }
                    actionButtons
                    if !history.isEmpty {
                        recentHistory
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Unit Converter")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showHistory) {
                fullHistorySheet
            }
            .onChange(of: selectedCategory) { _, _ in
                fromUnitIndex = 0
                toUnitIndex = min(2, units.count - 1)
                inputValue = ""
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(UnitCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        hapticTrigger.toggle()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.title3)
                            Text(category.rawValue)
                                .font(.caption2.bold())
                        }
                        .frame(width: 80, height: 70)
                        .background(
                            selectedCategory == category
                            ? AnyShapeStyle(category.color.opacity(0.2))
                            : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .foregroundStyle(selectedCategory == category ? category.color : .secondary)
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(selectedCategory == category ? category.color.opacity(0.5) : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Converter Card

    private var converterCard: some View {
        VStack(spacing: 0) {
            // From Section
            VStack(spacing: 10) {
                HStack {
                    Text("FROM")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Picker("From Unit", selection: $fromUnitIndex) {
                    ForEach(Array(units.enumerated()), id: \.element.id) { index, unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(index)
                    }
                }
                .pickerStyle(.menu)
                .tint(selectedCategory.color)

                TextField("Enter value", text: $inputValue)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            }
            .padding()

            // Swap Button
            Button {
                let temp = fromUnitIndex
                fromUnitIndex = toUnitIndex
                toUnitIndex = temp
                hapticTrigger.toggle()
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.title)
                    .foregroundStyle(selectedCategory.color)
                    .padding(4)
                    .background(.background, in: Circle())
            }
            .buttonStyle(.plain)
            .offset(y: -2)
            .zIndex(1)

            // To Section
            VStack(spacing: 10) {
                HStack {
                    Text("TO")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Picker("To Unit", selection: $toUnitIndex) {
                    ForEach(Array(units.enumerated()), id: \.element.id) { index, unit in
                        Text("\(unit.name) (\(unit.symbol))").tag(index)
                    }
                }
                .pickerStyle(.menu)
                .tint(selectedCategory.color)

                Text(formatResult(convertedValue))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(selectedCategory.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [selectedCategory.color.opacity(0.05), selectedCategory.color.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: .rect(cornerRadius: 12)
                    )

                Text("\(formatResult(inputDouble)) \(fromUnit.symbol) = \(formatResult(convertedValue)) \(toUnit.symbol)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Formula Card

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "function")
                    .foregroundStyle(selectedCategory.color)
                Text("Conversion Formula")
                    .font(.subheadline.bold())
            }

            Text(formulaText)
                .font(.callout.monospaced())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.tertiarySystemGroupedBackground),
                    in: .rect(cornerRadius: 10)
                )
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showFormula.toggle()
            } label: {
                Label(showFormula ? "Hide Formula" : "Show Formula", systemImage: "function")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                saveConversion()
                hapticTrigger.toggle()
            } label: {
                Label("Save", systemImage: "bookmark.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [selectedCategory.color, selectedCategory.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: .rect(cornerRadius: 12)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Recent History

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Conversions")
                    .font(.headline)
                Spacer()
                Button("See All") { showHistory = true }
                    .font(.caption.bold())
                    .foregroundStyle(selectedCategory.color)
            }

            ForEach(history.suffix(5).reversed()) { record in
                HStack {
                    Image(systemName: UnitCategory(rawValue: record.category)?.icon ?? "questionmark")
                        .foregroundStyle(UnitCategory(rawValue: record.category)?.color ?? .gray)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(formatResult(record.fromValue)) \(record.fromUnit) = \(formatResult(record.toValue)) \(record.toUnit)")
                            .font(.subheadline.bold().monospacedDigit())
                        Text(record.date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Full History Sheet

    private var fullHistorySheet: some View {
        NavigationStack {
            List {
                ForEach(history.reversed()) { record in
                    HStack {
                        Image(systemName: UnitCategory(rawValue: record.category)?.icon ?? "questionmark")
                            .foregroundStyle(UnitCategory(rawValue: record.category)?.color ?? .gray)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(formatResult(record.fromValue)) \(record.fromUnit)")
                                .font(.subheadline.bold())
                            Text("\(formatResult(record.toValue)) \(record.toUnit)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(record.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Conversion History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        historyData = Data()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showHistory = false }
                }
            }
        }
    }

    // MARK: - Conversion Logic

    private func convert(_ value: Double, from: UnitInfo, to: UnitInfo, category: UnitCategory) -> Double {
        if category == .temperature {
            return convertTemperature(value, from: from.symbol, to: to.symbol)
        }
        let baseValue = value * from.toBase
        return baseValue / to.toBase
    }

    private func convertTemperature(_ value: Double, from: String, to: String) -> Double {
        var celsius: Double
        switch from {
        case "°C": celsius = value
        case "°F": celsius = (value - 32) * 5.0 / 9.0
        case "K": celsius = value - 273.15
        default: celsius = value
        }

        switch to {
        case "°C": return celsius
        case "°F": return celsius * 9.0 / 5.0 + 32
        case "K": return celsius + 273.15
        default: return celsius
        }
    }

    private func formulaDescription(from: UnitInfo, to: UnitInfo, category: UnitCategory) -> String {
        if category == .temperature {
            return temperatureFormula(from: from.symbol, to: to.symbol)
        }

        let factor = from.toBase / to.toBase
        return "\(from.symbol) x \(formatResult(factor)) = \(to.symbol)\n\n1 \(from.name) = \(formatResult(factor)) \(to.name)"
    }

    private func temperatureFormula(from: String, to: String) -> String {
        switch (from, to) {
        case ("°C", "°F"): return "°F = (°C x 9/5) + 32"
        case ("°F", "°C"): return "°C = (°F - 32) x 5/9"
        case ("°C", "K"): return "K = °C + 273.15"
        case ("K", "°C"): return "°C = K - 273.15"
        case ("°F", "K"): return "K = (°F - 32) x 5/9 + 273.15"
        case ("K", "°F"): return "°F = (K - 273.15) x 9/5 + 32"
        default: return "Same unit — no conversion needed"
        }
    }

    private func formatResult(_ value: Double) -> String {
        if value == 0 { return "0" }
        if abs(value) >= 1_000_000 || (abs(value) < 0.001 && value != 0) {
            return String(format: "%.4g", value)
        }
        let formatted = String(format: "%.6f", value)
        // Trim trailing zeros
        var trimmed = formatted
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }

    private func saveConversion() {
        guard inputDouble != 0 else { return }
        let record = ConversionRecord(
            id: UUID(),
            date: Date(),
            category: selectedCategory.rawValue,
            fromValue: inputDouble,
            fromUnit: fromUnit.symbol,
            toValue: convertedValue,
            toUnit: toUnit.symbol
        )
        var current = history
        current.append(record)
        if current.count > 100 { current = Array(current.suffix(100)) }
        if let data = try? JSONEncoder().encode(current) {
            historyData = data
        }
    }
}

// MARK: - Preview

#Preview {
    UnitConverterView()
}
