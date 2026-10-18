import SwiftUI
import SwiftData

/// v2 Phase 1: captures the information needed to plan a round before it's played.
/// Creates or edits a `RoundPlan`, independent of the v1 `Round`/`HoleScore` schema.
struct RoundPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingPlan: RoundPlan?

    /// The single "Holes" choice shown to the user, mapped onto the stored
    /// `numberOfHoles` + `nineHoleSide` fields.
    private enum HoleChoice: String, CaseIterable, Identifiable {
        case front9 = "Front 9"
        case back9 = "Back 9"
        case thirteen = "13"
        case eighteen = "18"

        var id: String { rawValue }

        init(numberOfHoles: Int, nineHoleSide: String) {
            switch numberOfHoles {
            case 13: self = .thirteen
            case 18: self = .eighteen
            default: self = nineHoleSide == NineHoleSide.back.rawValue ? .back9 : .front9
            }
        }

        var numberOfHoles: Int {
            switch self {
            case .front9, .back9: return 9
            case .thirteen: return 13
            case .eighteen: return 18
            }
        }

        var nineHoleSide: NineHoleSide {
            self == .back9 ? .back : .front
        }
    }

    private enum Field { case club, course }
    // Shared by both layouts so focus survives when the row switches between one and two lines.
    @FocusState private var focusedField: Field?

    @State private var golfClubName: String
    @State private var courseName: String
    @State private var holeChoice: HoleChoice
    @State private var plannedTeeTime: Date
    @State private var teeTimeBooked: Bool
    @State private var players: [String]
    @State private var newPlayerName: String = ""
    @State private var partnersInformed: Bool
    @State private var calendarUpdated: Bool

    init(existingPlan: RoundPlan? = nil) {
        self.existingPlan = existingPlan
        _golfClubName = State(initialValue: existingPlan?.golfClubName ?? "Clandeboye")
        _courseName = State(initialValue: existingPlan?.courseName ?? "AVA")
        _holeChoice = State(initialValue: existingPlan.map { HoleChoice(numberOfHoles: $0.numberOfHoles, nineHoleSide: $0.nineHoleSide) } ?? .front9)
        _plannedTeeTime = State(initialValue: existingPlan?.plannedTeeTime ?? .now)
        _teeTimeBooked = State(initialValue: existingPlan?.teeTimeBooked ?? false)
        _players = State(initialValue: existingPlan?.players ?? [])
        _partnersInformed = State(initialValue: existingPlan?.partnersInformed ?? false)
        _calendarUpdated = State(initialValue: existingPlan?.calendarUpdated ?? false)
    }

    private var trimmedClubName: String { golfClubName.trimmingCharacters(in: .whitespaces) }
    private var trimmedCourseName: String { courseName.trimmingCharacters(in: .whitespaces) }
    private var trimmedPlayerName: String { newPlayerName.trimmingCharacters(in: .whitespaces) }

    private var canSave: Bool {
        !trimmedClubName.isEmpty && !trimmedCourseName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // One line while both names fit; stacks onto two lines when they get too long.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Text("Club:")
                            sizedToText(golfClubName, placeholder: "Golf club") {
                                TextField("Golf club", text: $golfClubName)
                                    .focused($focusedField, equals: .club)
                            }
                            Divider()
                            Text("Course:")
                            sizedToText(courseName, placeholder: "Golf course") {
                                TextField("Golf course", text: $courseName)
                                    .focused($focusedField, equals: .course)
                            }
                            Spacer(minLength: 0)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Text("Club:")
                                TextField("Golf club", text: $golfClubName)
                                    .focused($focusedField, equals: .club)
                            }
                            Divider()
                            HStack(spacing: 12) {
                                Text("Course:")
                                TextField("Golf course", text: $courseName)
                                    .focused($focusedField, equals: .course)
                            }
                        }
                    }
                } footer: {
                    if !canSave {
                        Text("Golf club name and course name are required.")
                    }
                }

                Section("Holes") {
                    Picker("Holes", selection: $holeChoice) {
                        ForEach(HoleChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tee Time") {
                    DatePicker("Planned", selection: $plannedTeeTime)
                    Toggle("Booked", isOn: $teeTimeBooked)
                }

                Section("Players") {
                    ForEach(players, id: \.self) { player in
                        Label(player, systemImage: "person.fill")
                    }
                    .onDelete { offsets in players.remove(atOffsets: offsets) }

                    HStack {
                        TextField("Add player name", text: $newPlayerName)
                            .submitLabel(.done)
                            .onSubmit(addPlayer)
                        Button("Add", action: addPlayer)
                            .disabled(trimmedPlayerName.isEmpty)
                    }
                }

                Section("Checklist") {
                    Toggle("Partners informed", isOn: $partnersInformed)
                    Toggle("Calendar updated", isOn: $calendarUpdated)
                }
            }
            .navigationTitle(existingPlan == nil ? "Plan a Round" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingPlan == nil ? "Save" : "Update") { savePlan() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    /// A text field that is only as wide as its text, so `ViewThatFits` can tell when the
    /// one-line layout no longer fits. (A bare TextField has no content-based ideal width.)
    private func sizedToText<Field: View>(_ text: String, placeholder: String, @ViewBuilder field: () -> Field) -> some View {
        Text(text.isEmpty ? placeholder : text)
            .lineLimit(1)
            .padding(.trailing, 8)   // room for the cursor
            .hidden()
            .overlay(field())
    }

    private func addPlayer() {
        guard !trimmedPlayerName.isEmpty else { return }
        players.append(trimmedPlayerName)
        newPlayerName = ""
    }

    private func savePlan() {
        if let plan = existingPlan {
            plan.golfClubName = trimmedClubName
            plan.courseName = trimmedCourseName
            plan.numberOfHoles = holeChoice.numberOfHoles
            plan.nineHoleSide = holeChoice.nineHoleSide.rawValue
            plan.plannedTeeTime = plannedTeeTime
            plan.teeTimeBooked = teeTimeBooked
            plan.players = players
            plan.partnersInformed = partnersInformed
            plan.calendarUpdated = calendarUpdated
        } else {
            let plan = RoundPlan(
                golfClubName: trimmedClubName,
                courseName: trimmedCourseName,
                numberOfHoles: holeChoice.numberOfHoles,
                nineHoleSide: holeChoice.nineHoleSide,
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
