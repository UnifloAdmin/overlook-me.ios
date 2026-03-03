import SwiftUI

struct HomeDashboardView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                greetingHeader
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                LazyVStack(spacing: 16) {
                    WeatherTile()

                    HStack(alignment: .top, spacing: 12) {
                        HabitsTile()
                        TasksTile()
                    }

                    BillsTile()

                    SleepTile()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.todayDateString.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(.tertiary)

            Text(viewModel.greeting)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

struct AdaptiveHomeDashboard: View {
    var body: some View {
        HomeDashboardView()
    }
}

#Preview {
    HomeDashboardView()
}
