import SwiftUI

struct OfflineBannerView: View {
    let isConnected: Bool

    var body: some View {
        VStack {
            if !isConnected {
                banner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(duration: 0.5, bounce: 0.3), value: isConnected)
    }

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.pink)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.variableColor.iterative, options: .repeat(.continuous))

            Text("No internet connection")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            Circle()
                .fill(.pink.opacity(0.8))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(.pink.opacity(0.3))
                        .frame(width: 16, height: 16)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.clear)
                .glassEffect(.regular.tint(.pink), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview("Offline") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        OfflineBannerView(isConnected: false)
    }
}

#Preview("Online") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        OfflineBannerView(isConnected: true)
    }
}
