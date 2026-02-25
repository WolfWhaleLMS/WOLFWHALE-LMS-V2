import SwiftUI

/// A tamagotchi-style study pet that grows with student activity.
/// Designed to work both as an inline view and as a WidgetKit widget.
struct StudyPetWidget: View {
    let petName: String
    let petLevel: Int
    let petMood: PetMood
    let streak: Int
    let lastStudyDate: Date?

    enum PetMood: String {
        case happy, neutral, sad, sleeping, excited

        var emoji: String {
            switch self {
            case .happy: return "happy"
            case .neutral: return "neutral"
            case .sad: return "sad"
            case .sleeping: return "sleeping"
            case .excited: return "excited"
            }
        }

        var petImage: String {
            switch self {
            case .happy: return "face.smiling.fill"
            case .neutral: return "face.dashed"
            case .sad: return "cloud.rain.fill"
            case .sleeping: return "moon.zzz.fill"
            case .excited: return "star.fill"
            }
        }

        var backgroundColor: [Color] {
            switch self {
            case .happy: return [.green, .teal]
            case .neutral: return [.blue, .cyan]
            case .sad: return [.gray, .blue]
            case .sleeping: return [.indigo, .purple]
            case .excited: return [.orange, .yellow]
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Pet avatar area - animated creature
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: petMood.backgroundColor, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: petMood.petImage)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5))
            }

            // Pet name and level
            Text(petName)
                .font(.headline)

            Text("Level \(petLevel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Stats row
            HStack(spacing: 16) {
                Label("\(streak) day streak", systemImage: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            // Mood message
            Text(moodMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }

    private var moodMessage: String {
        switch petMood {
        case .happy: return "I'm happy! Keep studying!"
        case .neutral: return "Let's do some work today!"
        case .sad: return "I miss you... come study!"
        case .sleeping: return "Zzz... wake me for class"
        case .excited: return "Amazing streak! You're on fire!"
        }
    }
}
