import SwiftUI
import SwiftData

/// v2 Phase 1: captures the information needed to plan a round before it's played.
/// Creates or edits a `RoundPlan`, independent of the v1 `Round`/`HoleScore` schema.
struct RoundPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingPlan: RoundPlan?

    @State private var golfClubName: String
    @State private var numberOfHoles: Int
    @State private var plannedTeeTime: Date
    @State private var teeTimeBooked: Bool
    @State private var players: [String]
    @State private var newPlayerName: String = ""
    @State private var partnersInformed: Bool
    @State private var calendarUpdated: Bool

    init(existingPlan: RoundPlan? = nil) {
        self.existingPlan = existingPlan
        _golfClubName = State(initialValue: existingPlan?.golfClubName ?? "")
        _numberOfHoles = State(initialValue: existingPlan?.numberOfHoles ?? 9)
        _plannedTeeTime = State(initialValue: existingPlan?.plannedTeeTime ?? .now)
        _teeTimeBooked = State(initialValue: existingPlan?.teeTimeBooked ?? false)
        _players = State(initialValue: existingPlan?.players ?? [])
        _partnersInformed = State(initialValue: existingPlan?.partnersInformed ?? false)
        _calendarUpdated = State(initialValue: existingPlan?.calendarUpdated ?? false)
    }

    private var trimmedClubName: String { golfClubName.trimmingCharacters(in: .whitespaces) }
    private var trimmedPlayerName: String { newPlayerName.trimmingCharacters(in: .whitespaces) }

    private var canSave: Bool {
        !trimmedClubName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Round Details") {
                    TextField("Golf Club Name", text: $golfClubName)

                    Picker("Holes", selection: $numberOfHoles) {
                        Text("9").tag(9)
                        Text("13").tag(13)
                        Text("18").tag(18)
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Planned Tee Time", selection: $plannedTeeTime)

                    Toggle("Tee time booked", isOn: $teeTimeBooked)
                }

                Section("Players") {
                    ForEach(players, id: \.self) { player in
                        Text(player)
                    }
                    .onDelete { offsets in players.remove(atOffsets: offsets) }

                    HStack {
                        TextField("Add player name", text: $newPlayerName)
                        Button("Add") {
                            guard !trimmedPlayerName.isEmpty else { return }
                            players.append(trimmedPlayerName)
                            newPlayerName = ""
                        }
                        .disabled(trimmedPlayerName.isEmpty)
                    }
                }

                Section("Checklist") {
                    Toggle("Golfing partners informed", isOn: $partnersInformed)
                    Toggle("Calendar updated", isOn: $calendarUpdated)
                }

                Section {
                    Button(existingPlan == nil ? "Save Plan" : "Update Plan") {
                        savePlan()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .navigationTitle(existingPlan == nil ? "Plan a Round" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func savePlan() {
        if let plan = existingPlan {
            plan.golfClubName = trimmedClubName
            plan.numberOfHoles = numberOfHoles
            plan.plannedTeeTime = plannedTeeTime
            plan.teeTimeBooked = teeTimeBooked
            plan.players = players
            plan.partnersInformed = partnersInformed
            plan.calendarUpdated = calendarUpdated
        } else {
            let plan = RoundPlan(
                golfClubName: trimmedClubName,
                numberOfHoles: numberOfHoles,
                plannedTeeTime: plannedTeeTime,
                teeTimeBooked: teeTimeBooked,
                players: players,
                partnersInformed: partnersInformed,
                calendarUpdated: calendarUpdated
            )
            modelContext.insert(plan)
        }
        dismiss()
    }
}

#Preview {
    RoundPlanView()
        .modelContainer(for: [Round.self, HoleScore.self, RoundPlan.self], inMemory: true)
}
