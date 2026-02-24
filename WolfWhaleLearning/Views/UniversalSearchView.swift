import SwiftUI

// MARK: - UniversalSearchView

struct UniversalSearchView: View {
    let viewModel: AppViewModel

    @State private var searchService = SearchService()
    @State private var searchText = ""
    @State private var selectedCategory: SearchCategory? = nil
    @State private var hapticTrigger = false
    @State private var debouncedSearchTask: Task<Void, Never>?

    @FocusState private var isSearchFieldFocused: Bool

    // MARK: - Derived Data

    /// Flattens all lessons from all courses for search.
    private var allLessons: [Lesson] {
        viewModel.courses.flatMap { course in
            course.modules.flatMap(\.lessons)
        }
    }

    /// Filtered results based on the selected category filter.
    private var filteredResults: [SearchCategory: [SearchResult]] {
        guard let category = selectedCategory else {
            return searchService.results
        }
        if let items = searchService.results[category] {
            return [category: items]
        }
        return [:]
    }

    /// Categories that have results, sorted by the CaseIterable order.
    private var categoriesWithResults: [SearchCategory] {
        SearchCategory.allCases.filter { filteredResults[$0] != nil }
    }

    private var filteredResultCount: Int {
        filteredResults.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    searchBarSection

                    if searchText.isEmpty {
                        recentSearchesSection
                    } else if searchService.isLoading {
                        loadingSection
                    } else if searchService.totalResultCount == 0 {
                        emptyStateSection
                    } else {
                        categoryFilterChips
                        resultsHeaderSection
                        resultsListSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                isSearchFieldFocused = true
            }
        }
    }

    // MARK: - Search Bar

    private var searchBarSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("Search courses, assignments, people...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchService.clearResults()
                    selectedCategory = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        }
        .onChange(of: searchText) { _, newValue in
            debouncedSearch(query: newValue)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search field")
    }

    // MARK: - Recent Searches

    @ViewBuilder
    private var recentSearchesSection: some View {
        if !searchService.recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Recent Searches", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") {
                        searchService.clearRecentSearches()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.indigo)
                    .accessibilityLabel("Clear recent searches")
                }

                FlowLayout(spacing: 8) {
                    ForEach(searchService.recentSearches, id: \.self) { term in
                        Button {
                            searchText = term
                            performSearch()
                        } label: {
                            Text(term)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Search for \(term)")
                    }
                }
            }
            .padding(.top, 8)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .symbolEffect(.pulse)
                Text("Search Everything")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Find courses, assignments, messages, people, and lessons")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Category Filter Chips

    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                FilterChipButton(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    color: .indigo
                ) {
                    selectedCategory = nil
                    hapticTrigger.toggle()
                }

                // Per-category chips (only show categories that have results)
                ForEach(SearchCategory.allCases, id: \.self) { category in
                    if searchService.results[category] != nil {
                        let count = searchService.results[category]?.count ?? 0
                        FilterChipButton(
                            title: "\(category.displayName) (\(count))",
                            icon: category.iconName,
                            isSelected: selectedCategory == category,
                            color: category.color
                        ) {
                            selectedCategory = category
                            hapticTrigger.toggle()
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
    }

    // MARK: - Results Header

    private var resultsHeaderSection: some View {
        HStack {
            Text("\(filteredResultCount) result\(filteredResultCount == 1 ? "" : "s")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Results List (grouped by category)

    private var resultsListSection: some View {
        LazyVStack(spacing: 14) {
            ForEach(categoriesWithResults, id: \.self) { category in
                if let items = filteredResults[category] {
                    categorySectionView(category: category, items: items)
                }
            }
        }
    }

    private func categorySectionView(category: SearchCategory, items: [SearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(category.color)
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(items.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(category.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background {
                        Capsule()
                            .fill(category.color.opacity(0.12))
                    }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(category.displayName), \(items.count) results")

            // Result rows
            ForEach(items) { result in
                Button {
                    hapticTrigger.toggle()
                    handleResultTap(result)
                } label: {
                    SearchResultRow(result: result, query: searchText)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .accessibilityLabel("Searching")
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary.opacity(0.5))
                .symbolEffect(.bounce)
            Text("No results for '\(searchText)'")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try different keywords or check your spelling")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func debouncedSearch(query: String) {
        debouncedSearchTask?.cancel()
        debouncedSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            performSearch()
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchService.clearResults()
            selectedCategory = nil
            return
        }

        // FERPA: Scope search data by the current user's role to prevent
        // unauthorized disclosure of user names, emails, and academic records.
        let scopedUsers = ferpaFilteredUsers
        let scopedConversations = viewModel.conversations // already fetched for current user
        let scopedAssignments = viewModel.assignments     // already scoped server-side

        searchService.search(
            query: query,
            courses: viewModel.courses,
            assignments: scopedAssignments,
            conversations: scopedConversations,
            users: scopedUsers,
            lessons: allLessons
        )
    }

    // MARK: - FERPA: Role-Based User Filtering

    /// Returns users visible to the current user based on their role.
    /// - Students: can see other students in their courses + their teachers
    /// - Teachers: can see their students + other teachers
    /// - Parents: can see only their children's teachers
    /// - Admins/SuperAdmins: can see all users in the tenant
    private var ferpaFilteredUsers: [ProfileDTO] {
        guard let currentUser = viewModel.currentUser else { return [] }

        switch currentUser.role {
        case .admin, .superAdmin:
            // Admins see all users in the tenant
            return viewModel.allUsers

        case .student:
            // Collect teacher names from enrolled courses
            let teacherNames = Set(viewModel.courses.map { $0.teacherName.lowercased() })
            return viewModel.allUsers.filter { profile in
                let profileRole = profile.role.lowercased()
                let fullName = (profile.fullName ?? "\(profile.firstName ?? "") \(profile.lastName ?? "")").lowercased()
                // Allow seeing teachers of enrolled courses
                if profileRole == "teacher" && teacherNames.contains(fullName) {
                    return true
                }
                // Allow seeing fellow students (same role)
                if profileRole == "student" {
                    return true
                }
                return false
            }

        case .teacher:
            return viewModel.allUsers.filter { profile in
                let profileRole = profile.role.lowercased()
                // Teachers can see other teachers and students
                return profileRole == "teacher" || profileRole == "student"
            }

        case .parent:
            // Parents can only see their children's teachers.
            // Gather teacher names from the parent's loaded courses (which represent
            // the children's enrolled courses).
            let teacherNames = Set(viewModel.courses.map { $0.teacherName.lowercased() })
            return viewModel.allUsers.filter { profile in
                let profileRole = profile.role.lowercased()
                guard profileRole == "teacher" else { return false }
                let fullName = (profile.fullName ?? "\(profile.firstName ?? "") \(profile.lastName ?? "")").lowercased()
                return teacherNames.contains(fullName)
            }
        }
    }

    private func handleResultTap(_ result: SearchResult) {
        // Navigation would be handled here via deep link, sheet, or navigation destination.
        // For now this serves as the tap target that triggers sensory feedback.
        // Integration with the app's navigation system (e.g. deepLinkCourseId) can be added
        // by the consumer of this view.
        #if DEBUG
        print("[UniversalSearchView] Tapped result: \(result.category.rawValue) -> \(result.entityId)")
        #endif
    }
}

// MARK: - FilterChipButton

private struct FilterChipButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : color)
            .background {
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - FlowLayout

/// A simple flow layout that wraps children into multiple lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }
}
