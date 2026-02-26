import SwiftUI

// MARK: - Data Model

struct CanadianHistoryEvent: Identifiable {
    let id: Int
    let year: String
    let title: String
    let description: String
    let icon: String
    let era: HistoricalEra
}

enum HistoricalEra: String, CaseIterable {
    case preConfederation = "Pre-Confederation"
    case confederationEra = "Confederation Era"
    case worldWars = "World Wars"
    case modernCanada = "Modern Canada"

    var color: Color {
        switch self {
        case .preConfederation: .blue
        case .confederationEra: .purple
        case .worldWars: .red
        case .modernCanada: .green
        }
    }
}

// MARK: - Timeline View

struct CanadianHistoryTimelineView: View {
    @State private var expandedEvents: Set<Int> = []
    @State private var appeared = false

    private let events: [CanadianHistoryEvent] = [
        // MARK: Pre-Confederation
        CanadianHistoryEvent(
            id: 1,
            year: "1497",
            title: "John Cabot Reaches Newfoundland",
            description: "Italian explorer Giovanni Caboto (John Cabot), sailing under the English flag, reached the coast of Newfoundland, claiming it for King Henry VII of England.",
            icon: "wind",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 2,
            year: "1534",
            title: "Jacques Cartier Explores Canada",
            description: "French explorer Jacques Cartier made three voyages to Canada, claiming the land for France. He explored the St. Lawrence River and established contact with Indigenous peoples.",
            icon: "sailboat.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 3,
            year: "1608",
            title: "Founding of Quebec City",
            description: "Samuel de Champlain founded Quebec City, establishing the first permanent French settlement in North America and the capital of New France.",
            icon: "building.columns.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 4,
            year: "1670",
            title: "Hudson's Bay Company Founded",
            description: "King Charles II granted a royal charter to the Hudson's Bay Company, giving it a fur trade monopoly over the vast watershed draining into Hudson Bay — nearly 40% of modern Canada.",
            icon: "storefront.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 5,
            year: "1755",
            title: "Expulsion of the Acadians",
            description: "British authorities forcibly deported thousands of French-speaking Acadians from Nova Scotia, scattering them across the Atlantic colonies. Many eventually settled in Louisiana, forming Cajun culture.",
            icon: "figure.walk.departure",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 6,
            year: "1763",
            title: "Treaty of Paris",
            description: "France ceded New France to Britain after the Seven Years' War. This marked the beginning of British rule in Canada and reshaped the continent's colonial boundaries.",
            icon: "doc.text.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 7,
            year: "1791",
            title: "Constitutional Act",
            description: "Britain divided Quebec into Upper Canada (English-speaking, Ontario) and Lower Canada (French-speaking, Quebec), each with its own elected assembly.",
            icon: "rectangle.split.2x1.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 8,
            year: "1812",
            title: "War of 1812",
            description: "Canada (as British North America) defended against American invasion. The war helped forge a distinct Canadian identity and strengthened ties with Britain.",
            icon: "shield.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 9,
            year: "1837",
            title: "Rebellions of 1837-1838",
            description: "Armed uprisings in both Upper and Lower Canada demanded democratic reform and responsible government. Though militarily defeated, the rebellions led to the Durham Report and eventual self-governance.",
            icon: "flame.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 10,
            year: "1848",
            title: "Responsible Government Achieved",
            description: "Nova Scotia became the first British colony to achieve responsible government, where the executive must maintain the confidence of the elected assembly. The Province of Canada followed shortly after.",
            icon: "checkmark.seal.fill",
            era: .preConfederation
        ),

        // MARK: Confederation Era
        CanadianHistoryEvent(
            id: 11,
            year: "1867",
            title: "Confederation",
            description: "The British North America Act united Ontario, Quebec, Nova Scotia, and New Brunswick into the Dominion of Canada on July 1st. Sir John A. Macdonald became the first Prime Minister.",
            icon: "star.fill",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 12,
            year: "1869",
            title: "Red River Rebellion",
            description: "Led by Louis Riel, the Métis people of the Red River Colony resisted Canadian authority, leading to the creation of Manitoba as a province in 1870.",
            icon: "flag.fill",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 13,
            year: "1871",
            title: "British Columbia Joins Confederation",
            description: "British Columbia agreed to join Canada on the promise that a transcontinental railway would be built within 10 years, linking the Pacific coast to the rest of the country.",
            icon: "mountain.2.fill",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 14,
            year: "1873",
            title: "PEI Joins & NWMP Created",
            description: "Prince Edward Island became the seventh province. The same year, the North-West Mounted Police (forerunner of the RCMP) was established to bring law and order to the western territories.",
            icon: "star.circle.fill",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 15,
            year: "1885",
            title: "Last Spike / CPR Completion",
            description: "The Canadian Pacific Railway was completed at Craigellachie, BC, connecting Canada from coast to coast and fulfilling a key promise of Confederation.",
            icon: "tram.fill",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 16,
            year: "1896",
            title: "Klondike Gold Rush",
            description: "The discovery of gold in the Klondike region of Yukon triggered a massive stampede of prospectors. Over 100,000 set out for the goldfields, though fewer than half arrived. The rush transformed the Canadian North.",
            icon: "sparkles",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 17,
            year: "1905",
            title: "Alberta & Saskatchewan Created",
            description: "Alberta and Saskatchewan were carved out of the Northwest Territories and admitted as the 8th and 9th provinces, reflecting the rapid settlement of the prairies.",
            icon: "leaf.arrow.circlepath",
            era: .confederationEra
        ),

        // MARK: World Wars
        CanadianHistoryEvent(
            id: 18,
            year: "1914-1918",
            title: "World War I & Vimy Ridge",
            description: "Canadian forces fought with distinction, particularly at Vimy Ridge (1917) where all four Canadian divisions fought together for the first time. The war effort helped Canada gain greater autonomy from Britain.",
            icon: "shield.checkered",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 19,
            year: "1918",
            title: "Women's Suffrage",
            description: "Most Canadian women gained the right to vote in federal elections, though Indigenous women and some others were excluded until later decades.",
            icon: "person.2.fill",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 20,
            year: "1919",
            title: "Winnipeg General Strike",
            description: "Over 30,000 workers walked off the job in one of the most significant labour actions in Canadian history. The six-week strike was a defining moment for the Canadian labour movement and workers' rights.",
            icon: "hand.raised.fill",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 21,
            year: "1929",
            title: "Persons Case",
            description: "The Famous Five — five Alberta women — won a landmark legal victory when the Privy Council ruled that women were indeed 'persons' under the law, eligible for appointment to the Senate.",
            icon: "figure.dress.line.vertical.figure",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 22,
            year: "1931",
            title: "Statute of Westminster",
            description: "Canada gained legislative independence from Britain, becoming a fully sovereign nation in matters of domestic and foreign affairs.",
            icon: "scroll.fill",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 23,
            year: "1939-1945",
            title: "World War II",
            description: "Over one million Canadians served in the armed forces. Canada played pivotal roles at Juno Beach on D-Day, the liberation of the Netherlands, and the Battle of the Atlantic.",
            icon: "airplane",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 24,
            year: "1942",
            title: "Japanese Canadian Internment",
            description: "Following the attack on Pearl Harbor, over 22,000 Japanese Canadians were forcibly relocated from the BC coast to internment camps. Their property was confiscated and sold. Canada formally apologized and provided redress in 1988.",
            icon: "exclamationmark.triangle.fill",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 25,
            year: "1944",
            title: "D-Day — Juno Beach",
            description: "On June 6, 1944, Canadian forces stormed Juno Beach in Normandy, France. Despite fierce resistance, they advanced further inland than any other Allied force on D-Day.",
            icon: "flag.checkered",
            era: .worldWars
        ),

        // MARK: Modern Canada
        CanadianHistoryEvent(
            id: 26,
            year: "1949",
            title: "Newfoundland Joins Confederation",
            description: "After a close referendum, Newfoundland became Canada's 10th province, completing the country's Atlantic coast.",
            icon: "map.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 27,
            year: "1960",
            title: "Indigenous Right to Vote",
            description: "First Nations people gained the unconditional right to vote in federal elections without having to give up their treaty rights or Indian status.",
            icon: "hand.thumbsup.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 28,
            year: "1965",
            title: "The Maple Leaf Flag",
            description: "Canada adopted its iconic red and white maple leaf flag, replacing the Red Ensign and establishing a distinct national symbol.",
            icon: "leaf.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 29,
            year: "1967",
            title: "Expo 67 & Centennial",
            description: "Montreal hosted Expo 67, a World's Fair celebrating Canada's 100th birthday. The event drew over 50 million visitors and showcased Canada as a modern, cosmopolitan nation on the world stage.",
            icon: "globe.desk.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 30,
            year: "1969",
            title: "Official Languages Act",
            description: "English and French were declared Canada's two official languages, reflecting the country's bilingual heritage and Québécois identity.",
            icon: "text.bubble.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 31,
            year: "1970",
            title: "October Crisis",
            description: "The FLQ kidnapped a British diplomat and a Quebec cabinet minister, prompting Prime Minister Trudeau to invoke the War Measures Act — the only peacetime use of emergency powers in Canadian history.",
            icon: "exclamationmark.octagon.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 32,
            year: "1980",
            title: "First Quebec Referendum",
            description: "Quebecers voted 60% to 40% against sovereignty-association in a referendum organized by Premier René Lévesque's Parti Québécois government.",
            icon: "checkmark.rectangle.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 33,
            year: "1982",
            title: "Constitution Act & Charter of Rights",
            description: "Pierre Trudeau patriated the Constitution from Britain and enshrined the Canadian Charter of Rights and Freedoms, guaranteeing fundamental rights for all Canadians.",
            icon: "text.book.closed.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 34,
            year: "1988",
            title: "Multiculturalism Act",
            description: "Canada became the first country in the world to pass a national multiculturalism law, officially recognizing and promoting the cultural diversity of Canadian society.",
            icon: "person.3.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 35,
            year: "1995",
            title: "Second Quebec Referendum",
            description: "Quebec held a second sovereignty referendum. The result was razor-thin — 50.58% voted No, 49.42% voted Yes — keeping Canada united by the narrowest of margins.",
            icon: "chart.bar.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 36,
            year: "1999",
            title: "Creation of Nunavut",
            description: "Canada's newest territory was carved from the Northwest Territories, providing self-governance for the Inuit people of the eastern Arctic.",
            icon: "globe.americas.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 37,
            year: "2005",
            title: "Same-Sex Marriage Legalized",
            description: "Canada became the fourth country in the world to legalize same-sex marriage nationwide through the Civil Marriage Act, advancing equality rights under the Charter.",
            icon: "heart.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 38,
            year: "2008",
            title: "Residential Schools Apology",
            description: "Prime Minister Stephen Harper issued a formal apology in the House of Commons for the government's role in the Indian residential school system, which forcibly separated Indigenous children from their families for over a century.",
            icon: "person.crop.circle.badge.exclamationmark.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 39,
            year: "2010",
            title: "Vancouver Winter Olympics",
            description: "Vancouver and Whistler hosted the Winter Olympics. Canada won a record 14 gold medals, including Sidney Crosby's iconic overtime goal in men's hockey — a defining national moment.",
            icon: "medal.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 40,
            year: "2015",
            title: "Truth & Reconciliation Commission",
            description: "The TRC released its final report with 94 Calls to Action addressing the legacy of residential schools. The report declared the system a cultural genocide and called on all Canadians to work toward reconciliation.",
            icon: "hand.point.up.left.and.text.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 41,
            year: "2017",
            title: "Canada 150",
            description: "Canada celebrated its 150th anniversary of Confederation with nationwide events, though the celebrations also prompted important conversations about Indigenous rights and the country's colonial history.",
            icon: "party.popper.fill",
            era: .modernCanada
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    eraLegend
                    timelineContent
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Canadian History Timeline")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Major events that shaped Canada")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Era Legend

    private var eraLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HistoricalEra.allCases, id: \.rawValue) { era in
                    eraTag(era)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }

    private func eraTag(_ era: HistoricalEra) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(era.color)
                .frame(width: 8, height: 8)
            Text(era.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        ZStack(alignment: .leading) {
            // Vertical connecting line with gradient
            timelineLine

            // Event cards
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    timelineEventRow(event: event, index: index)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Timeline Line

    private var timelineLine: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [.blue, .purple, .red, .green],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .padding(.leading, 19)
        }
    }

    // MARK: - Event Row

    private func timelineEventRow(event: CanadianHistoryEvent, index: Int) -> some View {
        let isExpanded = expandedEvents.contains(event.id)

        return HStack(alignment: .top, spacing: 16) {
            // Circle node on the line
            timelineNode(event: event)

            // Event card
            eventCard(event: event, isExpanded: isExpanded)
        }
        .padding(.bottom, 20)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 30)
        .animation(
            .spring(duration: 0.6, bounce: 0.3).delay(Double(index) * 0.05),
            value: appeared
        )
        .onAppear {
            if !appeared {
                withAnimation {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Timeline Node

    private func timelineNode(event: CanadianHistoryEvent) -> some View {
        ZStack {
            Circle()
                .fill(event.era.color.opacity(0.2))
                .frame(width: 40, height: 40)

            Circle()
                .fill(event.era.color)
                .frame(width: 16, height: 16)

            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Event Card

    private func eventCard(event: CanadianHistoryEvent, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Year and Icon row
            HStack(spacing: 8) {
                Text(event.year)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(event.era.color)

                Spacer()

                Image(systemName: event.icon)
                    .font(.title3)
                    .foregroundStyle(event.era.color)
                    .frame(width: 36, height: 36)
                    .background(event.era.color.opacity(0.12), in: Circle())
            }

            // Event title
            Text(event.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Era badge
            Text(event.era.rawValue)
                .font(.caption2.bold())
                .foregroundStyle(event.era.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(event.era.color.opacity(0.12), in: Capsule())

            // Expandable description
            if isExpanded {
                Text(event.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Expand / collapse indicator
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text(isExpanded ? "Show less" : "Read more")
                        .font(.caption)
                        .foregroundStyle(event.era.color)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(event.era.color)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(event.era.color.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                if expandedEvents.contains(event.id) {
                    expandedEvents.remove(event.id)
                } else {
                    expandedEvents.insert(event.id)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.year), \(event.title). \(event.era.rawValue) era.")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand and read more")
    }
}

// MARK: - Preview

#Preview {
    CanadianHistoryTimelineView()
}
