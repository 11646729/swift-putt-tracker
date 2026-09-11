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
        ScrollView {
        VStack(spacing: 20) {
            Text("Hole \(currentHole.holeNumber) of \(round.numberOfHoles)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            ProgressView(value: Double(currentHoleIndex + 1), total: Double(round.numberOfHoles))
                .padding(.horizontal)

            Text("\(currentHole.totalPutts)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text("putts this hole")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            VStack(spacing: 14) {
                ForEach(PuttBin.allCases) { bin in
                    PuttBinRow(
                        bin: bin,
                        count: currentHole.count(for: bin),
                        onIncrement: { currentHole.increment(bin) },
                        onDecrement: { currentHole.decrement(bin) }
                    )
                }

                Toggle("Used putter off the green", isOn: Binding(
                    get: { currentHole.usedPutterOffGreen },
                    set: { currentHole.usedPutterOffGreen = $0 }
                ))
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)

            Spacer(minLength: 24)

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
        }
        .navigationTitle(round.golfClubName.isEmpty ? "Active Round" : round.golfClubName)
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

/// One row of the putt entry UI: a distance bin label, its current count, and +/- buttons.
private struct PuttBinRow: View {
    let bin: PuttBin
    let count: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack {
            Text(bin.rawValue)
                .font(.headline)
                .frame(width: 90, alignment: .leading)

            Spacer()

            Button(action: onDecrement) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(count == 0)

            Text("\(count)")
                .font(.title2.bold())
                .frame(width: 40)
                .contentTransition(.numericText())

            Button(action: onIncrement) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
            }
        }
        .foregroundStyle(.primary)
        .tint(.green)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    let round = Round(golfClubName: "Preview Club", courseName: "Preview Course", numberOfHoles: 9)
    for i in 1...9 { round.holes.append(HoleScore(holeNumber: i)) }
    return NavigationStack {
        ActiveRoundView(round: round, onFinish: {})
    }
    .modelContainer(for: [Round.self, HoleScore.self], inMemory: true)
}
