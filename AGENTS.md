# Repository Guidelines

## Project Structure & Module Organization

`FamilyDuty/` contains the SwiftUI application. Keep domain models in `FamilyDuty/Models/`, reusable business logic and persistence helpers in `FamilyDuty/Services/`, and screen-specific code under `FamilyDuty/Features/<FeatureName>/`. Application entry points and root navigation remain at the top level of `FamilyDuty/`. Unit tests mirror these areas in `FamilyDutyTests/`; simulator-driven flows belong in `FamilyDutyUITests/`. Project generation settings live in `project.yml`, while implementation specifications are stored in `docs/plans/`.

## Build, Test, and Development Commands

- `xcodegen generate` regenerates `FamilyDuty.xcodeproj` from `project.yml` after targets or source groups change.
- `open FamilyDuty.xcodeproj` opens the project for local development and simulator debugging.
- `xcodebuild -project FamilyDuty.xcodeproj -target FamilyDuty -sdk iphonesimulator build` performs a command-line simulator build.
- `xcodebuild test -project FamilyDuty.xcodeproj -scheme FamilyDutyTests -destination 'platform=iOS Simulator,name=iPad (10th generation)'` runs unit and UI tests. Substitute an installed iPad simulator when necessary.

## Coding Style & Naming Conventions

Use four-space indentation and standard Swift naming: `UpperCamelCase` for types and filenames, `lowerCamelCase` for methods and properties, and descriptive enum cases. Keep each file focused on its primary type. Prefer small SwiftUI views and dependency-injected services; date-sensitive logic should accept a `Calendar` rather than rely on global device state. Follow Xcode formatting and remove warnings before review.

## Testing Guidelines

Tests use XCTest. Name test files `*Tests.swift` and methods with behavior-focused names such as `testAssigneeRotatesEachWeekFromStartWeek`. Add focused coverage for model relationships, scheduling edge cases, and view-model state changes. Put end-to-end interactions and accessibility identifiers in `FamilyDutyUITests/`. Run the full shared scheme before opening a pull request.

## Commit & Pull Request Guidelines

Git history is not available in this checkout. Use concise, imperative commits with prefixes already referenced in project plans, such as `feat:`, `fix:`, `test:`, or `docs:`. Pull requests should explain the user-visible change, list verification performed, and link relevant issues. Include iPad screenshots for visual changes and note behavior in both portrait and landscape orientations.

## Security & Configuration Tips

The app targets iPadOS 17 and stores family data locally with SwiftData. Do not commit credentials, personal test data, provisioning profiles, or user-specific Xcode settings. Keep bundle and deployment changes centralized in `project.yml`.
