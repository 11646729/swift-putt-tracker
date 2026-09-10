import SwiftUI
import SwiftData

struct ActiveRoundView: View {
    @Bindable var round: Round
    var onFinish: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var currentHoleIndex = 0
    @State private var showingFinishConfirmation = false
    @State private var summaryRound: Round?

    private var sortedHoles: [HoleScore] {
        round.holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    private var currentHole: HoleScore {
        sortedHoles[currentHoleIndex]
    }

    private var isLastHole: Bool {
        currentHoleIndex == sortedHoles.count - 1
    }

    var body: some View {
        VStack(spacing: 32) {
            Text("Hole \(currentHole.holeNumber) of \(round.numberOfHoles)")
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(currentHoleIndex + 1), total: Double(round.numberOfHoles))
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Text("Putts")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("\(currentHole.putts)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                HStack(spacing: 40) {
                    Button {
                        if currentHole.putts > 0 { currentHole.putts -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 48))
                    }
                    .disabled(currentHole.putts == 0)

                    Button {
                        currentHole.putts += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                    }
                }
                .foregroundStyle(.green)
            }

            Spacer()

            Text("Round total: \(round.totalPutts) putts")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    goToPreviousHole()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(currentHoleIndex == 0)

                Button {
                    if isLastHole {
                        showingFinishConfirmation = true
                    } else {
                        goToNextHole()
                    }
                } label: {
                    Label(isLastHole ? "Finish Round" : "Next Hole", systemImage: isLastHole ? "checkmark.circle" : "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle(round.courseName?.isEmpty == false ? round.courseName! : "Active Round")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .confirmationDialog(
            "Finish this round?",
            isPresented: $showingFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button("Finish Round") {
                summaryRound = round
            }
            Button("Keep Playing", role: .cancel) {}
        }
        .navigationDestination(item: $summaryRound) { round in
            RoundSummaryView(round: round, isReadOnly: false, onDone: onFinish)
        }
    }

    private func goToNextHole() {
        withAnimation { currentHoleIndex = min(currentHoleIndex + 1, sortedHoles.count - 1) }
    }

    private func goToPreviousHole() {
        withAnimation { currentHoleIndex = max(currentHoleIndex - 1, 0) }
    }
}

#Preview {
    let round = Round(courseName: "Preview Course", numberOfHoles: 9)
    for i in 1...9 { round.holes.append(HoleScore(holeNumber: i)) }
    return NavigationStack {
        ActiveRoundView(round: round, onFinish: {})
    }
    .modelContainer(for: [Round.self, HoleScore.self], inMemory: true)
}
