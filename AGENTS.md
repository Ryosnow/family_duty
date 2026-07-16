# Repository Guidelines

## Project Overview

FamilyDuty is an offline, single-household iPad app built with SwiftUI, SwiftData, UserNotifications, and Swift Charts. The app targets iPadOS 17 and stores members, rotation rules, task instances, and completion records in the local SwiftData container.

The user-facing areas are:

- `首页`: overdue, today, later-this-week, temporary, and recent-completion sections.
- `任务面板`: today’s pending, completed, and cancelled tasks plus today’s workload summary.
- `报表`: day, week, and month completion counts, scores, and week/month daily trends.
- `轮班`: recurring rules, participant order, enable/disable state, and one-off task adjustments.
- `设置`: family members and local notification settings.

Keep the product’s current scope local and offline. Do not introduce login, cloud sync, server APIs, or remote analytics without an explicit product decision.

## Project Structure & Module Organization

`FamilyDuty/` contains the SwiftUI application:

- `FamilyDuty/Models/` contains SwiftData models and the `TaskStatus` value type. Keep persistence fields and relationships here.
- `FamilyDuty/Services/` contains reusable domain logic and side effects, including rotation calculation, task generation, completion, member deletion protection, deadline validation, model-container creation, and notification scheduling.
- `FamilyDuty/Features/<FeatureName>/` contains screen-specific views and ViewModels for Dashboard, TaskBoard, Reports, Rotation, Settings, Setup, and Tasks.
- `FamilyDuty/DesignSystem/` contains shared colors, spacing, card styling, typography, and reusable SwiftUI components.
- `FamilyDuty/AppRootView.swift` and `FamilyDuty/FamilyDutyApp.swift` contain app startup, onboarding branching, primary navigation, SwiftData setup, UI-test seeding, and notification refresh wiring.

`FamilyDutyMiniProgram/` contains the native offline WeChat Mini Program:

- `miniprogram/domain/` mirrors the Swift models and reusable business rules in TypeScript.
- `miniprogram/data/` owns versioned local-storage snapshots and iPad-compatible backup conversion.
- `miniprogram/pages/` and `components/` contain WXML/WXSS presentation and interactions.
- `tests/` contains Vitest coverage for domain rules, rollback, backup compatibility, and storage recovery.

Tests mirror the application areas:

- `FamilyDutyTests/` contains XCTest coverage for models, services, ViewModels, persistence, scheduling, notifications, reports, and validation.
- `FamilyDutyUITests/` contains simulator-driven flows, onboarding coverage, accessibility checks, and visual interaction coverage.
- `docs/plans/` contains implementation specifications and design decisions.
- `project.yml` is the source of truth for XcodeGen project settings. `FamilyDuty.xcodeproj` is generated output.

## Architecture and Domain Rules

Use SwiftUI views for presentation and keep reusable business rules in services or testable ViewModels. Inject `Calendar`, dates, model contexts, and notification clients where date-sensitive or side-effecting logic needs deterministic tests.

Important invariants:

- `ChoreRule` describes a recurring rule; `ChoreTask` describes one concrete occurrence. `TaskGenerationService` may create tasks from rules, but a temporary task must not have a rule or affect rotation.
- `RotationScheduler` calculates an assignee from the rule’s start week and persisted `participantOrder`. Do not rely on the incidental order of the SwiftData relationship array.
- A one-off reassignment, reschedule, cancellation, adjustment note, or deadline change updates only the task instance. It must not mutate the rule or alter future rotation weeks.
- A task with no explicit `deadline` uses its `scheduledDate` as the effective deadline. A deadline before the scheduled date is invalid. Only pending tasks can be overdue.
- Completing a task creates a `CompletionRecord` with the actual completer, completion time, scheduled work date, and task score. Keep the completer-name snapshot so historical records remain readable after member deletion.
- Reports deduplicate records by task and calculate member completion counts and scores for day, week, or month periods. Changes to score semantics require corresponding ViewModel and service tests.
- Notification scheduling is local and managed by `NotificationScheduler`. Task or notification-setting changes must refresh the managed daily-summary and overdue-summary requests without affecting unrelated system notifications.
- Member deletion must preserve historical completion information and must not leave active rules or pending tasks with an invalid relationship. Use `MemberDeletionService` instead of deleting a member directly from a view.

## Build, Test, and Development Commands

After changing targets, source groups, build settings, or schemes, regenerate the project:

```bash
xcodegen generate
```

Open the generated project for local development:

```bash
open FamilyDuty.xcodeproj
```

Build the iPad simulator target without code signing:

```bash
xcodebuild build \
  -project FamilyDuty.xcodeproj \
  -target FamilyDuty \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO
```

Run the shared unit and UI test scheme:

```bash
xcodebuild test \
  -project FamilyDuty.xcodeproj \
  -scheme FamilyDutyTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  -derivedDataPath /private/tmp/FamilyDutyDerivedData
```

Replace the simulator name if it is not installed. Use `xcrun simctl list devices available` to inspect available devices. UI tests launch with `-uiTesting` and use an in-memory model container; seed flags such as `-seedDashboardTask`, `-seedOverdueTask`, and `-seedTaskBoard` are test-only data setup.

Verify the WeChat Mini Program domain and TypeScript code:

```bash
cd FamilyDutyMiniProgram
npm install
npm run verify
```

Import `FamilyDutyMiniProgram/` into WeChat Developer Tools for simulator and device validation. Keep its main data path offline; application reminders run only while the mini program is active.

## Coding Style & Naming Conventions

Use four-space indentation and standard Swift naming: `UpperCamelCase` for types and filenames, `lowerCamelCase` for methods and properties, and descriptive enum cases. Keep each file focused on its primary type.

Prefer small SwiftUI views, `@Query` for screen-local read models, and dependency-injected services for mutations and external system clients. Keep view code responsible for presentation and user interaction; do not duplicate rotation, deadline, completion, report, or notification rules inside views.

Use `Calendar` parameters for date-sensitive logic instead of relying on global device state. Normalize dates consistently through the existing deadline and report helpers. Preserve stable accessibility identifiers when changing UI layout, because UI tests and assistive technologies use them.

Follow Xcode formatting and remove warnings before review. Use the existing design system for colors, spacing, cards, hit targets, and status presentation. Status must not be communicated by color alone; retain meaningful text or symbols for pending, completed, cancelled, and overdue states.

## Testing Guidelines

Tests use XCTest. Name test files `*Tests.swift` and methods with behavior-focused names such as `testAssigneeRotatesEachWeekFromStartWeek`.

Add focused coverage for:

- model relationships and persistence round trips;
- rotation and task-generation edge cases, including one-off overrides and disabled rules;
- temporary task claiming and completion flows;
- deadline validation and overdue classification;
- completion rollback and historical member-name snapshots;
- report period boundaries, score aggregation, and duplicate-record handling;
- notification authorization and schedule refresh behavior;
- ViewModel state changes and user-visible validation errors.

Put end-to-end interactions, accessibility identifiers, and orientation-sensitive checks in `FamilyDutyUITests/`. Before opening a pull request, run the full `FamilyDutyTests` scheme and inspect both portrait and landscape layouts when UI changes are involved.

## Documentation and Change Scope

Update `README.md` when a user-visible feature, workflow, command, data limitation, or supported-device requirement changes. Update this file when architecture, domain invariants, testing commands, or repository conventions change. Keep documentation claims grounded in the current source and `project.yml`; do not document planned behavior as implemented behavior.

Implementation specifications belong in `docs/plans/` and should identify affected files, verification steps, and any behavior that must remain unchanged. If implementation reveals a requirement outside the approved plan, stop and return to planning before adding it.

## Commit & Pull Request Guidelines

Git history is not available in this checkout. Use concise, imperative commits with prefixes already used in project plans, such as `feat:`, `fix:`, `test:`, or `docs:`.

Pull requests should explain the user-visible change, list verification performed, and link relevant issues. For visual changes, include iPad screenshots and note behavior in both portrait and landscape orientations. Do not commit generated DerivedData, personal test data, credentials, provisioning profiles, or user-specific Xcode settings.

## Security & Configuration Tips

The app stores family data locally with SwiftData. Do not commit credentials, personal test data, provisioning profiles, or user-specific Xcode settings. Keep bundle identifier, deployment target, target membership, and signing-related configuration centralized in `project.yml` where possible.
