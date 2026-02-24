import SwiftUI

// MARK: - Data Models

struct IndigenousGroup: Identifiable {
    let id = UUID()
    let name: String
    let category: IndigenousCategory
    let territory: String
    let languages: [String]
    let culturalPractices: [String]
    let description: String
    let icon: String
}

enum IndigenousCategory: String, CaseIterable {
    case firstNations = "First Nations"
    case inuit = "Inuit"
    case metis = "M\u{00E9}tis"

    var color: Color {
        switch self {
        case .firstNations: return Color(red: 0.72, green: 0.33, blue: 0.13) // Warm brown-orange
        case .inuit: return Color(red: 0.30, green: 0.50, blue: 0.55)        // Arctic blue-grey
        case .metis: return Color(red: 0.55, green: 0.35, blue: 0.22)        // Deep earth brown
        }
    }

    var icon: String {
        switch self {
        case .firstNations: return "leaf.fill"
        case .inuit: return "snowflake"
        case .metis: return "figure.dance"
        }
    }

    var description: String {
        switch self {
        case .firstNations: return "The diverse First Nations peoples have lived on Turtle Island (North America) since time immemorial, with over 630 communities across Canada."
        case .inuit: return "The Inuit are Indigenous peoples of the Arctic regions of Canada, with a deep connection to the land, sea, and ice of the North."
        case .metis: return "The M\u{00E9}tis are a distinct Indigenous people with roots in both First Nations and European heritage, with their own unique culture, language, and traditions."
        }
    }
}

struct TimelineEvent: Identifiable {
    let id = UUID()
    let year: String
    let title: String
    let description: String
    let icon: String
    let significance: EventSignificance
}

enum EventSignificance {
    case positive
    case negative
    case neutral
    case reconciliation

    var color: Color {
        switch self {
        case .positive: return .green
        case .negative: return Color(red: 0.6, green: 0.3, blue: 0.3)
        case .neutral: return Color(red: 0.72, green: 0.55, blue: 0.33)
        case .reconciliation: return Color(red: 0.85, green: 0.55, blue: 0.15)
        }
    }
}

struct CulturalAchievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let category: String
}

struct IndigenousQuizQuestion: Identifiable {
    let id = UUID()
    let question: String
    let options: [String]
    let correctAnswer: String
    let explanation: String
}

// MARK: - Data

private let indigenousGroups: [IndigenousGroup] = [
    // First Nations
    IndigenousGroup(
        name: "Haudenosaunee (Iroquois)",
        category: .firstNations,
        territory: "Southern Ontario, Quebec, and northeastern United States",
        languages: ["Mohawk", "Oneida", "Onondaga", "Cayuga", "Seneca", "Tuscarora"],
        culturalPractices: ["Great Law of Peace (Kayanerenhkowa)", "Longhouse governance", "Wampum belts", "Lacrosse", "Three Sisters agriculture (corn, beans, squash)"],
        description: "The Haudenosaunee Confederacy, also known as the Six Nations, is one of the oldest participatory democracies in the world. Their Great Law of Peace influenced democratic ideas worldwide.",
        icon: "building.columns.fill"
    ),
    IndigenousGroup(
        name: "Anishinaabe (Ojibwe)",
        category: .firstNations,
        territory: "Great Lakes region across Ontario, Manitoba, Saskatchewan, and Quebec",
        languages: ["Anishinaabemowin (Ojibwe)", "Algonquin", "Odawa"],
        culturalPractices: ["Medicine Wheel teachings", "Dreamcatcher making", "Wild rice harvesting", "Birch bark canoe building", "Midewiwin ceremonies"],
        description: "The Anishinaabe people are among the most populous Indigenous groups in Canada. They have a rich tradition of oral storytelling and are known for their deep connection to the Great Lakes.",
        icon: "water.waves"
    ),
    IndigenousGroup(
        name: "Cree (Nehiyawak)",
        category: .firstNations,
        territory: "From Quebec across Ontario, Manitoba, Saskatchewan, Alberta, and Northwest Territories",
        languages: ["Cree (multiple dialects: Plains, Swampy, Woods, Moose)"],
        culturalPractices: ["Pow-wows", "Sweat lodge ceremonies", "Syllabic writing system", "Trapping and hunting traditions", "Tipi construction"],
        description: "The Cree are one of the largest First Nations groups in Canada. Their language, Cree, has more speakers than any other Indigenous language in Canada.",
        icon: "tent.fill"
    ),
    IndigenousGroup(
        name: "Blackfoot (Niitsitapi)",
        category: .firstNations,
        territory: "Southern Alberta and northern Montana",
        languages: ["Blackfoot (Siksikaitsitapi)"],
        culturalPractices: ["Sun Dance ceremony", "Buffalo hunting traditions", "Tipi painting", "Warrior societies", "Star knowledge and astronomy"],
        description: "The Blackfoot Confederacy consists of four nations: Siksika, Piikani, Kainai, and Amskapi Piikani. They were renowned buffalo hunters of the Great Plains.",
        icon: "sun.max.fill"
    ),
    IndigenousGroup(
        name: "Haida",
        category: .firstNations,
        territory: "Haida Gwaii (formerly Queen Charlotte Islands), British Columbia",
        languages: ["Haida (Xaat Kil)"],
        culturalPractices: ["Totem pole carving", "Potlatch ceremonies", "Cedar canoe building", "Argillite carving", "Bentwood box making"],
        description: "The Haida are master artists and carvers known worldwide for their monumental totem poles and intricate art. They have been stewards of Haida Gwaii for over 13,000 years.",
        icon: "tree.fill"
    ),
    IndigenousGroup(
        name: "Mi'kmaq (L'nu)",
        category: .firstNations,
        territory: "Atlantic provinces: Nova Scotia, New Brunswick, PEI, Quebec, Newfoundland",
        languages: ["Mi'kmaq"],
        culturalPractices: ["Birch bark canoe and wigwam building", "Quillwork and beadwork", "Storytelling traditions", "Smudging ceremonies", "Treaty Day celebrations"],
        description: "The Mi'kmaq were among the first Indigenous peoples to make contact with European explorers. They are the original inhabitants of Mi'kma'ki, the Atlantic region of Canada.",
        icon: "sailboat.fill"
    ),
    // Inuit
    IndigenousGroup(
        name: "Inuit",
        category: .inuit,
        territory: "Inuit Nunangat: Nunavut, Nunavik (northern Quebec), Nunatsiavut (Labrador), Inuvialuit (Northwest Territories)",
        languages: ["Inuktitut", "Inuinnaqtun", "Inuvialuktun"],
        culturalPractices: ["Inuksuk building", "Throat singing (katajjaq)", "Drum dancing", "Soapstone carving", "Ice fishing and seal hunting", "Igloo construction", "Dog sled travel"],
        description: "The Inuit have thrived in the Arctic for thousands of years, developing remarkable knowledge of the land, sea, ice, and wildlife. Their traditional ecological knowledge is increasingly recognized as vital for understanding climate change.",
        icon: "snowflake"
    ),
    // Metis
    IndigenousGroup(
        name: "M\u{00E9}tis",
        category: .metis,
        territory: "Manitoba, Saskatchewan, Alberta, Ontario, British Columbia, and Northwest Territories",
        languages: ["Michif", "French", "Cree", "Ojibwe"],
        culturalPractices: ["Red River jigging", "Finger weaving and beadwork (flower beadwork)", "Fiddle music", "Buffalo hunt traditions", "M\u{00E9}tis sash weaving"],
        description: "The M\u{00E9}tis emerged as a distinct people in the 18th century, developing their own language (Michif), culture, and governance. They played a crucial role in the fur trade and the development of western Canada.",
        icon: "figure.dance"
    )
]

private let timelineEvents: [TimelineEvent] = [
    TimelineEvent(
        year: "Time Immemorial",
        title: "Indigenous Peoples on Turtle Island",
        description: "Indigenous peoples have lived on the land now called Canada since time immemorial, developing rich cultures, languages, governance systems, and deep connections to the land.",
        icon: "globe.americas.fill",
        significance: .positive
    ),
    TimelineEvent(
        year: "1701",
        title: "Great Peace of Montreal",
        description: "Thirty-nine Indigenous nations signed a peace treaty with the French, one of the largest diplomatic gatherings in North American history.",
        icon: "doc.text.fill",
        significance: .positive
    ),
    TimelineEvent(
        year: "1763",
        title: "Royal Proclamation",
        description: "The British Crown recognized Indigenous land rights and established that only the Crown could purchase Indigenous lands, setting a foundation for treaty-making.",
        icon: "scroll.fill",
        significance: .neutral
    ),
    TimelineEvent(
        year: "1869-1870",
        title: "Red River Resistance",
        description: "Led by Louis Riel, the M\u{00E9}tis people resisted Canadian expansion into their homeland, leading to the creation of Manitoba and recognition of M\u{00E9}tis rights.",
        icon: "flag.fill",
        significance: .neutral
    ),
    TimelineEvent(
        year: "1871-1921",
        title: "Numbered Treaties",
        description: "Eleven Numbered Treaties were signed between the Crown and First Nations across northern and western Canada. Indigenous peoples understood these as agreements to share the land, not surrender it.",
        icon: "signature",
        significance: .neutral
    ),
    TimelineEvent(
        year: "1876",
        title: "Indian Act",
        description: "The Canadian government passed the Indian Act, imposing restrictions on First Nations peoples including banning cultural ceremonies, restricting movement, and controlling governance.",
        icon: "exclamationmark.triangle.fill",
        significance: .negative
    ),
    TimelineEvent(
        year: "1880s-1996",
        title: "Residential Schools",
        description: "The residential school system forcibly removed Indigenous children from their families with the goal of eliminating Indigenous cultures and languages. Over 150,000 children attended these schools, and many suffered abuse and neglect. Thousands of children did not return home.",
        icon: "heart.slash.fill",
        significance: .negative
    ),
    TimelineEvent(
        year: "1960",
        title: "Right to Vote",
        description: "First Nations people gained the unconditional right to vote in federal elections without giving up their Treaty rights or Indian status.",
        icon: "checkmark.seal.fill",
        significance: .positive
    ),
    TimelineEvent(
        year: "1969",
        title: "White Paper / Red Paper",
        description: "The government proposed eliminating Indian status and treaties. Indigenous leaders responded with the 'Red Paper' (Citizens Plus), defending their rights. The White Paper was withdrawn.",
        icon: "doc.fill",
        significance: .neutral
    ),
    TimelineEvent(
        year: "1982",
        title: "Constitution Act - Section 35",
        description: "Section 35 of the Constitution Act recognized and affirmed existing Aboriginal and Treaty rights, marking a major legal milestone for Indigenous rights in Canada.",
        icon: "text.book.closed.fill",
        significance: .positive
    ),
    TimelineEvent(
        year: "1999",
        title: "Creation of Nunavut",
        description: "Nunavut was established as Canada's newest territory, providing Inuit self-governance over a vast area of the eastern Arctic. The name means 'our land' in Inuktitut.",
        icon: "map.fill",
        significance: .positive
    ),
    TimelineEvent(
        year: "2008",
        title: "Official Apology for Residential Schools",
        description: "Prime Minister Stephen Harper delivered a formal apology in Parliament to survivors of the residential school system, acknowledging the harm caused.",
        icon: "person.wave.2.fill",
        significance: .reconciliation
    ),
    TimelineEvent(
        year: "2015",
        title: "Truth and Reconciliation Commission",
        description: "The TRC released its final report with 94 Calls to Action to address the legacy of residential schools and advance reconciliation between Indigenous and non-Indigenous Canadians.",
        icon: "lightbulb.fill",
        significance: .reconciliation
    ),
    TimelineEvent(
        year: "2021",
        title: "National Day for Truth and Reconciliation",
        description: "September 30 was established as a federal statutory holiday to honour residential school survivors, their families, and the children who never returned. It is also known as Orange Shirt Day.",
        icon: "heart.fill",
        significance: .reconciliation
    )
]

private let culturalAchievements: [CulturalAchievement] = [
    CulturalAchievement(title: "Totem Pole Carving", description: "Northwest Coast nations, especially the Haida and Kwakwaka'wakw, are renowned for monumental cedar totem poles that tell stories, honour ancestors, and mark important events.", icon: "tree.fill", category: "Art"),
    CulturalAchievement(title: "Inuit Soapstone Sculpture", description: "Inuit artists create stunning sculptures from soapstone, depicting Arctic life, animals, and spiritual beings. This art form has gained worldwide recognition.", icon: "cube.fill", category: "Art"),
    CulturalAchievement(title: "Throat Singing (Katajjaq)", description: "Inuit throat singing is a unique musical form where two performers face each other, creating rhythmic vocal sounds. It is traditionally performed by women.", icon: "music.note", category: "Music"),
    CulturalAchievement(title: "Haudenosaunee Great Law of Peace", description: "The Haudenosaunee Confederacy developed one of the world's oldest participatory democracies, with principles that influenced the development of democratic governance globally.", icon: "building.columns.fill", category: "Governance"),
    CulturalAchievement(title: "Traditional Ecological Knowledge", description: "Indigenous peoples have developed sophisticated understanding of ecosystems over thousands of years. This knowledge is now recognized as essential for conservation and climate science.", icon: "leaf.fill", category: "Environment"),
    CulturalAchievement(title: "M\u{00E9}tis Beadwork", description: "The M\u{00E9}tis are known as the 'Flower Beadwork People' for their distinctive and intricate floral beadwork designs on clothing, moccasins, and accessories.", icon: "sparkles", category: "Art"),
    CulturalAchievement(title: "Pow-wow Traditions", description: "Pow-wows are vibrant gatherings that celebrate Indigenous culture through dance, music, regalia, and community. They bring together people from many nations in celebration.", icon: "music.mic.circle.fill", category: "Music"),
    CulturalAchievement(title: "Three Sisters Agriculture", description: "First Nations peoples developed the Three Sisters planting method (corn, beans, and squash grown together), a sustainable agricultural technique that enriches the soil.", icon: "carrot.fill", category: "Environment"),
    CulturalAchievement(title: "Syllabic Writing System", description: "James Evans and Cree elders developed the Cree syllabics writing system in the 1840s. It was later adapted for Inuktitut and other Indigenous languages.", icon: "text.book.closed.fill", category: "Language"),
    CulturalAchievement(title: "Lacrosse", description: "Lacrosse, known as 'the Creator's Game,' was developed by First Nations peoples, particularly the Haudenosaunee. It was both a sport and a spiritual practice.", icon: "sportscourt.fill", category: "Sport")
]

private let quizQuestions: [IndigenousQuizQuestion] = [
    IndigenousQuizQuestion(
        question: "What are the three groups of Indigenous peoples recognized in Canada?",
        options: ["First Nations, Inuit, and M\u{00E9}tis", "Cree, Ojibwe, and Haida", "Haudenosaunee, Blackfoot, and Mi'kmaq", "Dene, Algonquin, and Salish"],
        correctAnswer: "First Nations, Inuit, and M\u{00E9}tis",
        explanation: "Canada's Constitution recognizes three groups of Indigenous peoples: First Nations, Inuit, and M\u{00E9}tis. Each has distinct cultures, languages, and histories."
    ),
    IndigenousQuizQuestion(
        question: "What does 'Nunavut' mean in Inuktitut?",
        options: ["Northern home", "Our land", "Cold place", "Frozen water"],
        correctAnswer: "Our land",
        explanation: "Nunavut means 'our land' in Inuktitut. Created in 1999, it provides Inuit self-governance in the eastern Arctic."
    ),
    IndigenousQuizQuestion(
        question: "Who led the Red River Resistance of 1869-1870?",
        options: ["Sitting Bull", "Tecumseh", "Louis Riel", "Big Bear"],
        correctAnswer: "Louis Riel",
        explanation: "Louis Riel, a M\u{00E9}tis leader, led the Red River Resistance to protect M\u{00E9}tis rights, leading to the creation of Manitoba."
    ),
    IndigenousQuizQuestion(
        question: "What is the Inuit art of throat singing called?",
        options: ["Powwow", "Katajjaq", "Potlatch", "Sundance"],
        correctAnswer: "Katajjaq",
        explanation: "Katajjaq (throat singing) is a unique Inuit musical tradition where two performers face each other, creating rhythmic vocal sounds."
    ),
    IndigenousQuizQuestion(
        question: "What are the 'Three Sisters' in Indigenous agriculture?",
        options: ["Wheat, barley, and oats", "Corn, beans, and squash", "Rice, peas, and lettuce", "Potatoes, tomatoes, and peppers"],
        correctAnswer: "Corn, beans, and squash",
        explanation: "The Three Sisters (corn, beans, and squash) are planted together. The corn provides support for beans, beans add nitrogen to the soil, and squash leaves shade the ground."
    ),
    IndigenousQuizQuestion(
        question: "When is the National Day for Truth and Reconciliation?",
        options: ["July 1", "June 21", "September 30", "November 11"],
        correctAnswer: "September 30",
        explanation: "September 30 is the National Day for Truth and Reconciliation, also known as Orange Shirt Day, honouring residential school survivors."
    ),
    IndigenousQuizQuestion(
        question: "What is a 'potlatch'?",
        options: ["A type of canoe", "A gift-giving feast and ceremony", "A hunting technique", "A building structure"],
        correctAnswer: "A gift-giving feast and ceremony",
        explanation: "A potlatch is a ceremonial feast practised by Northwest Coast nations involving gift-giving, feasting, dancing, and the sharing of wealth and stories."
    ),
    IndigenousQuizQuestion(
        question: "How many Calls to Action did the Truth and Reconciliation Commission issue?",
        options: ["50", "72", "94", "150"],
        correctAnswer: "94",
        explanation: "The TRC issued 94 Calls to Action in 2015 to address the legacy of residential schools and advance reconciliation."
    ),
    IndigenousQuizQuestion(
        question: "Why are the M\u{00E9}tis known as the 'Flower Beadwork People'?",
        options: ["They grow flowers", "Their distinctive floral beadwork designs", "They worship flowers", "They trade flowers"],
        correctAnswer: "Their distinctive floral beadwork designs",
        explanation: "The M\u{00E9}tis earned this name for their beautiful and intricate floral beadwork designs on clothing and accessories."
    ),
    IndigenousQuizQuestion(
        question: "What is an inuksuk?",
        options: ["A type of kayak", "A stone landmark built by Inuit", "A traditional drum", "A snow shelter"],
        correctAnswer: "A stone landmark built by Inuit",
        explanation: "An inuksuk (plural: inuksuit) is a stone structure built by the Inuit, used as landmarks for navigation, to mark food caches, or for spiritual purposes."
    )
]

// MARK: - Main View

struct IndigenousPeoplesView: View {
    @State private var selectedSection: Int = 0
    @State private var expandedGroup: UUID?
    @State private var expandedEvent: UUID?
    @State private var showQuiz = false
    @State private var quizIndex = 0
    @State private var selectedAnswer: String?
    @State private var isAnswerRevealed = false
    @State private var quizScore = 0
    @State private var quizCompleted = false
    @State private var shuffledQuiz: [IndigenousQuizQuestion] = []
    @State private var animateResult = false

    private let earthBrown = Color(red: 0.72, green: 0.55, blue: 0.33)
    private let deepOrange = Color(red: 0.80, green: 0.45, blue: 0.15)
    private let warmGreen = Color(red: 0.30, green: 0.50, blue: 0.30)
    private let earthRed = Color(red: 0.72, green: 0.33, blue: 0.13)

    private let sections = ["Peoples", "Timeline", "Culture", "Quiz"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sectionSelector
                TabView(selection: $selectedSection) {
                    peoplesTab.tag(0)
                    timelineTab.tag(1)
                    cultureTab.tag(2)
                    quizTab.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: selectedSection)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Indigenous Peoples of Canada")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Section Selector

    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(sections.enumerated()), id: \.offset) { index, title in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedSection = index
                        }
                    } label: {
                        Text(title)
                            .font(.subheadline.weight(selectedSection == index ? .bold : .medium))
                            .foregroundStyle(selectedSection == index ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background {
                                if selectedSection == index {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [earthRed, deepOrange],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                    }
                    .sensoryFeedback(.selection, trigger: selectedSection)
                }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Peoples Tab

    private var peoplesTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Respectful introduction
                introductionCard

                // Category cards
                ForEach(IndigenousCategory.allCases, id: \.rawValue) { category in
                    categorySection(category)
                }

                landAcknowledgementCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .padding(.top, 8)
        }
    }

    private var introductionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe.americas.fill")
                .font(.title)
                .foregroundStyle(
                    LinearGradient(colors: [earthRed, deepOrange], startPoint: .top, endPoint: .bottom)
                )

            Text("Learning About Indigenous Peoples")
                .font(.headline)

            Text("Indigenous peoples have lived on this land since time immemorial. This section offers an introduction to the rich cultures, histories, and contributions of First Nations, Inuit, and M\u{00E9}tis peoples. We approach this learning with respect and a commitment to understanding.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [earthRed.opacity(0.12), deepOrange.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private func categorySection(_ category: IndigenousCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(category.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(.title3.bold())
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(category.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            // Groups in this category
            let groups = indigenousGroups.filter { $0.category == category }
            ForEach(groups) { group in
                groupCard(group)
            }
        }
    }

    private func groupCard(_ group: IndigenousGroup) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expandedGroup = expandedGroup == group.id ? nil : group.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: group.icon)
                        .font(.title3)
                        .foregroundStyle(group.category.color)
                        .frame(width: 36, height: 36)
                        .background(group.category.color.opacity(0.15), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(group.territory)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(expandedGroup == group.id ? nil : 1)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expandedGroup == group.id ? 180 : 0))
                }
                .padding(14)
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: expandedGroup)

            if expandedGroup == group.id {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()

                    Text(group.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Languages
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Languages", systemImage: "text.bubble.fill")
                            .font(.caption.bold())
                            .foregroundStyle(group.category.color)

                        IndigenousFlowLayout(spacing: 6) {
                            ForEach(group.languages, id: \.self) { lang in
                                Text(lang)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(group.category.color.opacity(0.12), in: Capsule())
                            }
                        }
                    }

                    // Cultural practices
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Cultural Practices", systemImage: "sparkles")
                            .font(.caption.bold())
                            .foregroundStyle(group.category.color)

                        ForEach(group.culturalPractices, id: \.self) { practice in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(group.category.color)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 5)
                                Text(practice)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var landAcknowledgementCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.title2)
                .foregroundStyle(warmGreen)

            Text("Land Acknowledgement")
                .font(.subheadline.bold())

            Text("All of Canada is on the traditional territories of Indigenous peoples. Learning about and respecting Indigenous peoples, their histories, and their ongoing contributions is an important part of reconciliation.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(warmGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Timeline Tab

    private var timelineTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                timelineHeader

                ForEach(Array(timelineEvents.enumerated()), id: \.element.id) { index, event in
                    timelineEventCard(event, index: index)
                }

                reconciliationFooter
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .padding(.top, 8)
        }
    }

    private var timelineHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title)
                .foregroundStyle(deepOrange)
            Text("Key Historical Events")
                .font(.headline)
            Text("An overview of significant events in the history of Indigenous peoples in Canada")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [deepOrange.opacity(0.1), earthBrown.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .padding(.bottom, 16)
    }

    private func timelineEventCard(_ event: TimelineEvent, index: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline line and dot
            VStack(spacing: 0) {
                if index > 0 {
                    Rectangle()
                        .fill(event.significance.color.opacity(0.3))
                        .frame(width: 2, height: 20)
                } else {
                    Color.clear.frame(width: 2, height: 20)
                }

                Circle()
                    .fill(event.significance.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))

                if index < timelineEvents.count - 1 {
                    Rectangle()
                        .fill(event.significance.color.opacity(0.3))
                        .frame(width: 2)
                }
            }
            .frame(width: 16)

            // Event card
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expandedEvent = expandedEvent == event.id ? nil : event.id
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: event.icon)
                            .font(.caption)
                            .foregroundStyle(event.significance.color)
                        Text(event.year)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(event.significance.color)
                    }

                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if expandedEvent == event.id {
                        Text(event.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(event.significance.color.opacity(0.3), lineWidth: 1)
                )
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: expandedEvent)
        }
        .padding(.bottom, 4)
    }

    private var reconciliationFooter: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 0.85, green: 0.55, blue: 0.15))

            Text("Reconciliation Is Ongoing")
                .font(.subheadline.bold())

            Text("Reconciliation is not a single event but an ongoing process. Every Canadian has a role to play in building respectful relationships with Indigenous peoples and understanding our shared history.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Label("Orange Shirt Day", systemImage: "tshirt.fill")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)

                Label("Sept 30", systemImage: "calendar")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            Color.orange.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .padding(.top, 12)
    }

    // MARK: - Culture Tab

    private var cultureTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                cultureHeader

                let categories = Array(Set(culturalAchievements.map(\.category))).sorted()
                ForEach(categories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(category)
                            .font(.subheadline.bold())
                            .foregroundStyle(earthRed)
                            .padding(.horizontal, 4)

                        let items = culturalAchievements.filter { $0.category == category }
                        ForEach(items) { achievement in
                            achievementCard(achievement)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .padding(.top, 8)
        }
    }

    private var cultureHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.title)
                .foregroundStyle(
                    LinearGradient(colors: [earthRed, deepOrange], startPoint: .top, endPoint: .bottom)
                )
            Text("Cultural Achievements")
                .font(.headline)
            Text("Celebrating the rich contributions of Indigenous peoples to art, music, governance, and the environment")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [earthRed.opacity(0.1), warmGreen.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private func achievementCard(_ achievement: CulturalAchievement) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: achievement.icon)
                .font(.title3)
                .foregroundStyle(earthRed)
                .frame(width: 36, height: 36)
                .background(earthRed.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline.weight(.semibold))
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quiz Tab

    private var quizTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !showQuiz {
                    quizIntro
                } else if quizCompleted {
                    quizResults
                } else {
                    quizActiveView
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .padding(.top, 8)
        }
    }

    private var quizIntro: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(colors: [earthRed, deepOrange], startPoint: .top, endPoint: .bottom)
                )

            Text("Test Your Knowledge")
                .font(.title2.bold())

            Text("Answer questions about the Indigenous peoples of Canada, their histories, cultures, and contributions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if quizScore > 0 {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(quizScore)")
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(warmGreen)
                        Text("Last Score")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("/")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 4) {
                        Text("\(quizQuestions.count)")
                            .font(.title.bold().monospacedDigit())
                        Text("Questions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            Button {
                startQuiz()
            } label: {
                Label("Start Quiz", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [earthRed, deepOrange], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: showQuiz)
        }
    }

    private var quizActiveView: some View {
        VStack(spacing: 16) {
            // Progress
            HStack {
                Text("Question \(quizIndex + 1) of \(shuffledQuiz.count)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(quizScore) correct")
                    .font(.caption.bold())
                    .foregroundStyle(warmGreen)
            }

            ProgressView(value: Double(quizIndex + 1), total: Double(shuffledQuiz.count))
                .tint(earthRed)

            if quizIndex < shuffledQuiz.count {
                let q = shuffledQuiz[quizIndex]

                // Question
                VStack(spacing: 10) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(earthRed)
                    Text(q.question)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Options
                ForEach(q.options, id: \.self) { option in
                    Button {
                        guard !isAnswerRevealed else { return }
                        selectedAnswer = option
                        isAnswerRevealed = true
                        if option == q.correctAnswer {
                            quizScore += 1
                        }
                    } label: {
                        HStack {
                            Text(option)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(quizOptionColor(option, correct: q.correctAnswer))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if isAnswerRevealed {
                                if option == q.correctAnswer {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if option == selectedAnswer {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .background(quizOptionBG(option, correct: q.correctAnswer), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(quizOptionBorder(option, correct: q.correctAnswer), lineWidth: 2)
                        )
                    }
                    .sensoryFeedback(.impact(flexibility: .rigid), trigger: isAnswerRevealed)
                }

                // Explanation
                if isAnswerRevealed {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Learn More", systemImage: "lightbulb.fill")
                            .font(.caption.bold())
                            .foregroundStyle(deepOrange)
                        Text(q.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(deepOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        nextQuizQuestion()
                    } label: {
                        Text(quizIndex < shuffledQuiz.count - 1 ? "Next Question" : "See Results")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [earthRed, deepOrange], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                }
            }
        }
    }

    private var quizResults: some View {
        VStack(spacing: 24) {
            Image(systemName: quizScore >= shuffledQuiz.count / 2 ? "star.fill" : "arrow.counterclockwise")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: quizScore >= shuffledQuiz.count / 2 ? [.yellow, deepOrange] : [.red, deepOrange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(animateResult ? 1.0 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateResult)

            Text(quizScore >= shuffledQuiz.count * 8 / 10 ? "Excellent!" :
                 quizScore >= shuffledQuiz.count / 2 ? "Well Done!" : "Keep Learning!")
                .font(.title.bold())

            Text("\(quizScore) out of \(shuffledQuiz.count) correct")
                .font(.title3)
                .foregroundStyle(.secondary)

            let pct = shuffledQuiz.isEmpty ? 0.0 : Double(quizScore) / Double(shuffledQuiz.count)
            VStack(spacing: 8) {
                Text("\(Int(pct * 100))%")
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(pct >= 0.8 ? warmGreen : pct >= 0.5 ? deepOrange : .red)
                ProgressView(value: pct)
                    .tint(pct >= 0.8 ? warmGreen : pct >= 0.5 ? deepOrange : .red)
                    .scaleEffect(y: 2)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Button {
                startQuiz()
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [earthRed, deepOrange], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }

            Button {
                showQuiz = false
                quizCompleted = false
            } label: {
                Text("Back to Quiz Home")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(earthRed)
            }
        }
        .onAppear { animateResult = true }
    }

    // MARK: - Quiz Helpers

    private func quizOptionColor(_ option: String, correct: String) -> Color {
        guard isAnswerRevealed else { return .primary }
        if option == correct { return .green }
        if option == selectedAnswer { return .red }
        return .secondary
    }

    private func quizOptionBG(_ option: String, correct: String) -> some ShapeStyle {
        guard isAnswerRevealed else { return AnyShapeStyle(.ultraThinMaterial) }
        if option == correct { return AnyShapeStyle(Color.green.opacity(0.1)) }
        if option == selectedAnswer { return AnyShapeStyle(Color.red.opacity(0.1)) }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private func quizOptionBorder(_ option: String, correct: String) -> Color {
        guard isAnswerRevealed else { return .clear }
        if option == correct { return .green }
        if option == selectedAnswer { return .red }
        return .clear
    }

    private func startQuiz() {
        shuffledQuiz = quizQuestions.shuffled()
        quizIndex = 0
        quizScore = 0
        selectedAnswer = nil
        isAnswerRevealed = false
        quizCompleted = false
        animateResult = false
        showQuiz = true
    }

    private func nextQuizQuestion() {
        if quizIndex < shuffledQuiz.count - 1 {
            quizIndex += 1
            selectedAnswer = nil
            isAnswerRevealed = false
        } else {
            quizCompleted = true
        }
    }
}

// MARK: - IndigenousFlowLayout

private struct IndigenousFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    IndigenousPeoplesView()
}
