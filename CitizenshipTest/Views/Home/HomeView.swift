import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LegislatorStore.self) private var legislatorStore
    @Query private var settingsResults: [UserSettings]
    @State private var showResetAlert = false
    @State private var districtResolver = DistrictResolver()
    @State private var zipCode = ""
    @State private var isOfficialsExpanded = false
    @FocusState private var zipFocused: Bool

    private var settings: UserSettings {
        settingsResults.first ?? UserSettings()
    }

    private var selectedState: StateInfo? {
        statesData.first { $0.id == settings.selectedStateId }
    }

    private var displayPresident: String {
        legislatorStore.president ?? federalData.president
    }

    private var displayVicePresident: String {
        legislatorStore.vicePresident ?? federalData.vicePresident
    }

    /// Whether we have a resolved location (state derived from location/ZIP)
    private var hasResolvedLocation: Bool {
        districtResolver.resolvedState != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("CitizenReady")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("US Citizenship Test Prep")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let state = selectedState {
                        Text("\(state.name) Edition")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top)

                // Info banner
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("20 questions from 128 total. You need 12 correct to pass (60%).")
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Progress
                ProgressSummaryView()

                // Mode buttons
                VStack(spacing: 12) {
                    NavigationLink(value: AppDestination.flashcards) {
                        ModeButton(icon: "rectangle.stack.fill", title: "Study Flashcards", subtitle: "Review all 128 questions", color: .blue)
                    }

                    NavigationLink(value: AppDestination.practiceTest) {
                        ModeButton(icon: "pencil.and.list.clipboard", title: "Practice Test", subtitle: "Simulate the real 20-question test", color: .green)
                    }

                    NavigationLink(value: AppDestination.review) {
                        ModeButton(icon: "list.bullet.rectangle", title: "Review All Questions", subtitle: "Browse questions by category", color: .purple)
                    }
                }

                // Unified location & officials card
                locationAndOfficialsCard

                // Reset
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
                .padding(.top)
                .alert("Reset Progress?", isPresented: $showResetAlert) {
                    Button("Reset", role: .destructive) {
                        ProgressTracker.resetProgress(context: modelContext)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will clear all your study progress.")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .onAppear {
            _ = ensureSettings()
            deduplicateOnLaunch()
        }
    }

    // MARK: - Unified Location & Officials Card

    @ViewBuilder
    private var locationAndOfficialsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $isOfficialsExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    if hasResolvedLocation {
                        // Location is resolved — show state & district inline
                        resolvedLocationSection

                        HStack {
                            Spacer()
                            Button {
                                clearLocation()
                            } label: {
                                Label("Change Location", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                            }
                        }
                    } else {
                        // No location yet — show location finder + state fallback
                        locationFinderSection
                    }

                    Divider()

                    // Officials
                    federalRow("President", displayPresident)
                    federalRow("Vice President", displayVicePresident)
                    federalRow("Speaker of the House", federalData.speakerOfHouse)
                    federalRow("Chief Justice", federalData.chiefJustice)

                    if let state = selectedState {
                        Divider()
                        federalRow("Governor", state.governor)
                        federalRow("Capital", state.capital)
                        let senators = legislatorStore.senatorsForState(state.id)
                        ForEach(senators, id: \.self) { senator in
                            federalRow("Senator", senator)
                        }
                        if let district = settings.selectedDistrict,
                           let rep = legislatorStore.representativeForDistrict(state: state.id, district: district) {
                            federalRow("Representative", rep)
                        } else {
                            HStack {
                                Text("Representative")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 140, alignment: .leading)
                                Text("Use location or ZIP above to find yours")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .italic()
                                Spacer()
                            }
                        }
                    }

                    // Last updated
                    Divider()
                    lastUpdatedRow
                }
                .padding(.top, 12)
            } label: {
                Label("Your Location & Officials", systemImage: "person.3.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Resolved Location (compact display)

    @ViewBuilder
    private var resolvedLocationSection: some View {
        if let stateCode = districtResolver.resolvedState,
           let state = statesData.first(where: { $0.id == stateCode }) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let district = districtResolver.resolvedDistrict {
                        Text(district == 0 ? "At-Large District" : "District \(district)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Location Finder (before resolved)

    @ViewBuilder
    private var locationFinderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find your representatives by location or ZIP code")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    Task { await resolveLocation() }
                } label: {
                    HStack(spacing: 4) {
                        if districtResolver.isResolving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.caption)
                        }
                        Text("Use My Location")
                            .font(.caption)
                    }
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(districtResolver.isResolving)

                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("ZIP", text: $zipCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .font(.caption)
                    .focused($zipFocused)

                Button("Go") {
                    zipFocused = false
                    Task { await resolveZIP() }
                }
                .font(.caption)
                .fontWeight(.medium)
                .disabled(!isValidZIP(zipCode) || districtResolver.isResolving)
            }

            if districtResolver.locationPermissionDenied {
                Text("Location access denied. Use ZIP code instead.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let error = districtResolver.error, !districtResolver.locationPermissionDenied {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Manual state picker as fallback
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Text("Or select state manually")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("State", selection: Binding(
                    get: { settings.selectedStateId },
                    set: { newValue in
                        ensureSettings().selectedStateId = newValue
                        try? modelContext.save()
                    }
                )) {
                    ForEach(statesData) { state in
                        Text(state.name).tag(state.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Last Updated Row

    @ViewBuilder
    private var lastUpdatedRow: some View {
        HStack {
            if legislatorStore.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Updating...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let date = legislatorStore.lastRefreshed {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Updated \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "tray.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Using bundled data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task {
                    await legislatorStore.refreshIfNeeded()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .disabled(legislatorStore.isLoading)
        }

        if let error = legislatorStore.loadError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Actions

    private func resolveLocation() async {
        await districtResolver.resolveFromLocation(using: legislatorStore)
        applyResolvedState()
    }

    private func resolveZIP() async {
        await districtResolver.resolveFromZIP(zipCode, using: legislatorStore)
        applyResolvedState()
    }

    /// After location/ZIP resolves, auto-set the state and district
    private func applyResolvedState() {
        guard let stateCode = districtResolver.resolvedState else { return }
        let s = ensureSettings()
        s.selectedStateId = stateCode
        s.selectedDistrict = districtResolver.resolvedDistrict
        s.districtResolutionMethod = "location"
        try? modelContext.save()
    }

    private func clearLocation() {
        districtResolver.clear()
        let s = ensureSettings()
        s.selectedDistrict = nil
        s.districtResolutionMethod = nil
        try? modelContext.save()
        zipCode = ""
    }

    // MARK: - Validation

    private func isValidZIP(_ zip: String) -> Bool {
        zip.count == 5 && zip.allSatisfy(\.isNumber)
    }

    // MARK: - Helpers

    @discardableResult
    private func ensureSettings() -> UserSettings {
        if let existing = settingsResults.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    private func deduplicateOnLaunch() {
        let all = ProgressTracker.fetchAll(context: modelContext)
        _ = ProgressTracker.deduplicate(all, context: modelContext)
        try? modelContext.save()
    }

    private func federalRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

private struct ModeButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

enum AppDestination: Hashable {
    case flashcards
    case flashcardsReview
    case practiceTest
    case review
}
