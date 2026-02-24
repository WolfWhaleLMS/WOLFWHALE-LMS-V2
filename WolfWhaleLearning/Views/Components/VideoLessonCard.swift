import SwiftUI

struct VideoLessonCard: View {
    let lesson: Lesson
    let courseColor: Color
    let onTap: () -> Void

    @State private var progressService = VideoProgressService()
    @State private var hapticTrigger = false

    private var completionPercentage: Double {
        progressService.getCompletionPercentage(lessonId: lesson.id)
    }

    private var isWatched: Bool {
        progressService.isWatched(lessonId: lesson.id)
    }

    var body: some View {
        Button(action: {
            hapticTrigger.toggle()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                thumbnailSection
                detailsSection
            }
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        #if canImport(UIKit)
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Double tap to play video")
    }

    // MARK: - Thumbnail

    private var thumbnailSection: some View {
        ZStack {
            // Gradient placeholder thumbnail
            LinearGradient(
                colors: [courseColor, courseColor.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)
            .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16))

            // Play button overlay
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: isWatched ? "checkmark.circle.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(isWatched ? .green : .white)
                        .offset(x: isWatched ? 0 : 2) // optical centering for play icon
                }
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            // Watched badge
            if isWatched {
                VStack {
                    HStack {
                        Spacer()
                        Text("Watched")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green, in: .capsule)
                    }
                    Spacer()
                }
                .padding(10)
            }

            // Duration badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("\(lesson.duration) min")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: .capsule)
                }
                .padding(10)
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "play.rectangle.fill")
                    .font(.caption)
                    .foregroundStyle(courseColor)
                Text("Video")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(lesson.title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Completion progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(courseColor.opacity(0.15))
                            .frame(height: 4)

                        Capsule()
                            .fill(isWatched ? Color.green : courseColor)
                            .frame(
                                width: geometry.size.width * CGFloat(completionPercentage),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(progressLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .padding(12)
    }

    // MARK: - Helpers

    private var progressLabel: String {
        if isWatched {
            return "Complete"
        }
        let pct = Int(completionPercentage * 100)
        if pct == 0 {
            return "Not started"
        }
        return "\(pct)% watched"
    }

    private var accessibilityText: String {
        var parts = [lesson.title, "Video lesson", "\(lesson.duration) minutes"]
        if isWatched {
            parts.append("Watched")
        } else {
            let pct = Int(completionPercentage * 100)
            if pct > 0 {
                parts.append("\(pct) percent watched")
            }
        }
        return parts.joined(separator: ", ")
    }
}
