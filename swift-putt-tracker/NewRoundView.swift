import SwiftUI
import SwiftData

struct NewRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var roundDate: Date = .now
    @State private var golfClubName: String = ""
    @State private var courseName: String = ""
    @State private var numberOfHoles: Int = 9
    @State private var teeColour: TeeColour = .green
    @State private var weather: WeatherCondition = .sunny
    @State private var wind: WindCondition = .calm

    @State private var activeRound: Round?

    private var trimmedClubName: String { golfClubName.trimmingCharacters(in: .whitespaces) }
    private var trimmedCourseName: String { courseName.trimmingCharacters(in: .whitespaces) }

    private var canBeginRound: Bool {
        !trimmedClubName.isEmpty && !trimmedCourseName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Round Details") {
                    DatePicker("Date", selection: $roundDate, displayedComponents: .date)

                    TextField("Golf Club Name", text: $golfClubName)
                    TextField("Course Name", text: $courseName)

                    Picker("Holes", selection: $numberOfHoles) {
                        Text("9").tag(9)
                        Text("18").tag(18)
                    }
                    .pickerStyle(.segmented)

                    Picker("Tee Colour", selection: $teeColour) {
                        ForEach(TeeColour.allCases) { tee in
                            Label {
                                Text(tee.rawValue)
                            } icon: {
                                Circle()
                                    .fill(tee.color)
                                    .overlay(Circle().strokeBorder(.secondary, lineWidth: tee == .white ? 1 : 0))
                                    .frame(width: 16, height: 16)
                            }
                            .tag(tee)
                        }
                    }
                }

                Section("Conditions") {
                    Picker("Weather", selection: $weather) {
                        ForEach(WeatherCondition.allCases) { condition in
                            Label(condition.rawValue, systemImage: condition.systemImage)
                                .tag(condition)
                        }
                    }

                    Picker("Wind", selection: $wind) {
                        ForEach(WindCondition.allCases) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                }

                Section {
                    Button("Begin Round") {
                        startRound()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fontWeight(.semibold)
                    .disabled(!canBeginRound)

                    if !canBeginRound {
                        Text("Golf club name and course name are required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            date: roundDate,
            golfClubName: trimmedClubName,
            courseName: trimmedCourseName,
            teeColour: teeColour,
            weather: weather.rawValue,
            wind: wind.rawValue,
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
