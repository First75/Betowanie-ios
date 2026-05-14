import SwiftUI

struct StatsBar: View {
    let position: Int
    let points: Int

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "medal")
                    .foregroundStyle(Color.terraTertiary)
                Text("Moja Pozycja:")
                    .font(.terraCaption())
                    .foregroundStyle(Color.terraTextSecondary)
                Text("\(position)")
                    .font(.terraLabel())
                    .foregroundStyle(Color.terraTextPrimary)
            }

            Spacer()

            HStack(spacing: 6) {
                Text("Suma Punktów:")
                    .font(.terraCaption())
                    .foregroundStyle(Color.terraTextSecondary)
                Text("\(points)")
                    .font(.terraLabel())
                    .foregroundStyle(Color.terraTextPrimary)
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.terraTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.terraPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
