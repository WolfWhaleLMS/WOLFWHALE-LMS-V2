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
        CanadianHistoryEvent(
            id: 1,
            year: "1534",
            title: "Jacques Cartier Explores Canada",
            description: "French explorer Jacques Cartier made three voyages to Canada, claiming the land for France. He explored the St. Lawrence River and established contact with Indigenous peoples.",
            icon: "sailboat.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 2,
            year: "1608",
            title: "Founding of Quebec City",
            description: "Samuel de Champlain founded Quebec City, establishing the first permanent French settlement in North America and the capital of New France.",
            icon: "building.columns.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 3,
            year: "1763",
            title: "Treaty of Paris",
            description: "France ceded New France to Britain after the Seven Years' War. This marked the beginning of British rule in Canada.",
            icon: "doc.text.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 4,
            year: "1812",
            title: "War of 1812",
            description: "Canada (as British North America) defended against American invasion. The war helped forge a distinct Canadian identity and strengthened ties with Britain.",
            icon: "shield.fill",
            era: .preConfederation
        ),
        CanadianHistoryEvent(
            id: 5,
            year: "1867",
            title: "Confederation",
            description: "The British North America Act united Ontario, Quebec, Nova Scotia, and New Brunswick into the Dominion of Canada on July 1st. Sir John A. Macdonald became the first Prime Minister.",
            icon: "star.fill",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 6,
            year: "1869",
            title: "Red River Rebellion",
            description: "Led by Louis Riel, the M\u{00E9}tis people of the Red River Colony resisted Canadian authority, leading to the creation of Manitoba as a province in 1870.",
            icon: "flag.fill",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 7,
            year: "1885",
            title: "Last Spike / CPR Completion",
            description: "The Canadian Pacific Railway was completed at Craigellachie, BC, connecting Canada from coast to coast and fulfilling a key promise of Confederation.",
            icon: "tram.fill",
            era: .confederationEra
        ),
        CanadianHistoryEvent(
            id: 8,
            year: "1914-1918",
            title: "World War I & Vimy Ridge",
            description: "Canadian forces fought with distinction, particularly at Vimy Ridge (1917). The war effort helped Canada gain greater autonomy from Britain.",
            icon: "shield.checkered",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 9,
            year: "1918",
            title: "Women's Suffrage",
            description: "Most Canadian women gained the right to vote in federal elections, though Indigenous women and some others were excluded until later decades.",
            icon: "person.2.fill",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 10,
            year: "1931",
            title: "Statute of Westminster",
            description: "Canada gained legislative independence from Britain, becoming a fully sovereign nation in matters of domestic and foreign affairs.",
            icon: "scroll.fill",
            era: .worldWars
        ),
        CanadianHistoryEvent(
            id: 11,
            year: "1949",
            title: "Newfoundland Joins Confederation",
            description: "After a close referendum, Newfoundland became Canada's 10th province, completing the country's Atlantic coast.",
            icon: "map.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 12,
            year: "1965",
            title: "The Maple Leaf Flag",
            description: "Canada adopted its iconic red and white maple leaf flag, replacing the Red Ensign and establishing a distinct national symbol.",
            icon: "leaf.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 13,
            year: "1969",
            title: "Official Languages Act",
            description: "English and French were declared Canada's two official languages, reflecting the country's bilingual heritage and Qu\u{00E9}b\u{00E9}cois identity.",
            icon: "text.bubble.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 14,
            year: "1982",
            title: "Constitution Act & Charter of Rights",
            description: "Pierre Trudeau patriated the Constitution from Britain and enshrined the Canadian Charter of Rights and Freedoms.",
            icon: "text.book.closed.fill",
            era: .modernCanada
        ),
        CanadianHistoryEvent(
            id: 15,
            year: "1999",
            title: "Creation of Nunavut",
            description: "Canada's newest territory was carved from the Northwest Territories, providing self-governance for the Inuit people of the eastern Arctic.",
            icon: "globe.americas.fill",
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
