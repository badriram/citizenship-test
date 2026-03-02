# Citizenship Test App

iOS app to study for the US citizenship naturalization test. 128 USCIS civics questions with flashcards, practice tests, and progress tracking.

## Build & Run

```bash
# Regenerate Xcode project from project.yml (requires xcodegen)
xcodegen generate

# Build
xcodebuild -project CitizenshipTest.xcodeproj -scheme CitizenshipTest -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- Requires Xcode 16+ with iOS 17+ SDK
- No external dependencies — uses only Apple frameworks (SwiftUI, SwiftData, NaturalLanguage, CoreLocation)
- CloudKit/iCloud sync is enabled via entitlements

## Architecture

**Pattern:** MVVM with `@Observable` and SwiftData. No third-party packages.

### Directory Structure

```
CitizenshipTest/
├── CitizenshipTestApp.swift     # Entry point, injects LegislatorStore via .environment()
├── ContentView.swift            # NavigationStack with AppDestination routing
├── Models/
│   ├── Question.swift           # Question struct + StateAnswerKey enum + answersForState overloads
│   ├── UserSettings.swift       # @Model — selectedStateId, selectedDistrict, districtResolutionMethod
│   ├── QuestionProgress.swift   # @Model — study progress per question (status, streak, etc.)
│   ├── Category.swift           # QuestionCategory enum (10 categories)
│   ├── StateInfo.swift          # State struct (id, name, capital, governor, senators)
│   ├── FederalInfo.swift        # Federal officials struct
│   ├── Legislator.swift         # Codable structs for congress-legislators JSON
│   └── Executive.swift          # Codable structs for executive.json
├── Data/
│   ├── QuestionsData.swift      # 128 hardcoded USCIS questions
│   ├── StatesData.swift         # 50 states + DC with governors, capitals, senators (fallback data)
│   └── FederalData.swift        # Hardcoded president, VP, speaker, chief justice
├── Services/
│   ├── LegislatorStore.swift    # @Observable — loads/caches/refreshes legislator data from GitHub
│   ├── DistrictResolver.swift   # @Observable — CoreLocation + Census Geocoder API for district lookup
│   ├── AnswerMatcher.swift      # Fuzzy answer matching (stop words, stem matching, abbreviations)
│   ├── SemanticMatcher.swift    # NLEmbedding cosine similarity matching (threshold 0.70)
│   ├── QuizEngine.swift         # @Observable — 20-question practice test engine
│   └── ProgressTracker.swift    # SwiftData CRUD for QuestionProgress
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift       # Main screen — location, officials, study mode buttons
│   │   ├── DistrictSelectorView.swift  # (unused — inlined into HomeView)
│   │   ├── StateSelectorView.swift     # (unused — inlined into HomeView)
│   │   └── ProgressSummaryView.swift   # Studied/Mastered/Review counts via @Query
│   ├── Flashcards/              # Flashcard study mode with flip animation
│   ├── PracticeTest/            # 20-question timed test with results review
│   ├── Review/                  # Browse all 128 questions by category
│   └── Components/              # CategoryFilterView, InfoCardView
├── Extensions/
│   └── String+FuzzyMatch.swift  # normalized(), words(), levenshteinDistance(), extractCapitalizedNames()
└── Resources/
    ├── Assets.xcassets
    ├── legislators-current.json # Bundled snapshot from congress-legislators (538 records)
    └── executive.json           # Bundled snapshot from congress-legislators
```

## Key Design Decisions

### Live Legislator Data
- **Offline-first**: Bundled JSON loads synchronously at app launch. Network refresh is async background.
- **Fallback chain**: Network → Disk cache (Caches/) → Bundle → StatesData.swift (hardcoded)
- **Staleness**: Refreshes from GitHub if >14 days since last fetch
- **Sources**: `unitedstates.github.io/congress-legislators/legislators-current.json` and `executive.json`
- **Governor/Speaker/Chief Justice**: Stay hardcoded (not in congress-legislators data)

### Answer Matching (OR logic)
Answers are accepted if EITHER matcher succeeds:
1. **Fuzzy matcher** (fast) — stop-word-filtered content word overlap, stem-aware prefix matching (5+ chars), abbreviation expansion, name extraction
2. **Semantic matcher** (NLEmbedding) — `NLEmbedding.sentenceEmbedding` cosine similarity ≥ 0.70, skips short/numeric answers

### District Resolution
- Primary: CoreLocation → Census Geocoder coordinate API (`geocoding.geo.census.gov`)
- Fallback: ZIP code → CLGeocoder → coordinates → Census API
- Census API returns district key dynamically (e.g. "119th Congressional Districts") — parser finds key by substring match
- Auto-sets state from resolved location

### State-Specific Questions
Questions with `stateSpecific` key (`.senators`, `.governor`, `.capital`, `.representative`) resolve answers via:
- `answersForState(_:legislators:district:)` — prefers live LegislatorStore data, falls back to StatesData

## Things to Watch

- `DistrictSelectorView.swift` and `StateSelectorView.swift` exist as files but are unused (their functionality is inlined into HomeView)
- `UserSettings` is a SwiftData `@Model` with CloudKit sync — schema changes need migration consideration
- Census Geocoder API is free/no-key but the congressional district key name changes each Congress session (handled by dynamic key lookup)
- `NLEmbedding.sentenceEmbedding(for: .english)` returns nil on some simulators — semantic matcher gracefully returns false, fuzzy still works
- The `project.yml` excludes `Resources/*.json` from sources but includes them explicitly as resources (prevents Xcode from compiling JSON as Swift)
