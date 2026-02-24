import SwiftUI

// MARK: - Data Models

enum ElementCategory: String, CaseIterable {
    case alkaliMetal = "Alkali Metal"
    case alkalineEarthMetal = "Alkaline Earth Metal"
    case transitionMetal = "Transition Metal"
    case postTransitionMetal = "Post-Transition Metal"
    case metalloid = "Metalloid"
    case nonmetal = "Nonmetal"
    case halogen = "Halogen"
    case nobleGas = "Noble Gas"
    case lanthanide = "Lanthanide"
    case actinide = "Actinide"

    var color: Color {
        switch self {
        case .alkaliMetal: Color(red: 0.95, green: 0.45, blue: 0.45)
        case .alkalineEarthMetal: Color(red: 0.95, green: 0.65, blue: 0.35)
        case .transitionMetal: Color(red: 0.55, green: 0.75, blue: 0.95)
        case .postTransitionMetal: Color(red: 0.55, green: 0.85, blue: 0.70)
        case .metalloid: Color(red: 0.70, green: 0.80, blue: 0.50)
        case .nonmetal: Color(red: 0.95, green: 0.85, blue: 0.40)
        case .halogen: Color(red: 0.85, green: 0.65, blue: 0.95)
        case .nobleGas: Color(red: 0.65, green: 0.55, blue: 0.95)
        case .lanthanide: Color(red: 0.90, green: 0.75, blue: 0.55)
        case .actinide: Color(red: 0.80, green: 0.60, blue: 0.60)
        }
    }
}

enum ElementState: String {
    case solid = "Solid"
    case liquid = "Liquid"
    case gas = "Gas"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .solid: "cube.fill"
        case .liquid: "drop.fill"
        case .gas: "cloud.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

struct ChemicalElement: Identifiable {
    let id: Int
    let name: String
    let symbol: String
    let atomicNumber: Int
    let atomicMass: String
    let category: ElementCategory
    let electronConfig: String
    let stateAtRoomTemp: ElementState
    let discoveryYear: String
    let funFact: String
    let group: Int
    let period: Int
}

// MARK: - Quiz Model

struct ElementQuizQuestion: Identifiable {
    let id = UUID()
    let question: String
    let options: [String]
    let correctIndex: Int
}

// MARK: - Periodic Table View

struct PeriodicTableView: View {
    @State private var searchText = ""
    @State private var selectedElement: ChemicalElement?
    @State private var showDetail = false
    @State private var showQuiz = false
    @State private var quizScore = 0
    @State private var quizQuestionIndex = 0
    @State private var quizAnswered = false
    @State private var quizCorrect = false
    @State private var selectedFilter: ElementCategory?
    @State private var appeared = false
    @State private var showLegend = false
    @State private var cachedQuizQuestions: [ElementQuizQuestion] = []

    private let columns = 18

    var filteredElements: [ChemicalElement] {
        let base = selectedFilter == nil ? Self.elements : Self.elements.filter { $0.category == selectedFilter }
        if searchText.isEmpty { return base }
        let query = searchText.lowercased()
        return base.filter {
            $0.name.lowercased().contains(query) ||
            $0.symbol.lowercased().contains(query) ||
            String($0.atomicNumber).contains(query)
        }
    }

    private func generateQuizQuestions() {
        var questions: [ElementQuizQuestion] = []
        let shuffled = Self.elements.shuffled()
        for i in 0..<min(10, shuffled.count) {
            let el = shuffled[i]
            if i % 2 == 0 {
                let correct = el.name
                var opts = Self.elements.filter { $0.id != el.id }.shuffled().prefix(3).map(\.name)
                let insertAt = Int.random(in: 0...opts.count)
                opts.insert(correct, at: insertAt)
                questions.append(ElementQuizQuestion(
                    question: "What element has atomic number \(el.atomicNumber)?",
                    options: opts,
                    correctIndex: insertAt
                ))
            } else {
                let correct = el.symbol
                var opts = Self.elements.filter { $0.id != el.id }.shuffled().prefix(3).map(\.symbol)
                let insertAt = Int.random(in: 0...opts.count)
                opts.insert(correct, at: insertAt)
                questions.append(ElementQuizQuestion(
                    question: "What is the symbol for \(el.name)?",
                    options: opts,
                    correctIndex: insertAt
                ))
            }
        }
        cachedQuizQuestions = questions
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                searchAndFilterSection
                periodicTableGrid
                legendSection
                quizButton
            }
            .padding()
        }
        .navigationTitle("Periodic Table Explorer")
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.indigo.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .sheet(isPresented: $showDetail) {
            if let el = selectedElement {
                ElementDetailSheet(element: el)
            }
        }
        .sheet(isPresented: $showQuiz) {
            QuizSheet(
                questions: cachedQuizQuestions,
                score: $quizScore,
                questionIndex: $quizQuestionIndex,
                answered: $quizAnswered,
                correct: $quizCorrect
            )
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appeared = true } }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "atom")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.pulse, options: .repeating)
                VStack(alignment: .leading) {
                    Text("Periodic Table")
                        .font(.title.bold())
                    Text("All 118 Elements")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Search & Filter

    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by name, symbol, or number...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: selectedFilter == nil) {
                        withAnimation { selectedFilter = nil }
                    }
                    ForEach(ElementCategory.allCases, id: \.self) { cat in
                        FilterChip(title: cat.rawValue, color: cat.color, isSelected: selectedFilter == cat) {
                            withAnimation { selectedFilter = selectedFilter == cat ? nil : cat }
                        }
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    // MARK: - Periodic Table Grid

    private var periodicTableGrid: some View {
        VStack(spacing: 2) {
            if !searchText.isEmpty || selectedFilter != nil {
                // Show filtered results as a simple grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 6), spacing: 3) {
                    ForEach(filteredElements) { el in
                        ElementCell(element: el)
                            .onTapGesture {
                                selectedElement = el
                                showDetail = true
                            }
                    }
                }
            } else {
                // Standard periodic table layout
                ForEach(1...7, id: \.self) { period in
                    HStack(spacing: 2) {
                        ForEach(1...18, id: \.self) { group in
                            if let el = elementAt(period: period, group: group) {
                                ElementCell(element: el)
                                    .onTapGesture {
                                        selectedElement = el
                                        showDetail = true
                                    }
                            } else {
                                Color.clear
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }

                // Spacer row
                HStack {
                    Text("Lanthanides & Actinides")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Lanthanides (period 8 proxy)
                HStack(spacing: 2) {
                    Text("La")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize, height: cellSize)
                    ForEach(Self.elements.filter({ $0.category == .lanthanide })) { el in
                        ElementCell(element: el)
                            .onTapGesture {
                                selectedElement = el
                                showDetail = true
                            }
                    }
                }

                // Actinides (period 9 proxy)
                HStack(spacing: 2) {
                    Text("Ac")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize, height: cellSize)
                    ForEach(Self.elements.filter({ $0.category == .actinide })) { el in
                        ElementCell(element: el)
                            .onTapGesture {
                                selectedElement = el
                                showDetail = true
                            }
                    }
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
    }

    private var cellSize: CGFloat { 18 }

    private func elementAt(period: Int, group: Int) -> ChemicalElement? {
        Self.elements.first(where: { $0.period == period && $0.group == group })
    }

    // MARK: - Legend

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showLegend.toggle() }
            } label: {
                HStack {
                    Image(systemName: "paintpalette.fill")
                    Text("Color Legend")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: showLegend ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(.primary)
            }

            if showLegend {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(ElementCategory.allCases, id: \.self) { cat in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cat.color)
                                .frame(width: 16, height: 16)
                            Text(cat.rawValue)
                                .font(.caption2)
                            Spacer()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Quiz Button

    private var quizButton: some View {
        Button {
            quizScore = 0
            quizQuestionIndex = 0
            quizAnswered = false
            generateQuizQuestions()
            showQuiz = true
        } label: {
            HStack {
                Image(systemName: "brain.head.profile")
                Text("Take Element Quiz")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
            }
            .padding()
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing),
                in: .rect(cornerRadius: 16)
            )
        }
        .hapticFeedback(.impact(flexibility: .soft), trigger: showQuiz)
    }

    // MARK: - All 118 Elements

    static let elements: [ChemicalElement] = [
        // Period 1
        ChemicalElement(id: 1, name: "Hydrogen", symbol: "H", atomicNumber: 1, atomicMass: "1.008", category: .nonmetal, electronConfig: "1s1", stateAtRoomTemp: .gas, discoveryYear: "1766", funFact: "Hydrogen is the most abundant element in the universe, making up about 75% of all matter.", group: 1, period: 1),
        ChemicalElement(id: 2, name: "Helium", symbol: "He", atomicNumber: 2, atomicMass: "4.003", category: .nobleGas, electronConfig: "1s2", stateAtRoomTemp: .gas, discoveryYear: "1868", funFact: "Helium was first discovered in the sun's spectrum before being found on Earth.", group: 18, period: 1),
        // Period 2
        ChemicalElement(id: 3, name: "Lithium", symbol: "Li", atomicNumber: 3, atomicMass: "6.941", category: .alkaliMetal, electronConfig: "[He] 2s1", stateAtRoomTemp: .solid, discoveryYear: "1817", funFact: "Lithium is the lightest metal and is used in rechargeable batteries.", group: 1, period: 2),
        ChemicalElement(id: 4, name: "Beryllium", symbol: "Be", atomicNumber: 4, atomicMass: "9.012", category: .alkalineEarthMetal, electronConfig: "[He] 2s2", stateAtRoomTemp: .solid, discoveryYear: "1798", funFact: "Beryllium is used in X-ray windows because X-rays pass through it easily.", group: 2, period: 2),
        ChemicalElement(id: 5, name: "Boron", symbol: "B", atomicNumber: 5, atomicMass: "10.81", category: .metalloid, electronConfig: "[He] 2s2 2p1", stateAtRoomTemp: .solid, discoveryYear: "1808", funFact: "Boron is essential for plant growth and is found in borax cleaning products.", group: 13, period: 2),
        ChemicalElement(id: 6, name: "Carbon", symbol: "C", atomicNumber: 6, atomicMass: "12.01", category: .nonmetal, electronConfig: "[He] 2s2 2p2", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "Carbon is the basis of all known life and can form more compounds than any other element.", group: 14, period: 2),
        ChemicalElement(id: 7, name: "Nitrogen", symbol: "N", atomicNumber: 7, atomicMass: "14.01", category: .nonmetal, electronConfig: "[He] 2s2 2p3", stateAtRoomTemp: .gas, discoveryYear: "1772", funFact: "Nitrogen makes up 78% of Earth's atmosphere.", group: 15, period: 2),
        ChemicalElement(id: 8, name: "Oxygen", symbol: "O", atomicNumber: 8, atomicMass: "16.00", category: .nonmetal, electronConfig: "[He] 2s2 2p4", stateAtRoomTemp: .gas, discoveryYear: "1774", funFact: "Oxygen is the third most abundant element in the universe.", group: 16, period: 2),
        ChemicalElement(id: 9, name: "Fluorine", symbol: "F", atomicNumber: 9, atomicMass: "19.00", category: .halogen, electronConfig: "[He] 2s2 2p5", stateAtRoomTemp: .gas, discoveryYear: "1886", funFact: "Fluorine is the most reactive of all elements and is added to toothpaste.", group: 17, period: 2),
        ChemicalElement(id: 10, name: "Neon", symbol: "Ne", atomicNumber: 10, atomicMass: "20.18", category: .nobleGas, electronConfig: "[He] 2s2 2p6", stateAtRoomTemp: .gas, discoveryYear: "1898", funFact: "Neon signs glow red-orange; other 'neon' colors use different gases.", group: 18, period: 2),
        // Period 3
        ChemicalElement(id: 11, name: "Sodium", symbol: "Na", atomicNumber: 11, atomicMass: "22.99", category: .alkaliMetal, electronConfig: "[Ne] 3s1", stateAtRoomTemp: .solid, discoveryYear: "1807", funFact: "Sodium reacts violently with water and its symbol Na comes from the Latin 'natrium'.", group: 1, period: 3),
        ChemicalElement(id: 12, name: "Magnesium", symbol: "Mg", atomicNumber: 12, atomicMass: "24.31", category: .alkalineEarthMetal, electronConfig: "[Ne] 3s2", stateAtRoomTemp: .solid, discoveryYear: "1755", funFact: "Magnesium burns with an intensely bright white flame.", group: 2, period: 3),
        ChemicalElement(id: 13, name: "Aluminum", symbol: "Al", atomicNumber: 13, atomicMass: "26.98", category: .postTransitionMetal, electronConfig: "[Ne] 3s2 3p1", stateAtRoomTemp: .solid, discoveryYear: "1825", funFact: "Aluminum was once more valuable than gold before modern extraction methods.", group: 13, period: 3),
        ChemicalElement(id: 14, name: "Silicon", symbol: "Si", atomicNumber: 14, atomicMass: "28.09", category: .metalloid, electronConfig: "[Ne] 3s2 3p2", stateAtRoomTemp: .solid, discoveryYear: "1824", funFact: "Silicon is the basis of computer chips and Silicon Valley is named after it.", group: 14, period: 3),
        ChemicalElement(id: 15, name: "Phosphorus", symbol: "P", atomicNumber: 15, atomicMass: "30.97", category: .nonmetal, electronConfig: "[Ne] 3s2 3p3", stateAtRoomTemp: .solid, discoveryYear: "1669", funFact: "Phosphorus was discovered from urine and glows in the dark (white phosphorus).", group: 15, period: 3),
        ChemicalElement(id: 16, name: "Sulfur", symbol: "S", atomicNumber: 16, atomicMass: "32.07", category: .nonmetal, electronConfig: "[Ne] 3s2 3p4", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "Sulfur is known as brimstone in the Bible and smells like rotten eggs.", group: 16, period: 3),
        ChemicalElement(id: 17, name: "Chlorine", symbol: "Cl", atomicNumber: 17, atomicMass: "35.45", category: .halogen, electronConfig: "[Ne] 3s2 3p5", stateAtRoomTemp: .gas, discoveryYear: "1774", funFact: "Chlorine is used to purify drinking water and swimming pools.", group: 17, period: 3),
        ChemicalElement(id: 18, name: "Argon", symbol: "Ar", atomicNumber: 18, atomicMass: "39.95", category: .nobleGas, electronConfig: "[Ne] 3s2 3p6", stateAtRoomTemp: .gas, discoveryYear: "1894", funFact: "Argon makes up about 1% of Earth's atmosphere and is used in light bulbs.", group: 18, period: 3),
        // Period 4
        ChemicalElement(id: 19, name: "Potassium", symbol: "K", atomicNumber: 19, atomicMass: "39.10", category: .alkaliMetal, electronConfig: "[Ar] 4s1", stateAtRoomTemp: .solid, discoveryYear: "1807", funFact: "Bananas are rich in potassium, which is essential for nerve function.", group: 1, period: 4),
        ChemicalElement(id: 20, name: "Calcium", symbol: "Ca", atomicNumber: 20, atomicMass: "40.08", category: .alkalineEarthMetal, electronConfig: "[Ar] 4s2", stateAtRoomTemp: .solid, discoveryYear: "1808", funFact: "Calcium is the most abundant metal in the human body, found mostly in bones and teeth.", group: 2, period: 4),
        ChemicalElement(id: 21, name: "Scandium", symbol: "Sc", atomicNumber: 21, atomicMass: "44.96", category: .transitionMetal, electronConfig: "[Ar] 3d1 4s2", stateAtRoomTemp: .solid, discoveryYear: "1879", funFact: "Scandium is used in aerospace alloys to make lighter, stronger aircraft.", group: 3, period: 4),
        ChemicalElement(id: 22, name: "Titanium", symbol: "Ti", atomicNumber: 22, atomicMass: "47.87", category: .transitionMetal, electronConfig: "[Ar] 3d2 4s2", stateAtRoomTemp: .solid, discoveryYear: "1791", funFact: "Titanium is as strong as steel but 45% lighter, used in jets and implants.", group: 4, period: 4),
        ChemicalElement(id: 23, name: "Vanadium", symbol: "V", atomicNumber: 23, atomicMass: "50.94", category: .transitionMetal, electronConfig: "[Ar] 3d3 4s2", stateAtRoomTemp: .solid, discoveryYear: "1801", funFact: "Vanadium compounds come in many beautiful colors.", group: 5, period: 4),
        ChemicalElement(id: 24, name: "Chromium", symbol: "Cr", atomicNumber: 24, atomicMass: "52.00", category: .transitionMetal, electronConfig: "[Ar] 3d5 4s1", stateAtRoomTemp: .solid, discoveryYear: "1797", funFact: "Chrome plating gets its shiny finish from chromium.", group: 6, period: 4),
        ChemicalElement(id: 25, name: "Manganese", symbol: "Mn", atomicNumber: 25, atomicMass: "54.94", category: .transitionMetal, electronConfig: "[Ar] 3d5 4s2", stateAtRoomTemp: .solid, discoveryYear: "1774", funFact: "Manganese is essential for steel production and bone formation.", group: 7, period: 4),
        ChemicalElement(id: 26, name: "Iron", symbol: "Fe", atomicNumber: 26, atomicMass: "55.85", category: .transitionMetal, electronConfig: "[Ar] 3d6 4s2", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "Earth's core is mostly iron, and it's what makes blood red.", group: 8, period: 4),
        ChemicalElement(id: 27, name: "Cobalt", symbol: "Co", atomicNumber: 27, atomicMass: "58.93", category: .transitionMetal, electronConfig: "[Ar] 3d7 4s2", stateAtRoomTemp: .solid, discoveryYear: "1735", funFact: "Cobalt blue has been used as a pigment since ancient times.", group: 9, period: 4),
        ChemicalElement(id: 28, name: "Nickel", symbol: "Ni", atomicNumber: 28, atomicMass: "58.69", category: .transitionMetal, electronConfig: "[Ar] 3d8 4s2", stateAtRoomTemp: .solid, discoveryYear: "1751", funFact: "The Canadian nickel coin was once made almost entirely of nickel.", group: 10, period: 4),
        ChemicalElement(id: 29, name: "Copper", symbol: "Cu", atomicNumber: 29, atomicMass: "63.55", category: .transitionMetal, electronConfig: "[Ar] 3d10 4s1", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "The Statue of Liberty is covered in 80 tonnes of copper.", group: 11, period: 4),
        ChemicalElement(id: 30, name: "Zinc", symbol: "Zn", atomicNumber: 30, atomicMass: "65.38", category: .transitionMetal, electronConfig: "[Ar] 3d10 4s2", stateAtRoomTemp: .solid, discoveryYear: "1746", funFact: "Zinc coating (galvanizing) protects steel from rusting.", group: 12, period: 4),
        ChemicalElement(id: 31, name: "Gallium", symbol: "Ga", atomicNumber: 31, atomicMass: "69.72", category: .postTransitionMetal, electronConfig: "[Ar] 3d10 4s2 4p1", stateAtRoomTemp: .solid, discoveryYear: "1875", funFact: "Gallium melts in your hand because its melting point is only 29.76 C.", group: 13, period: 4),
        ChemicalElement(id: 32, name: "Germanium", symbol: "Ge", atomicNumber: 32, atomicMass: "72.63", category: .metalloid, electronConfig: "[Ar] 3d10 4s2 4p2", stateAtRoomTemp: .solid, discoveryYear: "1886", funFact: "Germanium was predicted by Mendeleev before it was discovered.", group: 14, period: 4),
        ChemicalElement(id: 33, name: "Arsenic", symbol: "As", atomicNumber: 33, atomicMass: "74.92", category: .metalloid, electronConfig: "[Ar] 3d10 4s2 4p3", stateAtRoomTemp: .solid, discoveryYear: "1250", funFact: "Arsenic was historically known as the 'king of poisons'.", group: 15, period: 4),
        ChemicalElement(id: 34, name: "Selenium", symbol: "Se", atomicNumber: 34, atomicMass: "78.97", category: .nonmetal, electronConfig: "[Ar] 3d10 4s2 4p4", stateAtRoomTemp: .solid, discoveryYear: "1817", funFact: "Selenium is named after the Moon (Selene) and is essential in small amounts.", group: 16, period: 4),
        ChemicalElement(id: 35, name: "Bromine", symbol: "Br", atomicNumber: 35, atomicMass: "79.90", category: .halogen, electronConfig: "[Ar] 3d10 4s2 4p5", stateAtRoomTemp: .liquid, discoveryYear: "1826", funFact: "Bromine is one of only two elements that are liquid at room temperature.", group: 17, period: 4),
        ChemicalElement(id: 36, name: "Krypton", symbol: "Kr", atomicNumber: 36, atomicMass: "83.80", category: .nobleGas, electronConfig: "[Ar] 3d10 4s2 4p6", stateAtRoomTemp: .gas, discoveryYear: "1898", funFact: "Krypton is real! Superman's home planet was named after this element.", group: 18, period: 4),
        // Period 5
        ChemicalElement(id: 37, name: "Rubidium", symbol: "Rb", atomicNumber: 37, atomicMass: "85.47", category: .alkaliMetal, electronConfig: "[Kr] 5s1", stateAtRoomTemp: .solid, discoveryYear: "1861", funFact: "Rubidium ignites spontaneously in air.", group: 1, period: 5),
        ChemicalElement(id: 38, name: "Strontium", symbol: "Sr", atomicNumber: 38, atomicMass: "87.62", category: .alkalineEarthMetal, electronConfig: "[Kr] 5s2", stateAtRoomTemp: .solid, discoveryYear: "1790", funFact: "Strontium compounds produce the red color in fireworks.", group: 2, period: 5),
        ChemicalElement(id: 39, name: "Yttrium", symbol: "Y", atomicNumber: 39, atomicMass: "88.91", category: .transitionMetal, electronConfig: "[Kr] 4d1 5s2", stateAtRoomTemp: .solid, discoveryYear: "1794", funFact: "Yttrium is used in LEDs and energy-efficient light bulbs.", group: 3, period: 5),
        ChemicalElement(id: 40, name: "Zirconium", symbol: "Zr", atomicNumber: 40, atomicMass: "91.22", category: .transitionMetal, electronConfig: "[Kr] 4d2 5s2", stateAtRoomTemp: .solid, discoveryYear: "1789", funFact: "Cubic zirconia (from zirconium) is a popular diamond substitute.", group: 4, period: 5),
        ChemicalElement(id: 41, name: "Niobium", symbol: "Nb", atomicNumber: 41, atomicMass: "92.91", category: .transitionMetal, electronConfig: "[Kr] 4d4 5s1", stateAtRoomTemp: .solid, discoveryYear: "1801", funFact: "Niobium is used in superconducting magnets for MRI machines.", group: 5, period: 5),
        ChemicalElement(id: 42, name: "Molybdenum", symbol: "Mo", atomicNumber: 42, atomicMass: "95.95", category: .transitionMetal, electronConfig: "[Kr] 4d5 5s1", stateAtRoomTemp: .solid, discoveryYear: "1781", funFact: "Molybdenum is essential for life and is found in enzymes.", group: 6, period: 5),
        ChemicalElement(id: 43, name: "Technetium", symbol: "Tc", atomicNumber: 43, atomicMass: "(98)", category: .transitionMetal, electronConfig: "[Kr] 4d5 5s2", stateAtRoomTemp: .solid, discoveryYear: "1937", funFact: "Technetium was the first artificially produced element.", group: 7, period: 5),
        ChemicalElement(id: 44, name: "Ruthenium", symbol: "Ru", atomicNumber: 44, atomicMass: "101.1", category: .transitionMetal, electronConfig: "[Kr] 4d7 5s1", stateAtRoomTemp: .solid, discoveryYear: "1844", funFact: "Ruthenium is used to harden platinum and palladium alloys.", group: 8, period: 5),
        ChemicalElement(id: 45, name: "Rhodium", symbol: "Rh", atomicNumber: 45, atomicMass: "102.9", category: .transitionMetal, electronConfig: "[Kr] 4d8 5s1", stateAtRoomTemp: .solid, discoveryYear: "1803", funFact: "Rhodium is the most expensive precious metal, used in catalytic converters.", group: 9, period: 5),
        ChemicalElement(id: 46, name: "Palladium", symbol: "Pd", atomicNumber: 46, atomicMass: "106.4", category: .transitionMetal, electronConfig: "[Kr] 4d10", stateAtRoomTemp: .solid, discoveryYear: "1803", funFact: "Palladium can absorb up to 900 times its own volume of hydrogen.", group: 10, period: 5),
        ChemicalElement(id: 47, name: "Silver", symbol: "Ag", atomicNumber: 47, atomicMass: "107.9", category: .transitionMetal, electronConfig: "[Kr] 4d10 5s1", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "Silver has the highest electrical conductivity of all elements.", group: 11, period: 5),
        ChemicalElement(id: 48, name: "Cadmium", symbol: "Cd", atomicNumber: 48, atomicMass: "112.4", category: .transitionMetal, electronConfig: "[Kr] 4d10 5s2", stateAtRoomTemp: .solid, discoveryYear: "1817", funFact: "Cadmium yellow was a popular paint pigment used by artists like Monet.", group: 12, period: 5),
        ChemicalElement(id: 49, name: "Indium", symbol: "In", atomicNumber: 49, atomicMass: "114.8", category: .postTransitionMetal, electronConfig: "[Kr] 4d10 5s2 5p1", stateAtRoomTemp: .solid, discoveryYear: "1863", funFact: "Indium is used in touchscreens and LCD displays.", group: 13, period: 5),
        ChemicalElement(id: 50, name: "Tin", symbol: "Sn", atomicNumber: 50, atomicMass: "118.7", category: .postTransitionMetal, electronConfig: "[Kr] 4d10 5s2 5p2", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "Tin cans are actually steel coated with a thin layer of tin.", group: 14, period: 5),
        ChemicalElement(id: 51, name: "Antimony", symbol: "Sb", atomicNumber: 51, atomicMass: "121.8", category: .metalloid, electronConfig: "[Kr] 4d10 5s2 5p3", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "Ancient Egyptians used antimony as eye makeup (kohl).", group: 15, period: 5),
        ChemicalElement(id: 52, name: "Tellurium", symbol: "Te", atomicNumber: 52, atomicMass: "127.6", category: .metalloid, electronConfig: "[Kr] 4d10 5s2 5p4", stateAtRoomTemp: .solid, discoveryYear: "1783", funFact: "Tellurium is rarer than gold in Earth's crust.", group: 16, period: 5),
        ChemicalElement(id: 53, name: "Iodine", symbol: "I", atomicNumber: 53, atomicMass: "126.9", category: .halogen, electronConfig: "[Kr] 4d10 5s2 5p5", stateAtRoomTemp: .solid, discoveryYear: "1811", funFact: "Iodine is essential for thyroid function and is added to table salt.", group: 17, period: 5),
        ChemicalElement(id: 54, name: "Xenon", symbol: "Xe", atomicNumber: 54, atomicMass: "131.3", category: .nobleGas, electronConfig: "[Kr] 4d10 5s2 5p6", stateAtRoomTemp: .gas, discoveryYear: "1898", funFact: "Xenon headlights produce a bright blue-white light used in luxury cars.", group: 18, period: 5),
        // Period 6
        ChemicalElement(id: 55, name: "Cesium", symbol: "Cs", atomicNumber: 55, atomicMass: "132.9", category: .alkaliMetal, electronConfig: "[Xe] 6s1", stateAtRoomTemp: .solid, discoveryYear: "1860", funFact: "Cesium atomic clocks are accurate to 1 second in 300 million years.", group: 1, period: 6),
        ChemicalElement(id: 56, name: "Barium", symbol: "Ba", atomicNumber: 56, atomicMass: "137.3", category: .alkalineEarthMetal, electronConfig: "[Xe] 6s2", stateAtRoomTemp: .solid, discoveryYear: "1808", funFact: "Barium is used in medical imaging to make organs visible on X-rays.", group: 2, period: 6),
        // Lanthanides 57-71 (group 0 indicates lanthanide row)
        ChemicalElement(id: 57, name: "Lanthanum", symbol: "La", atomicNumber: 57, atomicMass: "138.9", category: .lanthanide, electronConfig: "[Xe] 5d1 6s2", stateAtRoomTemp: .solid, discoveryYear: "1839", funFact: "Lanthanum is used in camera and telescope lenses.", group: 0, period: 8),
        ChemicalElement(id: 58, name: "Cerium", symbol: "Ce", atomicNumber: 58, atomicMass: "140.1", category: .lanthanide, electronConfig: "[Xe] 4f1 5d1 6s2", stateAtRoomTemp: .solid, discoveryYear: "1803", funFact: "Cerium is the most abundant rare earth element.", group: 0, period: 8),
        ChemicalElement(id: 59, name: "Praseodymium", symbol: "Pr", atomicNumber: 59, atomicMass: "140.9", category: .lanthanide, electronConfig: "[Xe] 4f3 6s2", stateAtRoomTemp: .solid, discoveryYear: "1885", funFact: "Praseodymium creates an intense green color in glass.", group: 0, period: 8),
        ChemicalElement(id: 60, name: "Neodymium", symbol: "Nd", atomicNumber: 60, atomicMass: "144.2", category: .lanthanide, electronConfig: "[Xe] 4f4 6s2", stateAtRoomTemp: .solid, discoveryYear: "1885", funFact: "Neodymium magnets are the strongest permanent magnets known.", group: 0, period: 8),
        ChemicalElement(id: 61, name: "Promethium", symbol: "Pm", atomicNumber: 61, atomicMass: "(145)", category: .lanthanide, electronConfig: "[Xe] 4f5 6s2", stateAtRoomTemp: .solid, discoveryYear: "1945", funFact: "Promethium is the only radioactive rare earth element.", group: 0, period: 8),
        ChemicalElement(id: 62, name: "Samarium", symbol: "Sm", atomicNumber: 62, atomicMass: "150.4", category: .lanthanide, electronConfig: "[Xe] 4f6 6s2", stateAtRoomTemp: .solid, discoveryYear: "1879", funFact: "Samarium-cobalt magnets can work at extremely high temperatures.", group: 0, period: 8),
        ChemicalElement(id: 63, name: "Europium", symbol: "Eu", atomicNumber: 63, atomicMass: "152.0", category: .lanthanide, electronConfig: "[Xe] 4f7 6s2", stateAtRoomTemp: .solid, discoveryYear: "1901", funFact: "Europium is used in Euro banknotes as an anti-counterfeiting measure.", group: 0, period: 8),
        ChemicalElement(id: 64, name: "Gadolinium", symbol: "Gd", atomicNumber: 64, atomicMass: "157.3", category: .lanthanide, electronConfig: "[Xe] 4f7 5d1 6s2", stateAtRoomTemp: .solid, discoveryYear: "1880", funFact: "Gadolinium is used as a contrast agent in MRI scans.", group: 0, period: 8),
        ChemicalElement(id: 65, name: "Terbium", symbol: "Tb", atomicNumber: 65, atomicMass: "158.9", category: .lanthanide, electronConfig: "[Xe] 4f9 6s2", stateAtRoomTemp: .solid, discoveryYear: "1843", funFact: "Terbium is used in green phosphors for color TV screens.", group: 0, period: 8),
        ChemicalElement(id: 66, name: "Dysprosium", symbol: "Dy", atomicNumber: 66, atomicMass: "162.5", category: .lanthanide, electronConfig: "[Xe] 4f10 6s2", stateAtRoomTemp: .solid, discoveryYear: "1886", funFact: "Its name means 'hard to get' in Greek, reflecting difficulty of isolation.", group: 0, period: 8),
        ChemicalElement(id: 67, name: "Holmium", symbol: "Ho", atomicNumber: 67, atomicMass: "164.9", category: .lanthanide, electronConfig: "[Xe] 4f11 6s2", stateAtRoomTemp: .solid, discoveryYear: "1878", funFact: "Holmium has the highest magnetic moment of any naturally occurring element.", group: 0, period: 8),
        ChemicalElement(id: 68, name: "Erbium", symbol: "Er", atomicNumber: 68, atomicMass: "167.3", category: .lanthanide, electronConfig: "[Xe] 4f12 6s2", stateAtRoomTemp: .solid, discoveryYear: "1842", funFact: "Erbium is used in fiber optic cables to amplify light signals.", group: 0, period: 8),
        ChemicalElement(id: 69, name: "Thulium", symbol: "Tm", atomicNumber: 69, atomicMass: "168.9", category: .lanthanide, electronConfig: "[Xe] 4f13 6s2", stateAtRoomTemp: .solid, discoveryYear: "1879", funFact: "Thulium is the least abundant naturally occurring lanthanide.", group: 0, period: 8),
        ChemicalElement(id: 70, name: "Ytterbium", symbol: "Yb", atomicNumber: 70, atomicMass: "173.0", category: .lanthanide, electronConfig: "[Xe] 4f14 6s2", stateAtRoomTemp: .solid, discoveryYear: "1878", funFact: "Ytterbium is being studied for next-generation atomic clocks.", group: 0, period: 8),
        ChemicalElement(id: 71, name: "Lutetium", symbol: "Lu", atomicNumber: 71, atomicMass: "175.0", category: .lanthanide, electronConfig: "[Xe] 4f14 5d1 6s2", stateAtRoomTemp: .solid, discoveryYear: "1907", funFact: "Lutetium is the hardest and densest lanthanide element.", group: 0, period: 8),
        // Continue Period 6 main block
        ChemicalElement(id: 72, name: "Hafnium", symbol: "Hf", atomicNumber: 72, atomicMass: "178.5", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d2 6s2", stateAtRoomTemp: .solid, discoveryYear: "1923", funFact: "Hafnium is used in nuclear reactor control rods.", group: 4, period: 6),
        ChemicalElement(id: 73, name: "Tantalum", symbol: "Ta", atomicNumber: 73, atomicMass: "180.9", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d3 6s2", stateAtRoomTemp: .solid, discoveryYear: "1802", funFact: "Tantalum is used in smartphones and gaming consoles.", group: 5, period: 6),
        ChemicalElement(id: 74, name: "Tungsten", symbol: "W", atomicNumber: 74, atomicMass: "183.8", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d4 6s2", stateAtRoomTemp: .solid, discoveryYear: "1783", funFact: "Tungsten has the highest melting point of all elements at 3422 C.", group: 6, period: 6),
        ChemicalElement(id: 75, name: "Rhenium", symbol: "Re", atomicNumber: 75, atomicMass: "186.2", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d5 6s2", stateAtRoomTemp: .solid, discoveryYear: "1925", funFact: "Rhenium was the last stable element to be discovered.", group: 7, period: 6),
        ChemicalElement(id: 76, name: "Osmium", symbol: "Os", atomicNumber: 76, atomicMass: "190.2", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d6 6s2", stateAtRoomTemp: .solid, discoveryYear: "1803", funFact: "Osmium is the densest naturally occurring element.", group: 8, period: 6),
        ChemicalElement(id: 77, name: "Iridium", symbol: "Ir", atomicNumber: 77, atomicMass: "192.2", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d7 6s2", stateAtRoomTemp: .solid, discoveryYear: "1803", funFact: "An iridium-rich layer in rock marks the asteroid impact that killed the dinosaurs.", group: 9, period: 6),
        ChemicalElement(id: 78, name: "Platinum", symbol: "Pt", atomicNumber: 78, atomicMass: "195.1", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d9 6s1", stateAtRoomTemp: .solid, discoveryYear: "1735", funFact: "Platinum is rarer than gold and is used in catalytic converters.", group: 10, period: 6),
        ChemicalElement(id: 79, name: "Gold", symbol: "Au", atomicNumber: 79, atomicMass: "197.0", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d10 6s1", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "All the gold ever mined would fit in about 3.5 Olympic swimming pools.", group: 11, period: 6),
        ChemicalElement(id: 80, name: "Mercury", symbol: "Hg", atomicNumber: 80, atomicMass: "200.6", category: .transitionMetal, electronConfig: "[Xe] 4f14 5d10 6s2", stateAtRoomTemp: .liquid, discoveryYear: "Ancient", funFact: "Mercury is the only metal that is liquid at room temperature.", group: 12, period: 6),
        ChemicalElement(id: 81, name: "Thallium", symbol: "Tl", atomicNumber: 81, atomicMass: "204.4", category: .postTransitionMetal, electronConfig: "[Xe] 4f14 5d10 6s2 6p1", stateAtRoomTemp: .solid, discoveryYear: "1861", funFact: "Thallium was once used as rat poison due to its extreme toxicity.", group: 13, period: 6),
        ChemicalElement(id: 82, name: "Lead", symbol: "Pb", atomicNumber: 82, atomicMass: "207.2", category: .postTransitionMetal, electronConfig: "[Xe] 4f14 5d10 6s2 6p2", stateAtRoomTemp: .solid, discoveryYear: "Ancient", funFact: "Romans used lead pipes for plumbing - 'plumbing' comes from 'plumbum' (lead).", group: 14, period: 6),
        ChemicalElement(id: 83, name: "Bismuth", symbol: "Bi", atomicNumber: 83, atomicMass: "209.0", category: .postTransitionMetal, electronConfig: "[Xe] 4f14 5d10 6s2 6p3", stateAtRoomTemp: .solid, discoveryYear: "1753", funFact: "Bismuth crystals form beautiful rainbow-colored hopper structures.", group: 15, period: 6),
        ChemicalElement(id: 84, name: "Polonium", symbol: "Po", atomicNumber: 84, atomicMass: "(209)", category: .postTransitionMetal, electronConfig: "[Xe] 4f14 5d10 6s2 6p4", stateAtRoomTemp: .solid, discoveryYear: "1898", funFact: "Polonium was discovered by Marie Curie and named after her homeland Poland.", group: 16, period: 6),
        ChemicalElement(id: 85, name: "Astatine", symbol: "At", atomicNumber: 85, atomicMass: "(210)", category: .halogen, electronConfig: "[Xe] 4f14 5d10 6s2 6p5", stateAtRoomTemp: .solid, discoveryYear: "1940", funFact: "Astatine is the rarest naturally occurring element on Earth.", group: 17, period: 6),
        ChemicalElement(id: 86, name: "Radon", symbol: "Rn", atomicNumber: 86, atomicMass: "(222)", category: .nobleGas, electronConfig: "[Xe] 4f14 5d10 6s2 6p6", stateAtRoomTemp: .gas, discoveryYear: "1900", funFact: "Radon is a radioactive gas that can accumulate in basements.", group: 18, period: 6),
        // Period 7
        ChemicalElement(id: 87, name: "Francium", symbol: "Fr", atomicNumber: 87, atomicMass: "(223)", category: .alkaliMetal, electronConfig: "[Rn] 7s1", stateAtRoomTemp: .solid, discoveryYear: "1939", funFact: "Francium is the most unstable of the first 101 elements.", group: 1, period: 7),
        ChemicalElement(id: 88, name: "Radium", symbol: "Ra", atomicNumber: 88, atomicMass: "(226)", category: .alkalineEarthMetal, electronConfig: "[Rn] 7s2", stateAtRoomTemp: .solid, discoveryYear: "1898", funFact: "Radium glows blue and was once used in glow-in-the-dark watch dials.", group: 2, period: 7),
        // Actinides 89-103
        ChemicalElement(id: 89, name: "Actinium", symbol: "Ac", atomicNumber: 89, atomicMass: "(227)", category: .actinide, electronConfig: "[Rn] 6d1 7s2", stateAtRoomTemp: .solid, discoveryYear: "1899", funFact: "Actinium glows blue in the dark due to its intense radioactivity.", group: 0, period: 9),
        ChemicalElement(id: 90, name: "Thorium", symbol: "Th", atomicNumber: 90, atomicMass: "232.0", category: .actinide, electronConfig: "[Rn] 6d2 7s2", stateAtRoomTemp: .solid, discoveryYear: "1829", funFact: "Thorium is being explored as a safer alternative nuclear fuel.", group: 0, period: 9),
        ChemicalElement(id: 91, name: "Protactinium", symbol: "Pa", atomicNumber: 91, atomicMass: "231.0", category: .actinide, electronConfig: "[Rn] 5f2 6d1 7s2", stateAtRoomTemp: .solid, discoveryYear: "1913", funFact: "Protactinium is one of the rarest and most expensive elements.", group: 0, period: 9),
        ChemicalElement(id: 92, name: "Uranium", symbol: "U", atomicNumber: 92, atomicMass: "238.0", category: .actinide, electronConfig: "[Rn] 5f3 6d1 7s2", stateAtRoomTemp: .solid, discoveryYear: "1789", funFact: "A single uranium fuel pellet contains as much energy as 1 tonne of coal.", group: 0, period: 9),
        ChemicalElement(id: 93, name: "Neptunium", symbol: "Np", atomicNumber: 93, atomicMass: "(237)", category: .actinide, electronConfig: "[Rn] 5f4 6d1 7s2", stateAtRoomTemp: .solid, discoveryYear: "1940", funFact: "Neptunium was named after the planet Neptune.", group: 0, period: 9),
        ChemicalElement(id: 94, name: "Plutonium", symbol: "Pu", atomicNumber: 94, atomicMass: "(244)", category: .actinide, electronConfig: "[Rn] 5f6 7s2", stateAtRoomTemp: .solid, discoveryYear: "1940", funFact: "Plutonium generates enough heat to be used as a power source in space probes.", group: 0, period: 9),
        ChemicalElement(id: 95, name: "Americium", symbol: "Am", atomicNumber: 95, atomicMass: "(243)", category: .actinide, electronConfig: "[Rn] 5f7 7s2", stateAtRoomTemp: .solid, discoveryYear: "1944", funFact: "Americium is in most household smoke detectors.", group: 0, period: 9),
        ChemicalElement(id: 96, name: "Curium", symbol: "Cm", atomicNumber: 96, atomicMass: "(247)", category: .actinide, electronConfig: "[Rn] 5f7 6d1 7s2", stateAtRoomTemp: .solid, discoveryYear: "1944", funFact: "Curium is named after Marie and Pierre Curie.", group: 0, period: 9),
        ChemicalElement(id: 97, name: "Berkelium", symbol: "Bk", atomicNumber: 97, atomicMass: "(247)", category: .actinide, electronConfig: "[Rn] 5f9 7s2", stateAtRoomTemp: .solid, discoveryYear: "1949", funFact: "Berkelium was first produced at UC Berkeley.", group: 0, period: 9),
        ChemicalElement(id: 98, name: "Californium", symbol: "Cf", atomicNumber: 98, atomicMass: "(251)", category: .actinide, electronConfig: "[Rn] 5f10 7s2", stateAtRoomTemp: .solid, discoveryYear: "1950", funFact: "Californium is used to start up nuclear reactors.", group: 0, period: 9),
        ChemicalElement(id: 99, name: "Einsteinium", symbol: "Es", atomicNumber: 99, atomicMass: "(252)", category: .actinide, electronConfig: "[Rn] 5f11 7s2", stateAtRoomTemp: .solid, discoveryYear: "1952", funFact: "Einsteinium was discovered in the debris of the first hydrogen bomb test.", group: 0, period: 9),
        ChemicalElement(id: 100, name: "Fermium", symbol: "Fm", atomicNumber: 100, atomicMass: "(257)", category: .actinide, electronConfig: "[Rn] 5f12 7s2", stateAtRoomTemp: .solid, discoveryYear: "1952", funFact: "Fermium is named after Enrico Fermi, pioneer of nuclear physics.", group: 0, period: 9),
        ChemicalElement(id: 101, name: "Mendelevium", symbol: "Md", atomicNumber: 101, atomicMass: "(258)", category: .actinide, electronConfig: "[Rn] 5f13 7s2", stateAtRoomTemp: .solid, discoveryYear: "1955", funFact: "Named after Dmitri Mendeleev, creator of the periodic table.", group: 0, period: 9),
        ChemicalElement(id: 102, name: "Nobelium", symbol: "No", atomicNumber: 102, atomicMass: "(259)", category: .actinide, electronConfig: "[Rn] 5f14 7s2", stateAtRoomTemp: .solid, discoveryYear: "1966", funFact: "Nobelium is named after Alfred Nobel, inventor of dynamite.", group: 0, period: 9),
        ChemicalElement(id: 103, name: "Lawrencium", symbol: "Lr", atomicNumber: 103, atomicMass: "(266)", category: .actinide, electronConfig: "[Rn] 5f14 7s2 7p1", stateAtRoomTemp: .solid, discoveryYear: "1961", funFact: "Named after Ernest Lawrence, inventor of the cyclotron.", group: 0, period: 9),
        // Continue Period 7 main block
        ChemicalElement(id: 104, name: "Rutherfordium", symbol: "Rf", atomicNumber: 104, atomicMass: "(267)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d2 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1969", funFact: "Named after Ernest Rutherford, the father of nuclear physics.", group: 4, period: 7),
        ChemicalElement(id: 105, name: "Dubnium", symbol: "Db", atomicNumber: 105, atomicMass: "(268)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d3 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1970", funFact: "Named after Dubna, Russia, home of the Joint Institute for Nuclear Research.", group: 5, period: 7),
        ChemicalElement(id: 106, name: "Seaborgium", symbol: "Sg", atomicNumber: 106, atomicMass: "(269)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d4 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1974", funFact: "Named after Glenn Seaborg while he was still alive, a rare honor.", group: 6, period: 7),
        ChemicalElement(id: 107, name: "Bohrium", symbol: "Bh", atomicNumber: 107, atomicMass: "(270)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d5 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1981", funFact: "Named after Niels Bohr, who revolutionized atomic theory.", group: 7, period: 7),
        ChemicalElement(id: 108, name: "Hassium", symbol: "Hs", atomicNumber: 108, atomicMass: "(277)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d6 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1984", funFact: "Named after the German state of Hesse where it was discovered.", group: 8, period: 7),
        ChemicalElement(id: 109, name: "Meitnerium", symbol: "Mt", atomicNumber: 109, atomicMass: "(278)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d7 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1982", funFact: "Named after Lise Meitner, who helped discover nuclear fission.", group: 9, period: 7),
        ChemicalElement(id: 110, name: "Darmstadtium", symbol: "Ds", atomicNumber: 110, atomicMass: "(281)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d8 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1994", funFact: "Named after Darmstadt, Germany, where it was first created.", group: 10, period: 7),
        ChemicalElement(id: 111, name: "Roentgenium", symbol: "Rg", atomicNumber: 111, atomicMass: "(282)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d9 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1994", funFact: "Named after Wilhelm Roentgen, who discovered X-rays.", group: 11, period: 7),
        ChemicalElement(id: 112, name: "Copernicium", symbol: "Cn", atomicNumber: 112, atomicMass: "(285)", category: .transitionMetal, electronConfig: "[Rn] 5f14 6d10 7s2", stateAtRoomTemp: .unknown, discoveryYear: "1996", funFact: "Named after Nicolaus Copernicus, who proposed the heliocentric model.", group: 12, period: 7),
        ChemicalElement(id: 113, name: "Nihonium", symbol: "Nh", atomicNumber: 113, atomicMass: "(286)", category: .postTransitionMetal, electronConfig: "[Rn] 5f14 6d10 7s2 7p1", stateAtRoomTemp: .unknown, discoveryYear: "2003", funFact: "First element discovered in Asia, named after Japan (Nihon).", group: 13, period: 7),
        ChemicalElement(id: 114, name: "Flerovium", symbol: "Fl", atomicNumber: 114, atomicMass: "(289)", category: .postTransitionMetal, electronConfig: "[Rn] 5f14 6d10 7s2 7p2", stateAtRoomTemp: .unknown, discoveryYear: "1999", funFact: "Named after the Flerov Laboratory of Nuclear Reactions.", group: 14, period: 7),
        ChemicalElement(id: 115, name: "Moscovium", symbol: "Mc", atomicNumber: 115, atomicMass: "(290)", category: .postTransitionMetal, electronConfig: "[Rn] 5f14 6d10 7s2 7p3", stateAtRoomTemp: .unknown, discoveryYear: "2003", funFact: "Named after Moscow Oblast, where the discovery lab is located.", group: 15, period: 7),
        ChemicalElement(id: 116, name: "Livermorium", symbol: "Lv", atomicNumber: 116, atomicMass: "(293)", category: .postTransitionMetal, electronConfig: "[Rn] 5f14 6d10 7s2 7p4", stateAtRoomTemp: .unknown, discoveryYear: "2000", funFact: "Named after Lawrence Livermore National Laboratory.", group: 16, period: 7),
        ChemicalElement(id: 117, name: "Tennessine", symbol: "Ts", atomicNumber: 117, atomicMass: "(294)", category: .halogen, electronConfig: "[Rn] 5f14 6d10 7s2 7p5", stateAtRoomTemp: .unknown, discoveryYear: "2010", funFact: "Named after Tennessee, home of Oak Ridge National Laboratory.", group: 17, period: 7),
        ChemicalElement(id: 118, name: "Oganesson", symbol: "Og", atomicNumber: 118, atomicMass: "(294)", category: .nobleGas, electronConfig: "[Rn] 5f14 6d10 7s2 7p6", stateAtRoomTemp: .unknown, discoveryYear: "2002", funFact: "Named after Yuri Oganessian, a pioneer of superheavy element research.", group: 18, period: 7),
    ]
}

// MARK: - Element Cell

private struct ElementCell: View {
    let element: ChemicalElement

    var body: some View {
        VStack(spacing: 0) {
            Text("\(element.atomicNumber)")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
            Text(element.symbol)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
        }
        .frame(width: 18, height: 18)
        .background(element.category.color.opacity(0.8))
        .clipShape(.rect(cornerRadius: 2))
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    var color: Color = .blue
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.3) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: 12))
                .foregroundStyle(isSelected ? color : .secondary)
        }
        .hapticFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Element Detail Sheet

private struct ElementDetailSheet: View {
    let element: ChemicalElement
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Symbol card
                    VStack(spacing: 8) {
                        Text(element.symbol)
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [element.category.color, element.category.color.opacity(0.6)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        Text(element.name)
                            .font(.title2.bold())
                        Text(element.category.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(element.category.color.opacity(0.2), in: .capsule)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                    // Properties grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        PropertyCard(icon: "number", label: "Atomic Number", value: "\(element.atomicNumber)")
                        PropertyCard(icon: "scalemass.fill", label: "Atomic Mass", value: element.atomicMass)
                        PropertyCard(icon: element.stateAtRoomTemp.icon, label: "State (Room Temp)", value: element.stateAtRoomTemp.rawValue)
                        PropertyCard(icon: "calendar", label: "Discovered", value: element.discoveryYear)
                    }

                    // Electron config
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Electron Configuration", systemImage: "circle.grid.cross.fill")
                            .font(.subheadline.bold())
                        Text(element.electronConfig)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 10))
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                    // Fun Fact
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Fun Fact", systemImage: "lightbulb.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text(element.funFact)
                            .font(.body)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle(element.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PropertyCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.indigo)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }
}

// MARK: - Quiz Sheet

private struct QuizSheet: View {
    let questions: [ElementQuizQuestion]
    @Binding var score: Int
    @Binding var questionIndex: Int
    @Binding var answered: Bool
    @Binding var correct: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: Int?

    var currentQuestion: ElementQuizQuestion? {
        guard questionIndex < questions.count else { return nil }
        return questions[questionIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let q = currentQuestion {
                    // Progress
                    HStack {
                        Text("Question \(questionIndex + 1) of \(questions.count)")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("Score: \(score)")
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                    }

                    ProgressView(value: Double(questionIndex), total: Double(questions.count))
                        .tint(.indigo)

                    // Question
                    Text(q.question)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                    // Options
                    VStack(spacing: 12) {
                        ForEach(q.options.indices, id: \.self) { i in
                            Button {
                                guard !answered else { return }
                                selectedOption = i
                                answered = true
                                correct = i == q.correctIndex
                                if correct { score += 1 }
                            } label: {
                                HStack {
                                    Text(q.options[i])
                                        .font(.body.bold())
                                    Spacer()
                                    if answered {
                                        if i == q.correctIndex {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        } else if i == selectedOption {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    answered ?
                                    (i == q.correctIndex ? Color.green.opacity(0.15) :
                                        i == selectedOption ? Color.red.opacity(0.15) : Color.clear) :
                                        Color.clear,
                                    in: .rect(cornerRadius: 12)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(answered && i == q.correctIndex ? .green : .secondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .foregroundStyle(.primary)
                        }
                    }

                    Spacer()

                    if answered {
                        Button {
                            questionIndex += 1
                            answered = false
                            selectedOption = nil
                        } label: {
                            Text(questionIndex + 1 < questions.count ? "Next Question" : "See Results")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundStyle(.white)
                                .background(
                                    LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing),
                                    in: .rect(cornerRadius: 14)
                                )
                        }
                        .hapticFeedback(.impact(flexibility: .soft), trigger: questionIndex)
                    }
                } else {
                    // Results
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: score > 7 ? "star.fill" : score > 4 ? "hand.thumbsup.fill" : "book.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
                            )
                        Text("Quiz Complete!")
                            .font(.title.bold())
                        Text("\(score) out of \(questions.count)")
                            .font(.title2)
                        Text(score > 7 ? "Excellent work!" : score > 4 ? "Good effort! Keep learning!" : "Keep practicing, you'll get better!")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                    Spacer()
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing),
                            in: .rect(cornerRadius: 14)
                        )
                }
            }
            .padding()
            .navigationTitle("Element Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PeriodicTableView()
    }
}
