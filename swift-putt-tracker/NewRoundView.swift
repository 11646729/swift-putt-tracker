import SwiftUI
import SwiftData

struct NewRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var courseName: String = ""
    @State private var numberOfHoles: Int = 18
    @State private var activeRound: Round?

    var body: some View {
        NavigationStack {
            Form {
                Section("Round Details") {
                    TextField("Course Name (optional)", text: $courseName)

                    Picker("Holes", selection: $numberOfHoles) {
                        Text("9").tag(9)
                        Text("18").tag(18)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Begin Round") {
                        startRound()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $activeRound) { round in
                ActiveRoundView(round: round, onFinish: { dismiss() })
            }
        }
    }

    private func startRound() {
        let round = Round(
            courseName: courseName.trimmingCharacters(in: .whitespaces),
            numberOfHoles: numberOfHoles
        )
        for holeNumber in 1...numberOfHoles {
            round.holes.append(HoleScore(holeNumber: holeNumber))
        }
        modelContext.insert(round)
        activeRound = round
    }
}

#Preview {
    NewRoundView()
        .modelContainer(for: [Round.self, HoleScore.self], inMemory: true)
}
