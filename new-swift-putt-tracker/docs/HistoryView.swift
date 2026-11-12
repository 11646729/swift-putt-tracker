import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Round.date, order: .reverse) private var rounds: [Round]
    @Environment(\.modelContext) private var modelContext

    private var overallAveragePutts: Double {
        guard !rounds.isEmpty else { return 0 }
        let total = rounds.map(\.totalPutts).reduce(0, +)
        return Double(total) / Double(rounds.count)
    }

    private var overallAveragePerHole: Double {
        let allHoles = rounds.flatMap { $0.holes }
        guard !allHoles.isEmpty else { return 0 }
        let total = allHoles.map(\.totalPutts).reduce(0, +)
        return Double(total) / Double(allHoles.count)
    }

    var body: some View {
        List {
            if !rounds.isEmpty {
                Section("Overall Stats") {
                    HStack {
                        Text("Rounds Played")
                        Spacer()
                        Text("\(rounds.count)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Avg Putts / Round")
                        Spacer()
                        Text(String(format: "%.1f", overallAveragePutts)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Avg Putts / Hole")
                        Spacer()
                        Text(String(format: "%.2f", overallAveragePerHole)).foregroundStyle(.secondary)
                    }
                }
            }

            Section("All Rounds") {
                if rounds.isEmpty {
                    Text("No rounds recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rounds) { round in
                        NavigationLink(value: round) {
                            RoundRow(round: round)
                        }
                    }
                    .onDelete(perform: deleteRounds)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .navigationDestination(for: Round.self) { round in
            RoundSummaryView(round: round, isReadOnly: true)
        }
        .toolbar {
            if !rounds.isEmpty {
                EditButton()
            }
        }
    }

    private func deleteRounds(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rounds[index])
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: [Round.self, HoleScore.self], inMemory: true)
}
