import SwiftUI

// MARK: - Data Models

struct ProvinceData: Identifiable {
    let id = UUID()
    let name: String
    let abbreviation: String
    let capital: String
    let largestCity: String
    let population: String
    let area: String
    let region: CanadianRegion
    let interestingFact: String
    let majorLandmarks: [String]
    let mapPosition: CGPoint   // Approximate relative position on a simplified map
    let mapSize: CGSize        // Approximate relative size
}

enum CanadianRegion: String, CaseIterable {
    case atlantic = "Atlantic"
    case central = "Central"
    case prairies = "Prairies"
    case west = "West Coast"
    case north = "Northern"

    var color: Color {
        switch self {
        case .atlantic: return .blue
        case .central: return .green
        case .prairies: return Color.orange
        case .west: return .teal
        case .north: return Color(.systemGray4)
        }
    }

    var icon: String {
        switch self {
        case .atlantic: return "water.waves"
        case .central: return "leaf.fill"
        case .prairies: return "sun.max.fill"
        case .west: return "mountain.2.fill"
        case .north: return "snowflake"
        }
    }
}

enum CanadianGeographyQuizMode: String, CaseIterable {
    case nameProvince = "Name the Province"
    case findCapital = "Find the Capital"
    case landmarkMatch = "Landmark Match"

    var icon: String {
        switch self {
        case .nameProvince: return "map.fill"
        case .findCapital: return "building.columns.fill"
        case .landmarkMatch: return "mappin.and.ellipse"
        }
    }

    var description: String {
        switch self {
        case .nameProvince: return "Identify the highlighted province or territory"
        case .findCapital: return "Match provinces to their capital cities"
        case .landmarkMatch: return "Match famous landmarks to their locations"
        }
    }
}

struct GeographyQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let correctAnswer: String
    let options: [String]
    let highlightProvince: String?
}

// MARK: - Province Database

private let allProvinces: [ProvinceData] = [
    ProvinceData(
        name: "British Columbia", abbreviation: "BC",
        capital: "Victoria", largestCity: "Vancouver",
        population: "5.4 million", area: "944,735 km\u{00B2}",
        region: .west,
        interestingFact: "BC has more than 27,000 km of coastline, which is longer than the coastlines of most countries.",
        majorLandmarks: ["Stanley Park", "Butchart Gardens", "Whistler Blackcomb", "Pacific Rim National Park"],
        mapPosition: CGPoint(x: 0.08, y: 0.52), mapSize: CGSize(width: 0.13, height: 0.35)
    ),
    ProvinceData(
        name: "Alberta", abbreviation: "AB",
        capital: "Edmonton", largestCity: "Calgary",
        population: "4.6 million", area: "661,848 km\u{00B2}",
        region: .prairies,
        interestingFact: "Alberta is home to the Canadian Rockies and has the world's largest deposit of oil sands.",
        majorLandmarks: ["Banff National Park", "Lake Louise", "Columbia Icefield", "Dinosaur Provincial Park"],
        mapPosition: CGPoint(x: 0.19, y: 0.55), mapSize: CGSize(width: 0.10, height: 0.30)
    ),
    ProvinceData(
        name: "Saskatchewan", abbreviation: "SK",
        capital: "Regina", largestCity: "Saskatoon",
        population: "1.2 million", area: "651,036 km\u{00B2}",
        region: .prairies,
        interestingFact: "Saskatchewan has over 100,000 lakes, making up about one-eighth of the world's fresh water.",
        majorLandmarks: ["Wanuskewin Heritage Park", "RCMP Heritage Centre", "Prince Albert National Park", "Grasslands National Park"],
        mapPosition: CGPoint(x: 0.30, y: 0.55), mapSize: CGSize(width: 0.10, height: 0.30)
    ),
    ProvinceData(
        name: "Manitoba", abbreviation: "MB",
        capital: "Winnipeg", largestCity: "Winnipeg",
        population: "1.4 million", area: "647,797 km\u{00B2}",
        region: .prairies,
        interestingFact: "Churchill, Manitoba is known as the 'Polar Bear Capital of the World' where polar bears migrate each fall.",
        majorLandmarks: ["The Forks", "Churchill Polar Bears", "Riding Mountain National Park", "Manitoba Legislative Building"],
        mapPosition: CGPoint(x: 0.40, y: 0.55), mapSize: CGSize(width: 0.10, height: 0.30)
    ),
    ProvinceData(
        name: "Ontario", abbreviation: "ON",
        capital: "Toronto", largestCity: "Toronto",
        population: "15.3 million", area: "1,076,395 km\u{00B2}",
        region: .central,
        interestingFact: "Ontario is home to both Canada's capital (Ottawa) and its largest city (Toronto), and contains one-fifth of the world's fresh water.",
        majorLandmarks: ["CN Tower", "Niagara Falls", "Parliament Hill", "Algonquin Provincial Park"],
        mapPosition: CGPoint(x: 0.52, y: 0.62), mapSize: CGSize(width: 0.14, height: 0.28)
    ),
    ProvinceData(
        name: "Quebec", abbreviation: "QC",
        capital: "Quebec City", largestCity: "Montreal",
        population: "8.8 million", area: "1,542,056 km\u{00B2}",
        region: .central,
        interestingFact: "Quebec is the largest province by area and the only one with French as its sole official language.",
        majorLandmarks: ["Old Quebec City", "Mont Tremblant", "Montmorency Falls", "Basilica of Sainte-Anne-de-Beaupre"],
        mapPosition: CGPoint(x: 0.65, y: 0.48), mapSize: CGSize(width: 0.16, height: 0.32)
    ),
    ProvinceData(
        name: "New Brunswick", abbreviation: "NB",
        capital: "Fredericton", largestCity: "Saint John",
        population: "812,000", area: "72,908 km\u{00B2}",
        region: .atlantic,
        interestingFact: "New Brunswick is Canada's only officially bilingual province. The Bay of Fundy has the highest tides in the world.",
        majorLandmarks: ["Bay of Fundy", "Hopewell Rocks", "Fundy Trail Parkway", "Magnetic Hill"],
        mapPosition: CGPoint(x: 0.80, y: 0.72), mapSize: CGSize(width: 0.06, height: 0.08)
    ),
    ProvinceData(
        name: "Nova Scotia", abbreviation: "NS",
        capital: "Halifax", largestCity: "Halifax",
        population: "1.0 million", area: "55,284 km\u{00B2}",
        region: .atlantic,
        interestingFact: "Nova Scotia is almost completely surrounded by water and no point in the province is more than 67 km from the ocean.",
        majorLandmarks: ["Peggy's Cove Lighthouse", "Cabot Trail", "Halifax Citadel", "Lunenburg"],
        mapPosition: CGPoint(x: 0.86, y: 0.74), mapSize: CGSize(width: 0.06, height: 0.07)
    ),
    ProvinceData(
        name: "Prince Edward Island", abbreviation: "PE",
        capital: "Charlottetown", largestCity: "Charlottetown",
        population: "170,000", area: "5,660 km\u{00B2}",
        region: .atlantic,
        interestingFact: "PEI is Canada's smallest province and is known as the 'Birthplace of Confederation' because the first meeting was held there in 1864.",
        majorLandmarks: ["Confederation Bridge", "Green Gables Heritage Place", "Province House", "Cavendish Beach"],
        mapPosition: CGPoint(x: 0.87, y: 0.68), mapSize: CGSize(width: 0.04, height: 0.04)
    ),
    ProvinceData(
        name: "Newfoundland and Labrador", abbreviation: "NL",
        capital: "St. John's", largestCity: "St. John's",
        population: "533,000", area: "405,212 km\u{00B2}",
        region: .atlantic,
        interestingFact: "St. John's is the oldest city in North America, and Signal Hill received the first transatlantic wireless signal in 1901.",
        majorLandmarks: ["Signal Hill", "Gros Morne National Park", "L'Anse aux Meadows", "Cape Spear"],
        mapPosition: CGPoint(x: 0.88, y: 0.50), mapSize: CGSize(width: 0.10, height: 0.18)
    ),
    ProvinceData(
        name: "Yukon", abbreviation: "YT",
        capital: "Whitehorse", largestCity: "Whitehorse",
        population: "43,000", area: "482,443 km\u{00B2}",
        region: .north,
        interestingFact: "The Yukon is home to Mount Logan (5,959 m), Canada's tallest mountain and the second-highest peak in North America.",
        majorLandmarks: ["Kluane National Park", "Mount Logan", "Dawson City", "Northern Lights Centre"],
        mapPosition: CGPoint(x: 0.05, y: 0.18), mapSize: CGSize(width: 0.12, height: 0.25)
    ),
    ProvinceData(
        name: "Northwest Territories", abbreviation: "NT",
        capital: "Yellowknife", largestCity: "Yellowknife",
        population: "45,000", area: "1,346,106 km\u{00B2}",
        region: .north,
        interestingFact: "Yellowknife is one of the best places in the world to see the Northern Lights, visible about 240 nights per year.",
        majorLandmarks: ["Nahanni National Park", "Great Slave Lake", "Virginia Falls", "Wood Buffalo National Park"],
        mapPosition: CGPoint(x: 0.20, y: 0.15), mapSize: CGSize(width: 0.18, height: 0.30)
    ),
    ProvinceData(
        name: "Nunavut", abbreviation: "NU",
        capital: "Iqaluit", largestCity: "Iqaluit",
        population: "40,000", area: "2,093,190 km\u{00B2}",
        region: .north,
        interestingFact: "Nunavut is Canada's newest and largest territory, created in 1999. It means 'our land' in Inuktitut.",
        majorLandmarks: ["Auyuittuq National Park", "Sirmilik National Park", "Quttinirpaaq National Park", "Baffin Island"],
        mapPosition: CGPoint(x: 0.42, y: 0.08), mapSize: CGSize(width: 0.30, height: 0.35)
    )
]

// MARK: - Main View

struct CanadianGeographyView: View {
    @State private var selectedTab: Int = 0
    @State private var selectedProvince: ProvinceData?
    @State private var showProvinceDetail = false

    // Quiz state
    @State private var quizMode: CanadianGeographyQuizMode = .nameProvince
    @State private var showQuiz = false
    @State private var currentQuestionIndex = 0
    @State private var quizQuestions: [GeographyQuestion] = []
    @State private var selectedAnswer: String?
    @State private var isAnswerRevealed = false
    @State private var score = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var totalAnswered = 0
    @State private var highlightedProvinceName: String?
    @State private var showQuizComplete = false
    @State private var animateScore = false

    private let tabs = ["Map", "Quiz", "Facts"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabSelector
                TabView(selection: $selectedTab) {
                    mapExploreTab.tag(0)
                    quizTab.tag(1)
                    factsTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Canadian Geography")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showProvinceDetail) {
                if let province = selectedProvince {
                    provinceDetailSheet(province)
                }
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                } label: {
                    Text(title)
                        .font(.subheadline.weight(selectedTab == index ? .bold : .medium))
                        .foregroundStyle(selectedTab == index ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selectedTab == index {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.red, .red.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                }
                .hapticFeedback(.selection, trigger: selectedTab)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Map Explore Tab

    private var mapExploreTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                mapHeader
                canadaMapView
                regionLegend
                provincesListSection
            }
            .padding(.bottom, 40)
        }
    }

    private var mapHeader: some View {
        VStack(spacing: 6) {
            Text("Explore Canada's Provinces & Territories")
                .font(.headline)
            Text("Tap any region to learn more")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var canadaMapView: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.width * 0.65
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                ForEach(allProvinces) { province in
                    let x = province.mapPosition.x * width
                    let y = province.mapPosition.y * height
                    let w = province.mapSize.width * width
                    let h = province.mapSize.height * height

                    Button {
                        selectedProvince = province
                        showProvinceDetail = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    highlightedProvinceName == province.name
                                    ? province.region.color.opacity(0.9)
                                    : province.region.color.opacity(0.5)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            highlightedProvinceName == province.name ? .white : province.region.color,
                                            lineWidth: highlightedProvinceName == province.name ? 3 : 1
                                        )
                                )
                                .shadow(
                                    color: highlightedProvinceName == province.name ? province.region.color.opacity(0.6) : .clear,
                                    radius: 6
                                )

                            Text(province.abbreviation)
                                .font(.system(size: min(w, h) * 0.28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                        }
                    }
                    .frame(width: max(w, 24), height: max(h, 18))
                    .position(x: x + w / 2, y: y + h / 2)
                    .hapticFeedback(.impact(flexibility: .soft), trigger: showProvinceDetail)
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(1 / 0.65, contentMode: .fit)
        .padding(.horizontal, 16)
    }

    private var regionLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CanadianRegion.allCases, id: \.rawValue) { region in
                    HStack(spacing: 6) {
                        Image(systemName: region.icon)
                            .font(.caption2)
                        Circle()
                            .fill(region.color)
                            .frame(width: 10, height: 10)
                        Text(region.rawValue)
                            .font(.caption2.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var provincesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Provinces & Territories")
                .font(.title3.bold())
                .padding(.horizontal, 20)

            ForEach(CanadianRegion.allCases, id: \.rawValue) { region in
                let regionProvinces = allProvinces.filter { $0.region == region }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: region.icon)
                            .foregroundStyle(region.color)
                        Text(region.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(region.color)
                    }
                    .padding(.horizontal, 20)

                    ForEach(regionProvinces) { province in
                        Button {
                            selectedProvince = province
                            showProvinceDetail = true
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(province.region.color.gradient)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(province.abbreviation)
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(province.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Capital: \(province.capital)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Province Detail Sheet

    private func provinceDetailSheet(_ province: ProvinceData) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(province.region.color.gradient)
                            .frame(height: 100)
                            .overlay(
                                VStack(spacing: 4) {
                                    Text(province.abbreviation)
                                        .font(.largeTitle.bold())
                                        .foregroundStyle(.white)
                                    Text(province.region.rawValue)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            )

                        Text(province.name)
                            .font(.title.bold())
                    }

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statCard(icon: "building.columns.fill", label: "Capital", value: province.capital)
                        statCard(icon: "building.2.fill", label: "Largest City", value: province.largestCity)
                        statCard(icon: "person.3.fill", label: "Population", value: province.population)
                        statCard(icon: "square.dashed", label: "Area", value: province.area)
                    }

                    // Interesting fact
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Did You Know?", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)

                        Text(province.interestingFact)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Landmarks
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Major Landmarks", systemImage: "mappin.and.ellipse")
                            .font(.headline)

                        ForEach(province.majorLandmarks, id: \.self) { landmark in
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(province.region.color)
                                Text(landmark)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(province.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showProvinceDetail = false }
                }
            }
        }
    }

    private func statCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.red)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quiz Tab

    private var quizTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !showQuiz {
                    quizModeSelector
                } else if showQuizComplete {
                    quizCompleteView
                } else {
                    quizActiveView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    private var quizModeSelector: some View {
        VStack(spacing: 20) {
            // Score summary
            HStack(spacing: 20) {
                quizStatBadge(icon: "checkmark.circle.fill", label: "Score", value: "\(score)", color: .green)
                quizStatBadge(icon: "flame.fill", label: "Streak", value: "\(streak)", color: .orange)
                quizStatBadge(icon: "trophy.fill", label: "Best", value: "\(bestStreak)", color: .yellow)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("Choose a Quiz Mode")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(CanadianGeographyQuizMode.allCases, id: \.rawValue) { mode in
                Button {
                    quizMode = mode
                    startQuiz()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: mode.icon)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.rawValue)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .hapticFeedback(.impact(flexibility: .soft), trigger: showQuiz)
            }
        }
    }

    private func quizStatBadge(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var quizActiveView: some View {
        VStack(spacing: 16) {
            // Progress
            HStack {
                Text("Question \(currentQuestionIndex + 1) of \(quizQuestions.count)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak)")
                        .font(.subheadline.bold().monospacedDigit())
                }
            }

            ProgressView(value: Double(currentQuestionIndex + 1), total: Double(quizQuestions.count))
                .tint(.red)

            if currentQuestionIndex < quizQuestions.count {
                let question = quizQuestions[currentQuestionIndex]

                // Map highlight for province questions
                if let highlight = question.highlightProvince {
                    miniMapHighlight(provinceName: highlight)
                }

                // Question card
                VStack(spacing: 8) {
                    Image(systemName: quizMode.icon)
                        .font(.title)
                        .foregroundStyle(.red)
                    Text(question.prompt)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Options
                ForEach(question.options, id: \.self) { option in
                    Button {
                        guard !isAnswerRevealed else { return }
                        selectedAnswer = option
                        isAnswerRevealed = true
                        if option == question.correctAnswer {
                            score += 1
                            streak += 1
                            bestStreak = max(bestStreak, streak)
                        } else {
                            streak = 0
                        }
                        totalAnswered += 1
                    } label: {
                        HStack {
                            Text(option)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(optionTextColor(option: option, correct: question.correctAnswer))
                            Spacer()
                            if isAnswerRevealed {
                                if option == question.correctAnswer {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if option == selectedAnswer {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .background(optionBackground(option: option, correct: question.correctAnswer), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(optionBorder(option: option, correct: question.correctAnswer), lineWidth: 2)
                        )
                    }
                    .hapticFeedback(.impact(flexibility: .rigid), trigger: isAnswerRevealed)
                }

                // Next button
                if isAnswerRevealed {
                    Button {
                        nextQuestion()
                    } label: {
                        Text(currentQuestionIndex < quizQuestions.count - 1 ? "Next Question" : "See Results")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                    .hapticFeedback(.impact(flexibility: .soft), trigger: currentQuestionIndex)
                }
            }
        }
    }

    private func miniMapHighlight(provinceName: String) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.width * 0.45
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground).opacity(0.4))

                ForEach(allProvinces) { province in
                    let x = province.mapPosition.x * width
                    let y = province.mapPosition.y * height
                    let w = province.mapSize.width * width
                    let h = province.mapSize.height * height

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            province.name == provinceName
                            ? province.region.color.opacity(0.9)
                            : Color.secondary.opacity(0.15)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    province.name == provinceName ? .white : .clear,
                                    lineWidth: province.name == provinceName ? 3 : 0
                                )
                        )
                        .frame(width: max(w, 16), height: max(h, 12))
                        .position(x: x + w / 2, y: y + h / 2)
                        .shadow(
                            color: province.name == provinceName ? province.region.color.opacity(0.6) : .clear,
                            radius: 8
                        )
                }

                // Question mark over highlighted
                if let province = allProvinces.first(where: { $0.name == provinceName }) {
                    let x = province.mapPosition.x * width + province.mapSize.width * width / 2
                    let y = province.mapPosition.y * height + province.mapSize.height * height / 2
                    Text("?")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .position(x: x, y: y)
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(1 / 0.45, contentMode: .fit)
    }

    private func optionTextColor(option: String, correct: String) -> Color {
        guard isAnswerRevealed else { return .primary }
        if option == correct { return .green }
        if option == selectedAnswer { return .red }
        return .secondary
    }

    private func optionBackground(option: String, correct: String) -> some ShapeStyle {
        guard isAnswerRevealed else { return AnyShapeStyle(.ultraThinMaterial) }
        if option == correct { return AnyShapeStyle(Color.green.opacity(0.1)) }
        if option == selectedAnswer { return AnyShapeStyle(Color.red.opacity(0.1)) }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private func optionBorder(option: String, correct: String) -> Color {
        guard isAnswerRevealed else { return .clear }
        if option == correct { return .green }
        if option == selectedAnswer { return .red }
        return .clear
    }

    private var quizCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: score >= quizQuestions.count / 2 ? "star.fill" : "arrow.counterclockwise")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: score >= quizQuestions.count / 2 ? [.yellow, .orange] : [.red, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(animateScore ? 1.0 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateScore)

            Text(score >= quizQuestions.count * 8 / 10 ? "Outstanding!" :
                 score >= quizQuestions.count / 2 ? "Great Work!" : "Keep Practicing!")
                .font(.title.bold())

            Text("\(score) out of \(quizQuestions.count) correct")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Stats
            HStack(spacing: 20) {
                quizStatBadge(icon: "checkmark.circle.fill", label: "Correct", value: "\(score)", color: .green)
                quizStatBadge(icon: "xmark.circle.fill", label: "Missed", value: "\(quizQuestions.count - score)", color: .red)
                quizStatBadge(icon: "flame.fill", label: "Best Streak", value: "\(bestStreak)", color: .orange)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Percentage bar
            let percentage = quizQuestions.isEmpty ? 0.0 : Double(score) / Double(quizQuestions.count)
            VStack(spacing: 8) {
                Text("\(Int(percentage * 100))%")
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(percentage >= 0.8 ? .green : percentage >= 0.5 ? .orange : .red)
                ProgressView(value: percentage)
                    .tint(percentage >= 0.8 ? .green : percentage >= 0.5 ? .orange : .red)
                    .scaleEffect(y: 2)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Button {
                resetQuiz()
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }

            Button {
                showQuiz = false
                showQuizComplete = false
            } label: {
                Text("Back to Quiz Modes")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(.top, 20)
        .onAppear { animateScore = true }
    }

    // MARK: - Facts Tab

    private var factsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                factsHeader

                VStack(spacing: 12) {
                    factCard(
                        icon: "globe.americas.fill",
                        title: "Second Largest Country",
                        fact: "Canada is the second largest country in the world by total area (9.98 million km\u{00B2}), after Russia.",
                        color: .red
                    )
                    factCard(
                        icon: "water.waves",
                        title: "Most Lakes in the World",
                        fact: "Canada has more lakes than all other countries combined, with over 31,700 lakes larger than 3 km\u{00B2}.",
                        color: .blue
                    )
                    factCard(
                        icon: "thermometer.snowflake",
                        title: "Longest Coastline",
                        fact: "At 243,042 km, Canada has the longest coastline of any country in the world, touching the Atlantic, Pacific, and Arctic oceans.",
                        color: .teal
                    )
                    factCard(
                        icon: "mountain.2.fill",
                        title: "Rocky Mountains",
                        fact: "The Canadian Rockies stretch over 1,200 km from British Columbia to Alberta and include some of North America's highest peaks.",
                        color: .brown
                    )
                    factCard(
                        icon: "drop.fill",
                        title: "Niagara Falls",
                        fact: "Niagara Falls, on the Ontario-New York border, is one of the most powerful waterfalls in North America by flow rate.",
                        color: .cyan
                    )
                    factCard(
                        icon: "leaf.fill",
                        title: "National Parks",
                        fact: "Canada has 48 national parks and national park reserves, protecting over 340,000 km\u{00B2} of land and water.",
                        color: .green
                    )
                    factCard(
                        icon: "snowflake",
                        title: "The Canadian Shield",
                        fact: "The Canadian Shield is one of the oldest geological formations on Earth, covering about half of Canada's landmass with rock that is over 4 billion years old.",
                        color: .purple
                    )
                    factCard(
                        icon: "tree.fill",
                        title: "Boreal Forest",
                        fact: "Canada's boreal forest is one of the largest intact forest ecosystems remaining on Earth, making up about 30% of the world's boreal forest.",
                        color: .green.opacity(0.8)
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
    }

    private var factsHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundStyle(.yellow)
            Text("Amazing Canadian Geography Facts")
                .font(.title3.bold())
            Text("Discover what makes Canada's landscape so unique")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [.red.opacity(0.15), .red.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func factCard(icon: String, title: String, fact: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(fact)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quiz Logic

    private func startQuiz() {
        var questions: [GeographyQuestion] = []
        let shuffledProvinces = allProvinces.shuffled()

        switch quizMode {
        case .nameProvince:
            for province in shuffledProvinces.prefix(10) {
                let otherNames = allProvinces.filter { $0.name != province.name }.shuffled().prefix(3).map(\.name)
                let options = ([province.name] + otherNames).shuffled()
                questions.append(GeographyQuestion(
                    prompt: "Which province or territory is highlighted on the map?",
                    correctAnswer: province.name,
                    options: options,
                    highlightProvince: province.name
                ))
            }

        case .findCapital:
            for province in shuffledProvinces.prefix(10) {
                let otherCapitals = allProvinces.filter { $0.capital != province.capital }.shuffled().prefix(3).map(\.capital)
                let options = ([province.capital] + otherCapitals).shuffled()
                questions.append(GeographyQuestion(
                    prompt: "What is the capital of \(province.name)?",
                    correctAnswer: province.capital,
                    options: options,
                    highlightProvince: province.name
                ))
            }

        case .landmarkMatch:
            let provincesWithLandmarks = shuffledProvinces.filter { !$0.majorLandmarks.isEmpty }
            for province in provincesWithLandmarks.prefix(10) {
                let landmark = province.majorLandmarks.randomElement() ?? province.majorLandmarks[0]
                let otherProvinces = allProvinces.filter { $0.name != province.name }.shuffled().prefix(3).map(\.name)
                let options = ([province.name] + otherProvinces).shuffled()
                questions.append(GeographyQuestion(
                    prompt: "Where is \(landmark) located?",
                    correctAnswer: province.name,
                    options: options,
                    highlightProvince: nil
                ))
            }
        }

        quizQuestions = questions
        currentQuestionIndex = 0
        selectedAnswer = nil
        isAnswerRevealed = false
        score = 0
        streak = 0
        totalAnswered = 0
        showQuizComplete = false
        animateScore = false
        showQuiz = true
    }

    private func nextQuestion() {
        if currentQuestionIndex < quizQuestions.count - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            isAnswerRevealed = false
        } else {
            showQuizComplete = true
        }
    }

    private func resetQuiz() {
        showQuizComplete = false
        animateScore = false
        startQuiz()
    }
}

// MARK: - Preview

#Preview {
    CanadianGeographyView()
}
