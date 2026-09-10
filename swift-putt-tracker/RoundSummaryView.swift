import SwiftUI
import SwiftData

struct RoundSummaryView: View {
    let round: Round
    var isReadOnly: Bool
    var onDone: (() -> Void)? = nil

    private var sortedHoles: [HoleScore] {
        round.holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(round.courseName?.isEmpty == false ? round.courseName! : "Round Summary")
                    .font(.title2.bold())
                Text(round.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            HStack {
                StatBox(title: "Total Putts", value: "\(round.totalPutts)")
                StatBox(title: "Holes", value: "\(round.numberOfHoles)")
                StatBox(title: "Avg / Hole", value: String(format: "%.1f", round.averagePuttsPerHole))
            }
            .padding(.horizontal)

            List {
                Section("Hole by Hole") {
                    ForEach(sortedHoles) { hole in
                        HStack {
                            Text("Hole \(hole.holeNumber)")
                            Spacer()
                            Text("\(hole.putts) putt\(hole.putts == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            if !isReadOnly {
                Button {
                    onDone?()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .navigationTitle(isReadOnly ? "Round Detail" : "Round Complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!isReadOnly)
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let round = Round(courseName: "Preview Course", numberOfHoles: 9)
    for i in 1...9 { round.holes.append(HoleScore(holeNumber: i, putts: Int.random(in: 1...3))) }
    return NavigationStack {
        RoundSummaryView(round: round, isReadOnly: true)
    }
}
