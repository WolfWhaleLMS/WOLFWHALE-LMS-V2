import SwiftUI

struct ARLibraryView: View {
    let viewModel: AppViewModel
    @State private var arViewModel = ARLibraryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                categoryFilter
                if arViewModel.searchText.isEmpty && arViewModel.selectedCategory == nil {
                    featuredSection
                }
                allResourcesSection
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AR Library")
        .searchable(text: $arViewModel.searchText, prompt: "Search models, topics, subjects...")
        .navigationDestination(for: ARResource.self) { resource in
            ARResourceDetailView(resource: resource, viewModel: viewModel)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                CompatMeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.5, 0.5], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ],
                    colors: [
                        .indigo, .purple, .blue,
                        .cyan, .mint, .teal,
                        .blue, .indigo, .purple
                    ]
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .frame(height: 180)

                VStack(spacing: 8) {
                    Image(systemName: "arkit")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("Augmented Reality")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Explore 3D models projected into your space")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(title: "All", icon: "square.grid.2x2.fill", isSelected: arViewModel.selectedCategory == nil) {
                    withAnimation(.spring(response: 0.3)) {
                        arViewModel.selectedCategory = nil
                    }
                }

                ForEach(ARResourceCategory.allCases, id: \.self) { category in
                    categoryChip(
                        title: category.rawValue,
                        icon: category.iconName,
                        isSelected: arViewModel.selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            arViewModel.selectedCategory = arViewModel.selectedCategory == category ? nil : category
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16)
    }

    private func categoryChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Experiences")
                .font(.title3.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(arViewModel.featuredResources) { resource in
                        NavigationLink(value: resource) {
                            featuredCard(resource)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 16)
        }
    }

    private func featuredCard(_ resource: ARResource) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.courseColor(resource.colorName).gradient)
                    .frame(width: 280, height: 160)

                VStack {
                    Image(systemName: resource.iconSystemName)
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(width: 280, height: 160)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arkit")
                            .font(.caption2)
                        Text("AR")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.25), in: Capsule())

                    Text(resource.title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(resource.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
            }
            .clipShape(.rect(cornerRadius: 20))
        }
    }

    private var allResourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(arViewModel.selectedCategory?.rawValue ?? "All Experiences")
                    .font(.title3.bold())
                Spacer()
                Text("\(arViewModel.filteredResources.count) model\(arViewModel.filteredResources.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if arViewModel.filteredResources.isEmpty {
                ContentUnavailableView(
                    "No AR Experiences",
                    systemImage: "arkit",
                    description: Text(arViewModel.searchText.isEmpty ? "New experiences coming soon!" : "Try a different search term")
                )
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(arViewModel.filteredResources) { resource in
                        NavigationLink(value: resource) {
                            resourceRow(resource)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func resourceRow(_ resource: ARResource) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.courseColor(resource.colorName).gradient)
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: resource.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(resource.title)
                    .font(.headline)

                Text(resource.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(Theme.courseColor(resource.colorName))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.courseColor(resource.colorName).opacity(0.12), in: Capsule())

                HStack(spacing: 12) {
                    Label("\(resource.estimatedDuration) min", systemImage: "clock")
                    Label("Grades \(resource.gradeLevel)", systemImage: "graduationcap")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arkit")
                .font(.title3)
                .foregroundStyle(Theme.courseColor(resource.colorName))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}
