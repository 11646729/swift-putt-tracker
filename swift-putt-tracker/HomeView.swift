import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Round.date, order: .reverse) private var rounds: [Round]
    @Query(sort: \RoundPlan.plannedTeeTime) private var plans: [RoundPlan]

    @State private var showingNewRoundSheet = false
    @State private var showingNewPlanSheet = false
    @State private var editingPlan: RoundPlan?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "flag.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("Putt Tracker")
                        .font(.largeTitle.bold())
                }
                .padding(.top, 32)

                Button {
                    showingNewPlanSheet = true
                } label: {
                    Label("Plan a Round", systemImage: "calendar.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Button {
                    showingNewRoundSheet = true
                } label: {
                    Label("Start New Round", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                if !plans.isEmpty {
                    List {
                        Section("Upcoming Plans") {
                            ForEach(plans) { plan in
                                Button {
                                    editingPlan = plan
                                } label: {
                                    PlanRow(plan: plan)
                                }
                                .tint(.primary)
                            }
                            .onDelete(perform: deletePlans)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .frame(maxHeight: 220)
                }

                if rounds.isEmpty {
                    Spacer()
                    Text("No rounds yet.\nStart a round to begin tracking your putts.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        Section("Recent Rounds") {
                            ForEach(rounds.prefix(5)) { round in
                                NavigationLink {
                                    RoundSummaryView(round: round, isReadOnly: true)
                                } label: {
                                    RoundRow(round: round)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)

                    NavigationLink("View Full History") {
                        HistoryView()
                    }
                    .padding(.bottom)
                }
            }
            .sheet(isPresented: $showingNewRoundSheet) {
                NewRoundView()
            }
            .sheet(isPresented: $showingNewPlanSheet) {
                RoundPlanView()
            }
            .sheet(item: $editingPlan) { plan in
                RoundPlanView(existingPlan: plan)
            }
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
    }
}

struct RoundRow: View {
    let round: Round

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(round.golfClubName.isEmpty ? "Round" : round.golfClubName)
                    .font(.headline)
                Text(round.courseName.isEmpty ? round.date.formatted(date: .abbreviated, time: .omitted) : "\(round.courseName) · \(round.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(round.totalPutts)")
                    .font(.title3.bold())
                Text("putts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PlanRow: View {
    let plan: RoundPlan

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(plan.golfClubName.isEmpty ? "Round Plan" : plan.golfClubName)
                    .font(.headline)
                Text(plan.courseName.isEmpty
                     ? plan.plannedTeeTime.formatted(date: .abbreviated, time: .shortened)
                     : "\(plan.courseName) · \(plan.plannedTeeTime.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: plan.isReadyToPlay ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(plan.isReadyToPlay ? .green : .secondary)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Round.self, HoleScore.self, RoundPlan.self], inMemory: true)
}
