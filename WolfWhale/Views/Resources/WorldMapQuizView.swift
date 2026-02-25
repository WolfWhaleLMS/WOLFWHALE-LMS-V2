import SwiftUI

// MARK: - Data Models

struct CountryInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let capital: String
    let flag: String
    let continent: Continent
    let population: String
    let languages: [String]
    let difficulty: Int // 1 = easy, 2 = medium, 3 = hard

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: CountryInfo, rhs: CountryInfo) -> Bool {
        lhs.name == rhs.name
    }
}

enum Continent: String, CaseIterable, Identifiable {
    case northAmerica = "North America"
    case southAmerica = "South America"
    case europe = "Europe"
    case asia = "Asia"
    case africa = "Africa"
    case oceania = "Oceania"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .northAmerica: "globe.americas.fill"
        case .southAmerica: "globe.americas.fill"
        case .europe: "globe.europe.africa.fill"
        case .asia: "globe.asia.australia.fill"
        case .africa: "globe.europe.africa.fill"
        case .oceania: "globe.asia.australia.fill"
        }
    }

    var color: Color {
        switch self {
        case .northAmerica: .blue
        case .southAmerica: .green
        case .europe: .purple
        case .asia: .red
        case .africa: .orange
        case .oceania: .cyan
        }
    }

    var gradient: [Color] {
        switch self {
        case .northAmerica: [.blue, .cyan]
        case .southAmerica: [.green, .mint]
        case .europe: [.purple, .indigo]
        case .asia: [.red, .orange]
        case .africa: [.orange, .yellow]
        case .oceania: [.cyan, .teal]
        }
    }
}

enum WorldGeographyQuizMode: String, CaseIterable, Identifiable {
    case nameTheCountry = "Name the Country"
    case capitalMatch = "Capital Match"
    case flagQuiz = "Flag Quiz"
    case continentSort = "Continent Sort"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nameTheCountry: "flag.fill"
        case .capitalMatch: "building.columns.fill"
        case .flagQuiz: "flag.2.crossed.fill"
        case .continentSort: "globe.desk.fill"
        }
    }

    var description: String {
        switch self {
        case .nameTheCountry: "Given a flag, pick the country"
        case .capitalMatch: "Given a country, pick the capital"
        case .flagQuiz: "Given a country name, pick the flag"
        case .continentSort: "Sort countries into continents"
        }
    }
}

// MARK: - Country Database

private let allCountries: [CountryInfo] = [
    // North America
    CountryInfo(name: "Canada", capital: "Ottawa", flag: "\u{1F1E8}\u{1F1E6}", continent: .northAmerica, population: "40.1 million", languages: ["English", "French"], difficulty: 1),
    CountryInfo(name: "United States", capital: "Washington, D.C.", flag: "\u{1F1FA}\u{1F1F8}", continent: .northAmerica, population: "334 million", languages: ["English"], difficulty: 1),
    CountryInfo(name: "Mexico", capital: "Mexico City", flag: "\u{1F1F2}\u{1F1FD}", continent: .northAmerica, population: "130 million", languages: ["Spanish"], difficulty: 1),
    CountryInfo(name: "Cuba", capital: "Havana", flag: "\u{1F1E8}\u{1F1FA}", continent: .northAmerica, population: "11.2 million", languages: ["Spanish"], difficulty: 2),
    CountryInfo(name: "Jamaica", capital: "Kingston", flag: "\u{1F1EF}\u{1F1F2}", continent: .northAmerica, population: "2.8 million", languages: ["English"], difficulty: 2),
    CountryInfo(name: "Costa Rica", capital: "San Jose", flag: "\u{1F1E8}\u{1F1F7}", continent: .northAmerica, population: "5.2 million", languages: ["Spanish"], difficulty: 2),
    CountryInfo(name: "Panama", capital: "Panama City", flag: "\u{1F1F5}\u{1F1E6}", continent: .northAmerica, population: "4.4 million", languages: ["Spanish"], difficulty: 2),
    CountryInfo(name: "Trinidad and Tobago", capital: "Port of Spain", flag: "\u{1F1F9}\u{1F1F9}", continent: .northAmerica, population: "1.4 million", languages: ["English"], difficulty: 3),
    CountryInfo(name: "Barbados", capital: "Bridgetown", flag: "\u{1F1E7}\u{1F1E7}", continent: .northAmerica, population: "288,000", languages: ["English"], difficulty: 3),
    CountryInfo(name: "Guatemala", capital: "Guatemala City", flag: "\u{1F1EC}\u{1F1F9}", continent: .northAmerica, population: "17.6 million", languages: ["Spanish"], difficulty: 3),

    // South America
    CountryInfo(name: "Brazil", capital: "Brasilia", flag: "\u{1F1E7}\u{1F1F7}", continent: .southAmerica, population: "216 million", languages: ["Portuguese"], difficulty: 1),
    CountryInfo(name: "Argentina", capital: "Buenos Aires", flag: "\u{1F1E6}\u{1F1F7}", continent: .southAmerica, population: "46 million", languages: ["Spanish"], difficulty: 1),
    CountryInfo(name: "Colombia", capital: "Bogota", flag: "\u{1F1E8}\u{1F1F4}", continent: .southAmerica, population: "52 million", languages: ["Spanish"], difficulty: 2),
    CountryInfo(name: "Chile", capital: "Santiago", flag: "\u{1F1E8}\u{1F1F1}", continent: .southAmerica, population: "19.5 million", languages: ["Spanish"], difficulty: 2),
    CountryInfo(name: "Peru", capital: "Lima", flag: "\u{1F1F5}\u{1F1EA}", continent: .southAmerica, population: "34 million", languages: ["Spanish", "Quechua"], difficulty: 2),
    CountryInfo(name: "Venezuela", capital: "Caracas", flag: "\u{1F1FB}\u{1F1EA}", continent: .southAmerica, population: "28.4 million", languages: ["Spanish"], difficulty: 2),
    CountryInfo(name: "Ecuador", capital: "Quito", flag: "\u{1F1EA}\u{1F1E8}", continent: .southAmerica, population: "18 million", languages: ["Spanish"], difficulty: 3),
    CountryInfo(name: "Uruguay", capital: "Montevideo", flag: "\u{1F1FA}\u{1F1FE}", continent: .southAmerica, population: "3.4 million", languages: ["Spanish"], difficulty: 3),

    // Europe
    CountryInfo(name: "United Kingdom", capital: "London", flag: "\u{1F1EC}\u{1F1E7}", continent: .europe, population: "67.7 million", languages: ["English"], difficulty: 1),
    CountryInfo(name: "France", capital: "Paris", flag: "\u{1F1EB}\u{1F1F7}", continent: .europe, population: "68 million", languages: ["French"], difficulty: 1),
    CountryInfo(name: "Germany", capital: "Berlin", flag: "\u{1F1E9}\u{1F1EA}", continent: .europe, population: "84 million", languages: ["German"], difficulty: 1),
    CountryInfo(name: "Italy", capital: "Rome", flag: "\u{1F1EE}\u{1F1F9}", continent: .europe, population: "59 million", languages: ["Italian"], difficulty: 1),
    CountryInfo(name: "Spain", capital: "Madrid", flag: "\u{1F1EA}\u{1F1F8}", continent: .europe, population: "47.4 million", languages: ["Spanish"], difficulty: 1),
    CountryInfo(name: "Netherlands", capital: "Amsterdam", flag: "\u{1F1F3}\u{1F1F1}", continent: .europe, population: "17.6 million", languages: ["Dutch"], difficulty: 2),
    CountryInfo(name: "Sweden", capital: "Stockholm", flag: "\u{1F1F8}\u{1F1EA}", continent: .europe, population: "10.5 million", languages: ["Swedish"], difficulty: 2),
    CountryInfo(name: "Poland", capital: "Warsaw", flag: "\u{1F1F5}\u{1F1F1}", continent: .europe, population: "37.8 million", languages: ["Polish"], difficulty: 2),
    CountryInfo(name: "Switzerland", capital: "Bern", flag: "\u{1F1E8}\u{1F1ED}", continent: .europe, population: "8.8 million", languages: ["German", "French", "Italian", "Romansh"], difficulty: 2),
    CountryInfo(name: "Norway", capital: "Oslo", flag: "\u{1F1F3}\u{1F1F4}", continent: .europe, population: "5.5 million", languages: ["Norwegian"], difficulty: 2),
    CountryInfo(name: "Portugal", capital: "Lisbon", flag: "\u{1F1F5}\u{1F1F9}", continent: .europe, population: "10.3 million", languages: ["Portuguese"], difficulty: 2),
    CountryInfo(name: "Greece", capital: "Athens", flag: "\u{1F1EC}\u{1F1F7}", continent: .europe, population: "10.4 million", languages: ["Greek"], difficulty: 2),
    CountryInfo(name: "Ireland", capital: "Dublin", flag: "\u{1F1EE}\u{1F1EA}", continent: .europe, population: "5.1 million", languages: ["English", "Irish"], difficulty: 2),
    CountryInfo(name: "Czech Republic", capital: "Prague", flag: "\u{1F1E8}\u{1F1FF}", continent: .europe, population: "10.8 million", languages: ["Czech"], difficulty: 3),
    CountryInfo(name: "Romania", capital: "Bucharest", flag: "\u{1F1F7}\u{1F1F4}", continent: .europe, population: "19 million", languages: ["Romanian"], difficulty: 3),

    // Asia
    CountryInfo(name: "Japan", capital: "Tokyo", flag: "\u{1F1EF}\u{1F1F5}", continent: .asia, population: "125 million", languages: ["Japanese"], difficulty: 1),
    CountryInfo(name: "China", capital: "Beijing", flag: "\u{1F1E8}\u{1F1F3}", continent: .asia, population: "1.43 billion", languages: ["Mandarin"], difficulty: 1),
    CountryInfo(name: "India", capital: "New Delhi", flag: "\u{1F1EE}\u{1F1F3}", continent: .asia, population: "1.44 billion", languages: ["Hindi", "English"], difficulty: 1),
    CountryInfo(name: "South Korea", capital: "Seoul", flag: "\u{1F1F0}\u{1F1F7}", continent: .asia, population: "51.7 million", languages: ["Korean"], difficulty: 1),
    CountryInfo(name: "Saudi Arabia", capital: "Riyadh", flag: "\u{1F1F8}\u{1F1E6}", continent: .asia, population: "36.4 million", languages: ["Arabic"], difficulty: 2),
    CountryInfo(name: "Indonesia", capital: "Jakarta", flag: "\u{1F1EE}\u{1F1E9}", continent: .asia, population: "277 million", languages: ["Indonesian"], difficulty: 2),
    CountryInfo(name: "Turkey", capital: "Ankara", flag: "\u{1F1F9}\u{1F1F7}", continent: .asia, population: "85.3 million", languages: ["Turkish"], difficulty: 2),
    CountryInfo(name: "Thailand", capital: "Bangkok", flag: "\u{1F1F9}\u{1F1ED}", continent: .asia, population: "72 million", languages: ["Thai"], difficulty: 2),
    CountryInfo(name: "Vietnam", capital: "Hanoi", flag: "\u{1F1FB}\u{1F1F3}", continent: .asia, population: "99 million", languages: ["Vietnamese"], difficulty: 2),
    CountryInfo(name: "Pakistan", capital: "Islamabad", flag: "\u{1F1F5}\u{1F1F0}", continent: .asia, population: "230 million", languages: ["Urdu", "English"], difficulty: 2),
    CountryInfo(name: "Philippines", capital: "Manila", flag: "\u{1F1F5}\u{1F1ED}", continent: .asia, population: "115 million", languages: ["Filipino", "English"], difficulty: 2),
    CountryInfo(name: "Malaysia", capital: "Kuala Lumpur", flag: "\u{1F1F2}\u{1F1FE}", continent: .asia, population: "33 million", languages: ["Malay"], difficulty: 3),
    CountryInfo(name: "Singapore", capital: "Singapore", flag: "\u{1F1F8}\u{1F1EC}", continent: .asia, population: "5.9 million", languages: ["English", "Malay", "Mandarin", "Tamil"], difficulty: 3),

    // Africa
    CountryInfo(name: "South Africa", capital: "Pretoria", flag: "\u{1F1FF}\u{1F1E6}", continent: .africa, population: "60 million", languages: ["Zulu", "Xhosa", "Afrikaans", "English"], difficulty: 1),
    CountryInfo(name: "Nigeria", capital: "Abuja", flag: "\u{1F1F3}\u{1F1EC}", continent: .africa, population: "224 million", languages: ["English"], difficulty: 2),
    CountryInfo(name: "Egypt", capital: "Cairo", flag: "\u{1F1EA}\u{1F1EC}", continent: .africa, population: "111 million", languages: ["Arabic"], difficulty: 1),
    CountryInfo(name: "Kenya", capital: "Nairobi", flag: "\u{1F1F0}\u{1F1EA}", continent: .africa, population: "54 million", languages: ["English", "Swahili"], difficulty: 2),
    CountryInfo(name: "Morocco", capital: "Rabat", flag: "\u{1F1F2}\u{1F1E6}", continent: .africa, population: "37.5 million", languages: ["Arabic", "Berber"], difficulty: 2),
    CountryInfo(name: "Ghana", capital: "Accra", flag: "\u{1F1EC}\u{1F1ED}", continent: .africa, population: "33 million", languages: ["English"], difficulty: 2),
    CountryInfo(name: "Ethiopia", capital: "Addis Ababa", flag: "\u{1F1EA}\u{1F1F9}", continent: .africa, population: "126 million", languages: ["Amharic"], difficulty: 3),
    CountryInfo(name: "Tanzania", capital: "Dodoma", flag: "\u{1F1F9}\u{1F1FF}", continent: .africa, population: "65 million", languages: ["Swahili", "English"], difficulty: 3),

    // Oceania
    CountryInfo(name: "Australia", capital: "Canberra", flag: "\u{1F1E6}\u{1F1FA}", continent: .oceania, population: "26.4 million", languages: ["English"], difficulty: 1),
    CountryInfo(name: "New Zealand", capital: "Wellington", flag: "\u{1F1F3}\u{1F1FF}", continent: .oceania, population: "5.2 million", languages: ["English", "Maori"], difficulty: 1),
    CountryInfo(name: "Papua New Guinea", capital: "Port Moresby", flag: "\u{1F1F5}\u{1F1EC}", continent: .oceania, population: "10 million", languages: ["English", "Tok Pisin", "Hiri Motu"], difficulty: 3),
    CountryInfo(name: "Fiji", capital: "Suva", flag: "\u{1F1EB}\u{1F1EF}", continent: .oceania, population: "930,000", languages: ["English", "Fijian", "Hindi"], difficulty: 3),
]

// MARK: - Main View

struct WorldMapQuizView: View {
    @State private var selectedTab: WorldGeoTab = .explore
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                TabView(selection: $selectedTab) {
                    ExploreCountriesSection()
                        .tag(WorldGeoTab.explore)
                    GeographyQuizSection()
                        .tag(WorldGeoTab.quiz)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("World Geography")
            .navigationBarTitleDisplayMode(.large)
            .sensoryFeedback(.selection, trigger: selectedTab)
        }
    }

    private var tabPicker: some View {
        Picker("Section", selection: $selectedTab) {
            ForEach(WorldGeoTab.allCases) { tab in
                Label(tab.rawValue, systemImage: tab.icon).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
}

enum WorldGeoTab: String, CaseIterable, Identifiable {
    case explore = "Explore"
    case quiz = "Quiz"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .explore: "globe.desk"
        case .quiz: "questionmark.circle"
        }
    }
}

// MARK: - Explore Countries Section

private struct ExploreCountriesSection: View {
    @State private var selectedContinent: Continent? = nil
    @State private var searchText = ""
    @State private var expandedCountry: UUID? = nil

    private var filteredCountries: [CountryInfo] {
        var countries = allCountries
        if let continent = selectedContinent {
            countries = countries.filter { $0.continent == continent }
        }
        if !searchText.isEmpty {
            countries = countries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.capital.localizedCaseInsensitiveContains(searchText)
            }
        }
        return countries.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                searchBar
                continentFilter
                statsBar

                LazyVStack(spacing: 10) {
                    ForEach(filteredCountries) { country in
                        CountryCard(
                            country: country,
                            isExpanded: expandedCountry == country.id,
                            onTap: {
                                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                                    expandedCountry = expandedCountry == country.id ? nil : country.id
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search countries or capitals...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private var continentFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                continentChip(label: "All", continent: nil, icon: "globe", color: .gray)
                ForEach(Continent.allCases) { continent in
                    continentChip(
                        label: continent.rawValue,
                        continent: continent,
                        icon: continent.icon,
                        color: continent.color
                    )
                }
            }
        }
    }

    private func continentChip(label: String, continent: Continent?, icon: String, color: Color) -> some View {
        let isSelected = selectedContinent == continent
        return Button {
            withAnimation(.snappy) { selectedContinent = continent }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? AnyShapeStyle(color.opacity(0.2)) : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            statPill(value: "\(filteredCountries.count)", label: "Countries", icon: "flag.fill", color: .blue)
            Spacer()
            statPill(value: "\(Set(filteredCountries.map { $0.continent }).count)", label: "Continents", icon: "globe.desk.fill", color: .green)
            Spacer()
            statPill(
                value: "\(Set(filteredCountries.flatMap { $0.languages }).count)",
                label: "Languages",
                icon: "text.bubble.fill",
                color: .purple
            )
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    }

    private func statPill(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Country Card

private struct CountryCard: View {
    let country: CountryInfo
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 14) {
                Text(country.flag)
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 3) {
                    Text(country.name)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption2)
                            .foregroundStyle(country.continent.color)
                        Text(country.capital)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(country.continent.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(country.continent.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(country.continent.color.opacity(0.12), in: Capsule())
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    detailRow(icon: "person.3.fill", label: "Population", value: country.population, color: .blue)
                    detailRow(icon: "text.bubble.fill", label: "Languages", value: country.languages.joined(separator: ", "), color: .purple)
                    detailRow(icon: "globe.desk.fill", label: "Continent", value: country.continent.rawValue, color: country.continent.color)

                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Difficulty:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < country.difficulty ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(country.continent.color.opacity(isExpanded ? 0.3 : 0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(country.flag) \(country.name), capital \(country.capital), \(country.continent.rawValue)")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to see details")
    }

    private func detailRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
        }
    }
}

// MARK: - Geography Quiz Section

private struct GeographyQuizSection: View {
    @State private var selectedMode: WorldGeographyQuizMode? = nil
    @State private var quizDifficulty: Int = 1
    @State private var score = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var totalAnswered = 0
    @State private var currentQuestionIndex = 0
    @State private var quizQuestions: [GeoQuizQuestion] = []
    @State private var selectedAnswer: String? = nil
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var continentSortItems: [CountryInfo] = []
    @State private var continentSortAnswers: [String: Continent] = [:]
    @State private var continentSortChecked = false
    @State private var hapticTrigger = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreBoard

                if let mode = selectedMode {
                    quizHeader(mode: mode)

                    if mode == .continentSort {
                        continentSortQuiz
                    } else if !quizQuestions.isEmpty && currentQuestionIndex < quizQuestions.count {
                        standardQuiz
                    } else if !quizQuestions.isEmpty {
                        quizComplete
                    }
                } else {
                    modeSelection
                    difficultyPicker
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Score Board

    private var scoreBoard: some View {
        HStack(spacing: 0) {
            scoreStat(icon: "star.fill", value: "\(score)", label: "Score", color: .yellow)
            Rectangle().fill(.quaternary).frame(width: 1, height: 36)
            scoreStat(icon: "flame.fill", value: "\(streak)", label: "Streak", color: .orange)
            Rectangle().fill(.quaternary).frame(width: 1, height: 36)
            scoreStat(icon: "trophy.fill", value: "\(bestStreak)", label: "Best", color: .purple)
            Rectangle().fill(.quaternary).frame(width: 1, height: 36)
            scoreStat(icon: "checkmark.circle.fill", value: totalAnswered > 0 ? "\(score * 100 / max(totalAnswered, 1))%" : "--", label: "Accuracy", color: .green)
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func scoreStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mode Selection

    private var modeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(.indigo)
                Text("Choose Quiz Mode")
                    .font(.headline)
            }

            ForEach(WorldGeographyQuizMode.allCases) { mode in
                Button {
                    withAnimation(.snappy) {
                        selectedMode = mode
                        startQuiz(mode: mode)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: mode.icon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: .rect(cornerRadius: 12)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.rawValue)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.orange)
                Text("Difficulty")
                    .font(.headline)
            }
            Picker("Difficulty", selection: $quizDifficulty) {
                Text("Easy").tag(1)
                Text("Medium").tag(2)
                Text("Hard").tag(3)
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Quiz Header

    private func quizHeader(mode: WorldGeographyQuizMode) -> some View {
        HStack {
            Button {
                withAnimation(.snappy) {
                    selectedMode = nil
                    quizQuestions = []
                    currentQuestionIndex = 0
                    selectedAnswer = nil
                    showResult = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
            }
            Spacer()
            Text(mode.rawValue)
                .font(.headline)
            Spacer()
            if mode != .continentSort && !quizQuestions.isEmpty {
                Text("\(currentQuestionIndex + 1)/\(quizQuestions.count)")
                    .font(.caption.bold().monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.purple.opacity(0.15), in: Capsule())
            }
        }
    }

    // MARK: - Standard Quiz

    private var standardQuiz: some View {
        let question = quizQuestions[currentQuestionIndex]

        return VStack(spacing: 16) {
            // Question prompt
            VStack(spacing: 8) {
                if question.displayEmoji {
                    Text(question.prompt)
                        .font(.system(size: 64))
                } else {
                    Text(question.prompt)
                        .font(.title2.bold())
                }
                Text(question.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))

            // Answer options
            ForEach(question.options, id: \.self) { option in
                Button {
                    guard !showResult else { return }
                    withAnimation(.snappy) {
                        selectedAnswer = option
                        isCorrect = option == question.correctAnswer
                        showResult = true
                        totalAnswered += 1
                        if isCorrect {
                            score += 1
                            streak += 1
                            if streak > bestStreak { bestStreak = streak }
                        } else {
                            streak = 0
                        }
                    }
                } label: {
                    HStack {
                        if question.optionsAreEmoji {
                            Text(option)
                                .font(.system(size: 32))
                        } else {
                            Text(option)
                                .font(.body)
                        }
                        Spacer()
                        if showResult && option == question.correctAnswer {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if showResult && option == selectedAnswer && !isCorrect {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                    .background(answerBackground(for: option), in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(answerBorder(for: option), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: selectedAnswer)
            }

            if showResult {
                HStack {
                    Image(systemName: isCorrect ? "checkmark.seal.fill" : "info.circle.fill")
                        .foregroundStyle(isCorrect ? .green : .orange)
                    Text(isCorrect ? "Correct! Well done!" : "The answer is: \(question.correctAnswer)")
                        .font(.subheadline.bold())
                        .foregroundStyle(isCorrect ? .green : .orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background((isCorrect ? Color.green : Color.orange).opacity(0.1), in: .rect(cornerRadius: 12))

                Button {
                    withAnimation(.snappy) {
                        currentQuestionIndex += 1
                        selectedAnswer = nil
                        showResult = false
                    }
                } label: {
                    Text(currentQuestionIndex < quizQuestions.count - 1 ? "Next Question" : "See Results")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .sensoryFeedback(isCorrect ? .success : .error, trigger: showResult)
            }
        }
    }

    private func answerBackground(for option: String) -> some ShapeStyle {
        if showResult && option == quizQuestions[currentQuestionIndex].correctAnswer {
            return AnyShapeStyle(Color.green.opacity(0.12))
        } else if showResult && option == selectedAnswer && !isCorrect {
            return AnyShapeStyle(Color.red.opacity(0.12))
        } else if option == selectedAnswer {
            return AnyShapeStyle(Color.indigo.opacity(0.1))
        }
        return AnyShapeStyle(Color(.tertiarySystemFill))
    }

    private func answerBorder(for option: String) -> Color {
        if showResult && option == quizQuestions[currentQuestionIndex].correctAnswer {
            return .green.opacity(0.5)
        } else if showResult && option == selectedAnswer && !isCorrect {
            return .red.opacity(0.5)
        } else if option == selectedAnswer {
            return .indigo.opacity(0.4)
        }
        return .clear
    }

    // MARK: - Continent Sort Quiz

    private var continentSortQuiz: some View {
        VStack(spacing: 16) {
            Text("Drag each country to the correct continent")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(continentSortItems) { country in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(country.flag)
                            .font(.title2)
                        Text(country.name)
                            .font(.subheadline.bold())
                        Spacer()
                        if continentSortChecked {
                            if continentSortAnswers[country.name] == country.continent {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Continent.allCases) { continent in
                                let isSelected = continentSortAnswers[country.name] == continent
                                let isCorrectAnswer = continentSortChecked && continent == country.continent
                                Button {
                                    guard !continentSortChecked else { return }
                                    withAnimation(.snappy) {
                                        continentSortAnswers[country.name] = continent
                                    }
                                } label: {
                                    Text(continent.rawValue)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            isSelected ? continent.color.opacity(0.25) :
                                            isCorrectAnswer ? Color.green.opacity(0.15) :
                                            Color(.tertiarySystemFill),
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule().stroke(
                                                isSelected ? continent.color.opacity(0.6) :
                                                isCorrectAnswer ? Color.green.opacity(0.5) : .clear,
                                                lineWidth: 1.5
                                            )
                                        )
                                        .foregroundStyle(isSelected ? continent.color : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            }

            if !continentSortChecked {
                Button {
                    withAnimation(.snappy) {
                        continentSortChecked = true
                        let correctCount = continentSortItems.filter { continentSortAnswers[$0.name] == $0.continent }.count
                        score += correctCount
                        totalAnswered += continentSortItems.count
                    }
                } label: {
                    Text("Check Answers")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(continentSortAnswers.count < continentSortItems.count)
            } else {
                let correctCount = continentSortItems.filter { continentSortAnswers[$0.name] == $0.continent }.count
                VStack(spacing: 8) {
                    Text("\(correctCount)/\(continentSortItems.count) Correct")
                        .font(.title2.bold())
                    Button {
                        withAnimation(.snappy) {
                            startContinentSort()
                        }
                    } label: {
                        Text("Try Again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
                .sensoryFeedback(.success, trigger: continentSortChecked)
            }
        }
    }

    // MARK: - Quiz Complete

    private var quizComplete: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Quiz Complete!")
                .font(.title2.bold())

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("Correct")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(quizQuestions.count)")
                        .font(.title.bold())
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(bestStreak)")
                        .font(.title.bold())
                        .foregroundStyle(.orange)
                    Text("Best Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                withAnimation(.snappy) {
                    selectedMode = nil
                    quizQuestions = []
                    currentQuestionIndex = 0
                    selectedAnswer = nil
                    showResult = false
                }
            } label: {
                Text("Play Again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .sensoryFeedback(.success, trigger: currentQuestionIndex)
    }

    // MARK: - Quiz Generation

    private func startQuiz(mode: WorldGeographyQuizMode) {
        score = 0
        streak = 0
        bestStreak = 0
        totalAnswered = 0
        currentQuestionIndex = 0
        selectedAnswer = nil
        showResult = false

        if mode == .continentSort {
            startContinentSort()
            return
        }

        let pool = allCountries.filter { $0.difficulty <= quizDifficulty }.shuffled()
        var questions: [GeoQuizQuestion] = []

        for i in 0..<min(10, pool.count) {
            let country = pool[i]
            let otherCountries = pool.filter { $0.name != country.name }.shuffled()

            switch mode {
            case .nameTheCountry:
                let wrongAnswers = Array(otherCountries.prefix(3).map { $0.name })
                let options = ([country.name] + wrongAnswers).shuffled()
                questions.append(GeoQuizQuestion(
                    prompt: country.flag,
                    subtitle: "Which country does this flag belong to?",
                    options: options,
                    correctAnswer: country.name,
                    displayEmoji: true,
                    optionsAreEmoji: false
                ))

            case .capitalMatch:
                let wrongAnswers = Array(otherCountries.prefix(3).map { $0.capital })
                let options = ([country.capital] + wrongAnswers).shuffled()
                questions.append(GeoQuizQuestion(
                    prompt: country.name,
                    subtitle: "What is the capital of this country?",
                    options: options,
                    correctAnswer: country.capital,
                    displayEmoji: false,
                    optionsAreEmoji: false
                ))

            case .flagQuiz:
                let wrongAnswers = Array(otherCountries.prefix(3).map { $0.flag })
                let options = ([country.flag] + wrongAnswers).shuffled()
                questions.append(GeoQuizQuestion(
                    prompt: country.name,
                    subtitle: "Which flag belongs to this country?",
                    options: options,
                    correctAnswer: country.flag,
                    displayEmoji: false,
                    optionsAreEmoji: true
                ))

            case .continentSort:
                break
            }
        }

        quizQuestions = questions
    }

    private func startContinentSort() {
        continentSortChecked = false
        continentSortAnswers = [:]
        let pool = allCountries.filter { $0.difficulty <= quizDifficulty }.shuffled()
        continentSortItems = Array(pool.prefix(8))
    }
}

// MARK: - Quiz Question Model

private struct GeoQuizQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let subtitle: String
    let options: [String]
    let correctAnswer: String
    let displayEmoji: Bool
    let optionsAreEmoji: Bool
}

// MARK: - Preview

#Preview {
    WorldMapQuizView()
}
