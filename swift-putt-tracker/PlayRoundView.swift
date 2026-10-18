import SwiftUI
import SwiftData

/// v2 Phase 2: playing the round. A scorecard-style screen for recording hole-by-hole
/// par, score and putts (by distance bin), plus the competition type and conditions.
///
/// Opened for a `RoundPlan`. The first time, it creates the plan's `RoundPlay`; after that
/// it edits the saved one, so everything entered here persists.
struct PlayRoundView: View {
    let plan: RoundPlan
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let play = plan.play {
                PlayRoundContent(plan: plan, play: play)
            } else {
                Color.clear.onAppear(perform: startPlay)
            }
        }
        .navigationTitle("Playing the Round")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startPlay() {
        let play = RoundPlay()
        for number in plan.holeNumbers {
            play.holes.append(HolePlay(holeNumber: number))
        }
        modelContext.insert(play)
        plan.play = play
    }
}

private struct PlayRoundContent: View {
    let plan: RoundPlan
    @Bindable var play: RoundPlay

    @State private var selectedHole: Int?

    // MARK: Holes

    private var holes: [HolePlay] {
        play.holes.sorted { $0.holeNumber < $1.holeNumber }
    }

    /// The card is shown in blocks of up to 9 holes, like the Out / In halves of a paper card.
    private var blocks: [[HolePlay]] {
        let all = holes
        return stride(from: 0, to: all.count, by: 9).map {
            Array(all[$0..<min($0 + 9, all.count)])
        }
    }

    private var currentHole: HolePlay? {
        holes.first { $0.holeNumber == selectedHole } ?? holes.first
    }

    private func totalTitle(forBlock index: Int) -> String {
        guard blocks.count > 1 else { return "Tot" }
        return index == 0 ? "Out" : (index == 1 && blocks[1].count == 9 ? "In" : "Tot")
    }

    // MARK: Bindings

    private var competition: Binding<CompetitionFormat> {
        Binding(
            get: { CompetitionFormat(rawValue: play.competitionFormat) ?? .stableford },
            set: { play.competitionFormat = $0.rawValue }
        )
    }

    private var weather: Binding<WeatherCondition> {
        Binding(
            get: { WeatherCondition(rawValue: play.weather) ?? .sunny },
            set: { play.weather = $0.rawValue }
        )
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Competition", selection: competition) {
                    ForEach(CompetitionFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                headerCard
                scorecardCard
                if let hole = currentHole {
                    HoleEditorCard(hole: hole)
                }
                conditionsCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plan.golfClubName)
                    .font(.headline)
                Spacer()
                Text(plan.plannedTeeTime.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
            }
            HStack {
                Text(plan.courseName)
                Spacer()
                Text(holesDescription)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .card()
    }

    private var holesDescription: String {
        switch plan.numberOfHoles {
        case 13, 18: return "\(plan.numberOfHoles) holes"
        default: return plan.nineHoleSide
        }
    }

    // MARK: Scorecard

    private var scorecardCard: some View {
        VStack(spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                scoreBlock(block, totalTitle: totalTitle(forBlock: index))
            }

            Divider()

            HStack {
                summaryItem("Par", "\(play.totalPar)")
                summaryItem("Score", play.holes.contains { $0.score != nil } ? "\(play.totalScore)" : "–")
                summaryItem("Putts", play.totalPutts == 0 ? "–" : "\(play.totalPutts)")
            }
        }
        .card()
    }

    private func summaryItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreBlock(_ block: [HolePlay], totalTitle: String) -> some View {
        VStack(spacing: 8) {
            // Green hole-number header; tap a hole to edit it below.
            HStack(spacing: 0) {
                Text("Hole")
                    .frame(width: 44, alignment: .leading)
                ForEach(block) { hole in
                    Button {
                        selectedHole = hole.holeNumber
                    } label: {
                        Text("\(hole.holeNumber)")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                            .background(currentHole?.holeNumber == hole.holeNumber ? Color.white.opacity(0.3) : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text(totalTitle)
                    .frame(width: 38)
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.green, in: RoundedRectangle(cornerRadius: 10))

            cardRow("Par", block: block, cell: { Text("\($0.par)") }, total: {
                Text("\(block.map(\.par).reduce(0, +))")
            })

            cardRow("Score", block: block, cell: { hole in
                ScoreMark(score: hole.score, par: hole.par)
            }, total: {
                let scored = block.compactMap(\.score)
                Text(scored.isEmpty ? "–" : "\(scored.reduce(0, +))").bold()
            })

            cardRow("Putts", block: block, cell: { hole in
                Text(hole.totalPutts == 0 ? "–" : "\(hole.totalPutts)").foregroundStyle(.secondary)
            }, total: {
                let total = block.map(\.totalPutts).reduce(0, +)
                Text(total == 0 ? "–" : "\(total)")
            })
        }
    }

    private func cardRow<Cell: View, Total: View>(
        _ title: String,
        block: [HolePlay],
        @ViewBuilder cell: @escaping (HolePlay) -> Cell,
        @ViewBuilder total: () -> Total
    ) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.subheadline.bold())
                .frame(width: 44, alignment: .leading)
            ForEach(block) { hole in
                cell(hole).frame(maxWidth: .infinity)
            }
            total().frame(width: 38)
        }
        .font(.subheadline)
        .padding(.horizontal, 8)
    }

    // MARK: Conditions

    private var conditionsCard: some View {
        VStack(spacing: 12) {
            Text("Conditions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Weather", selection: weather) {
                ForEach(WeatherCondition.allCases) { condition in
                    Label(condition.rawValue, systemImage: condition.systemImage)
                        .tag(condition)
                }
            }

            Stepper("Temperature: \(play.temperature)°C", value: $play.temperature, in: -10...45)
        }
        .card()
    }
}

/// Edits one hole: par, score, and putts in each distance bin.
private struct HoleEditorCard: View {
    @Bindable var hole: HolePlay

    var body: some View {
        VStack(spacing: 12) {
            Text("Hole \(hole.holeNumber)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Stepper("Par: \(hole.par)", value: $hole.par, in: 3...6)

            Stepper("Score: \(hole.score.map(String.init) ?? "–")", value: Binding(
                get: { hole.score ?? hole.par },
                set: { hole.score = $0 }
            ), in: 1...12)

            Divider()

            ForEach(PuttBin.allCases) { bin in
                Stepper("Putts \(bin.rawValue): \(hole.count(for: bin))", value: Binding(
                    get: { hole.count(for: bin) },
                    set: { hole.setCount($0, for: bin) }
                ), in: 0...10)
            }
        }
        .card()
    }
}

/// Score cell styled like a paper card: circles for under par, squares for over par.
private struct ScoreMark: View {
    let score: Int?
    let par: Int

    var body: some View {
        if let score {
            let diff = score - par
            Text("\(score)")
                .font(.subheadline.bold())
                .foregroundStyle(diff == 0 ? Color.primary : .white)
                .frame(width: 26, height: 26)
                .background {
                    switch diff {
                    case ...(-2): Circle().fill(.orange)
                    case -1: Circle().fill(.red)
                    case 0: Color.clear
                    case 1: RoundedRectangle(cornerRadius: 4).fill(.blue.opacity(0.7))
                    default: RoundedRectangle(cornerRadius: 4).fill(.indigo)
                    }
                }
        } else {
            Text("–").foregroundStyle(.secondary)
        }
    }
}

private extension View {
    /// White rounded card used to group sections on the grouped background.
    func card() -> some View {
        padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("New play") {
    let container = try! ModelContainer(
        for: RoundPlan.self, RoundPlay.self, HolePlay.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let plan = RoundPlan(golfClubName: "Clandeboye", courseName: "AVA", numberOfHoles: 18)
    container.mainContext.insert(plan)
    return NavigationStack { PlayRoundView(plan: plan) }
        .modelContainer(container)
}

#Preview("With scores") {
    let container = try! ModelContainer(
        for: RoundPlan.self, RoundPlay.self, HolePlay.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let plan = RoundPlan(golfClubName: "Clandeboye", courseName: "AVA")
    let play = RoundPlay()
    let sample: [(par: Int, score: Int?)] = [(4, 3), (5, 5), (3, 3), (4, 6), (4, 8), (3, 2), (4, 5), (4, nil), (5, nil)]
    for (index, hole) in sample.enumerated() {
        let holePlay = HolePlay(holeNumber: index + 1, par: hole.par)
        holePlay.score = hole.score
        if hole.score != nil {
            holePlay.puttsShort = 1
            holePlay.puttsMid = index % 2
        }
        play.holes.append(holePlay)
    }
    container.mainContext.insert(plan)
    container.mainContext.insert(play)
    plan.play = play
    return NavigationStack { PlayRoundView(plan: plan) }
        .modelContainer(container)
}
