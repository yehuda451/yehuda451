import SwiftUI

struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streak > 0 ? .orange : .secondary)
            Text("\(streak)")
                .font(.headline)
                .foregroundStyle(streak > 0 ? .primary : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(streak > 0 ? 0.15 : 0.08), in: Capsule())
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b: UInt64
        if cleaned.count == 6 {
            r = (value >> 16) & 0xFF
            g = (value >> 8) & 0xFF
            b = value & 0xFF
        } else {
            r = 52; g = 120; b = 246
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

/// A row of tappable day-of-week circles, shared by the reminders screen
/// and the session editor's day scheduler.
struct WeekdayTogglesRow: View {
    @Binding var selection: Set<Weekday>
    var tint: Color = .accentColor

    var body: some View {
        HStack {
            ForEach(Weekday.allCases) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(day.shortLabel.prefix(1))
                        .font(.caption.bold())
                        .frame(width: 32, height: 32)
                        .background(isOn ? tint : Color.clear, in: Circle())
                        .foregroundStyle(isOn ? .white : .primary)
                        .overlay(Circle().strokeBorder(.quaternary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A curated palette so the session editor doesn't need a full color picker.
enum SessionColor: String, CaseIterable, Identifiable {
    case blue = "3478F6"
    case orange = "FF9500"
    case green = "34C759"
    case purple = "AF52DE"
    case red = "FF3B30"
    case teal = "30B0C7"

    var id: String { rawValue }
    var color: Color { Color(hex: rawValue) }
}
