# One Read

A native SwiftUI iOS app that recommends three recent AI news articles each day.

## What is built

- Daily feed with three latest AI news recommendations
- Live RSS fetching from AI-focused news sources, with local fallback content
- Article detail pages with source, summary, key points, and original-link handoff
- Article library with category filters and search
- Saved articles and read-state tracking

## Open

Open `OneRead.xcodeproj` in Xcode and run the `OneRead` scheme on an iPhone simulator.

If command-line scheme destinations are unavailable because no iOS Simulator Runtime is installed locally, the target can still be compiled with:

```sh
xcodebuild -project OneRead.xcodeproj -target OneRead -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project OneRead.xcodeproj -target OneRead -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

## Architecture

- `Models`: article, category, and legacy vocabulary types
- `Data`: RSS-backed article state, local fallback articles, and legacy word data
- `Services`: local notification helpers and legacy speech service
- `Views`: SwiftUI screens
- `Components`: shared visual helpers and reusable controls
