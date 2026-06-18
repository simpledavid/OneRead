# One Read

A native SwiftUI iOS app that helps CET-4-level learners study English through
two high-quality AI and major technology stories each day.

## What is built

- Morning (07:00) and afternoon (16:00) editorial editions; notifications are currently hidden
- Included Easy (~100 words, A2-B1), Standard (~150 words, B1-B2), and Original reading modes
- Platform-generated vocabulary supports tap-to-translate lookup without colored word highlighting
- Live RSS fetching from AI-focused news sources, with local fallback content
- Source weighting plus optional LLM editorial scoring for the strongest candidates
- Human review gate that publishes exactly two diverse stories
- Article detail pages with source, summary, key points, and original-link handoff
- Article library with category filters and search
- Saved articles, daily completion, streaks, and retention-event tracking
- Optional personal API key only for rewriting extra library articles

## Daily content service

The app reads approved editions from a static JSON endpoint. Set
`ONE_READ_CONTENT_BASE_URL` in the target Info.plist or the launch environment.
The client requests `YYYY-MM-DD.json`, then `latest.json`; without a configured
endpoint it loads a bundled approved preview edition.

Use the two-stage editorial CLI described in
[`content/README.md`](content/README.md) to prepare five candidates and publish
two human-selected stories. Any static host or CDN can serve the output.

Set `ONE_READ_ANALYTICS_URL` to an optional event collector. If it is absent,
events remain queued on device and the profile still shows local streak,
completion, active-day, and quiz metrics.

## Open

Open `OneRead.xcodeproj` in Xcode and run the `OneRead` scheme on an iPhone simulator.

If command-line scheme destinations are unavailable because no iOS Simulator Runtime is installed locally, the target can still be compiled with:

```sh
xcodebuild -project OneRead.xcodeproj -target OneRead -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project OneRead.xcodeproj -target OneRead -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

## Architecture

- `Models`: `Article`, category, and per-article vocabulary types
- `Data`: article store and persistence (`ArticleStore`, `StoreServices`,
  `ArticleDatabase`), RSS fetching and parsing (`FeedService`,
  `FeedConfiguration`, `FeedChannels`, `FeedSupport`, `ArticleRSSParser`,
  `StringHTML`), and local fallback content (`SampleArticles`)
- `Services`: daily content and curation (`DailyContentService`,
  `ArticleCurationService`), reading-level rewriting (`ArticleLevelService`),
  dictionary and glossary lookup (`NativeDictionaryService`, `DomainGlossary`,
  `WordEnrichmentService`), notifications, and speech
- `Views`: SwiftUI screens (root, article list/reading, profile, shared components)
- `Components`: shared visual helpers and reusable controls
- `Resources`: bundled dictionary (`ecdict.sqlite`), domain glossary, and feed source list
- `content` + `scripts/content_pipeline.py`: server-side generation and editorial review workflow
