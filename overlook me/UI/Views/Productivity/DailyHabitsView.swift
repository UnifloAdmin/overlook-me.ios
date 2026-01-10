import SwiftUI

struct DailyHabitsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .ignoresSafeArea()

            header
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                Spacer()
            }
            .overlay {
                Text("Habits")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider()
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .top)
    }
}
