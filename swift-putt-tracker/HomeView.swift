import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.date, order: .reverse) private var rounds: [Round]

    @State private var showingNewRoundSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "flag.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("Putt Tracker")
                        .font(.largeTitle.bold())
                }
                .padding(.top, 32)

                Button {
                    showingNewRoundSheet = true
                } label: {
                    Label("Start New Round", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                if rounds.isEmpty {
                    Spacer()
                    Text("No rounds yet.\nStart a round to begin tracking your putts.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        Section("Recent Rounds") {
                            ForEach(rounds.prefix(5)) { round in
                                NavigationLink {
                                    RoundSummaryView(round: round, isReadOnly: true)
                                } label: {
                                    RoundRow(round: round)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)

                    NavigationLink("View Full History") {
                        HistoryView()
                    }
                    .padding(.bottom)
                }
            }
            .sheet(isPresented: $showingNewRoundSheet) {
                NewRoundView()
            }
        }
    }
}

struct RoundRow: View {
    let round: Round

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(round.golfClubName.isEmpty ? "Round" : round.golfClubName)
                    .font(.headline)
                Text(round.courseName.isEmpty ? round.date.formatted(date: .abbreviated, time: .omitted) : "\(round.courseName) · \(round.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(round.totalPutts)")
                    .font(.title3.bold())
                Text("putts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Round.self, HoleScore.self], inMemory: true)
}
