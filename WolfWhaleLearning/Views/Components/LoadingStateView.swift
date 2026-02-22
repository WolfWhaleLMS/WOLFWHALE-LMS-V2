import SwiftUI

struct LoadingStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

struct ShimmerLoadingView: View {
    @State private var isAnimating = false
    let rowCount: Int

    init(rowCount: Int = 3) {
        self.rowCount = rowCount
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rowCount, id: \.self) { _ in
                shimmerRow
            }
        }
    }

    private var shimmerRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.secondary.opacity(0.15))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.15))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.1))
                    .frame(height: 10)
                    .frame(maxWidth: 180)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
        .accessibilityHidden(true)
    }
}

// ErrorStateView has been moved to ErrorStateView.swift with async retry support.
