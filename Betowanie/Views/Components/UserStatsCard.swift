import SwiftUI

/// Displays a user's stats — position, points, accuracy, points/game, and
/// missed bets. Reused by `ProfileView` and by user-detail sheets opened from
/// the ranking.
struct UserStatsCard: View {
    let stats: UserStats
    var title: String = "Statystyki"

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.terraTitle(18))
                .foregroundStyle(Color.terraTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                statTile(
                    title: "Pozycja",
                    value: stats.position == 0 ? "–" : "\(stats.position)",
                    icon: "medal"
                )
                statTile(
                    title: "Punkty",
                    value: "\(stats.totalPoints)",
                    icon: "star.fill"
                )
            }

            HStack(spacing: 12) {
                statTile(
                    title: "Trafność",
                    value: stats.totalSettledBets == 0 ? "–" : "\(Int((stats.accuracy * 100).rounded()))%",
                    subtitle: "\(stats.perfectScores)/\(stats.totalSettledBets)",
                    icon: "target"
                )
                statTile(
                    title: "Średnio/mecz",
                    value: stats.totalFinishedGames == 0 ? "–" : String(format: "%.1f", stats.pointsPerGame),
                    icon: "chart.line.uptrend.xyaxis"
                )
                statTile(
                    title: "Pominięte",
                    value: "\(stats.missedBets)",
                    icon: "exclamationmark.circle"
                )
            }
        }
    }

    private func statTile(title: String, value: String, subtitle: String? = nil, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.terraTertiary)
            Text(value)
                .font(.terraHeadline(20))
                .foregroundStyle(Color.terraTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // Always render the subtitle slot (hidden when absent) so all
            // tiles in the row stay the same height.
            Text(subtitle ?? " ")
                .font(.terraCaption(10))
                .foregroundStyle(Color.terraTextSecondary)
                .opacity(subtitle == nil ? 0 : 1)
            Text(title)
                .font(.terraCaption(11))
                .foregroundStyle(Color.terraTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color.terraCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
