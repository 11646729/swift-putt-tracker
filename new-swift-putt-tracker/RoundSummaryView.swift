import SwiftUI
import SwiftData

struct RoundSummaryView: View {
    let round: Round
    var isReadOnly: Bool
    var onDone: (() -> Void)? = nil

    private var sortedHoles: [HoleScore] {
        round.holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    private var binTotals: (short: Int, mid: Int, long: Int) {
        (
            round.holes.map(\.puttsShort).reduce(0, +),
            round.holes.map(\.puttsMid).reduce(0, +),
            round.holes.map(\.puttsLong).reduce(0, +)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(round.golfClubName.isEmpty ? "Round Summary" : round.golfClubName)
                    .font(.title2.bold())
                if !round.courseName.isEmpty {
                    Text(round.courseName)
                        .font(.subheadline)
                }
                Text(round.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    if let tee = TeeColour(rawValue: round.teeColour) {
                        Label {
                            Text("\(tee.rawValue) Tees")
                        } icon: {
                            Circle()
                                .fill(tee.color)
                                .overlay(Circle().strokeBorder(.secondary, lineWidth: tee == .white ? 1 : 0))
                                .frame(width: 10, height: 10)
                        }
                    }
                    if let weather = round.weather {
                        Label(weather, systemImage: WeatherCondition(rawValue: weather)?.systemImage ?? "cloud")
                    }
                    if let wind = round.wind {
                        Label("\(wind) wind", systemImage: "wind")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            HStack {
                StatBox(title: "Total Putts", value: "\(round.totalPutts)")
                StatBox(title: "Holes", value: "\(round.numberOfHoles)")
                StatBox(title: "Avg / Hole", value: String(format: "%.1f", round.averagePuttsPerHole))
            }
            .padding(.horizontal)

            HStack {
                StatBox(title: "0–4 ft", value: "\(binTotals.short)")
                StatBox(title: "4–10 ft", value: "\(binTotals.mid)")
                StatBox(title: "10+ ft", value: "\(binTotals.long)")
            }
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                Section("Hole by Hole") {
                    ForEach(sortedHoles) { hole in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Hole \(hole.holeNumber)")
                                    .font(.subheadline.bold())
                                if hole.usedPutterOffGreen {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                                Text("\(hole.totalPutts) putt\(hole.totalPutts == 1 ? "" : "s")")
                                    .foregroundStyle(.secondary)
                            }
                            Text("0–4 ft: \(hole.puttsShort)  ·  4–10 ft: \(hole.puttsMid)  ·  10+ ft: \(hole.puttsLong)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if hole.usedPutterOffGreen {
                                Text("Used putter off the green")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 2)
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
    let round = Round(golfClubName: "Preview Club", courseName: "Preview Course", teeColour: .yellow, weather: "Sunny", wind: "Light", numberOfHoles: 9)
    for i in 1...9 {
        round.holes.append(
            HoleScore(holeNumber: i,
                      puttsShort: Int.random(in: 0...1),
                      puttsMid: Int.random(in: 0...1),
                      puttsLong: Int.random(in: 0...1),
                      usedPutterOffGreen: Bool.random())
        )
    }
    return NavigationStack {
        RoundSummaryView(round: round, isReadOnly: true)
    }
}
