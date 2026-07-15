# CoreSimulator Connection Recovery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore reliable command-line access to the local CoreSimulator service while preserving the project configuration that already runs successfully from Xcode.

**Architecture:** Treat this as a host-service recovery task, not an app-code change. First verify the failure outside the agent sandbox, then restart only the CoreSimulator-related launchd services if the host reproduces the failure, and finally validate both `simctl` and `xcodebuild` against an available iPad simulator. No Swift source or project settings should change unless verification proves the project target is the failing layer.

**Tech Stack:** macOS launchd, Xcode 16.0, CoreSimulator, `xcrun simctl`, `xcodebuild`, FamilyDuty SwiftUI project.

### Task 1: Capture host-level CoreSimulator evidence

**Files:**
- Read only: `AGENTS.md`, `project.yml`, `FamilyDuty.xcodeproj/xcshareddata/xcschemes/FamilyDuty.xcscheme`

**Step 1: Verify the active developer directory and Xcode version**

Run from a host-permitted shell:

`xcode-select -p && xcodebuild -version && xcrun --find simctl`

Expected: `/Applications/Xcode.app/Contents/Developer`, Xcode 16.0, and the Xcode-provided `simctl` path.

**Step 2: Reproduce the simulator connection failure outside the sandbox**

Run:

`xcrun simctl list --json`

Expected if the host service is still broken: a normal `Connection refused`/`Connection invalid` error. Expected if the agent sandbox caused the earlier symptom: valid runtimes and device state are returned.

**Step 3: Inspect recent CoreSimulator service logs**

Run:

`log show --last 15m --style compact --predicate 'process == "CoreSimulatorService" OR process == "simdiskimaged"'`

Record whether the service is crashing, refusing IPC, or failing to mount a runtime image.

### Task 2: Recover only the simulator service layer

**Files:**
- No repository files modified.

**Step 1: Stop the Simulator UI cleanly**

Quit Simulator if it is open, then run:

`xcrun simctl shutdown all`

Expected: the command completes or reports that no devices are booted.

**Step 2: Restart the per-user CoreSimulator service**

Run:

`launchctl kickstart -k gui/$(id -u)/com.apple.CoreSimulator.CoreSimulatorService`

If launchd reports that the label does not exist, use the supported service restart fallback:

`killall -u "$(id -un)" CoreSimulatorService`

Do not delete `~/Library/Developer/CoreSimulator/Devices` or runtime images at this stage.

**Step 3: Re-probe the service before opening a device**

Run:

`xcrun simctl list runtimes` and `xcrun simctl list devices available`

Expected: installed iOS runtimes and available devices are listed without CoreSimulator IPC errors.

### Task 3: Validate the project-facing workflow

**Files:**
- No repository files modified unless Task 1 proves a project-specific destination/configuration issue.

**Step 1: Select an installed iPad simulator**

Use the device identifier returned by Task 2; do not assume `iPad (10th generation)` exists locally.

**Step 2: Validate the scheme destination**

Run:

`xcodebuild -project FamilyDuty.xcodeproj -scheme FamilyDuty -showdestinations`

Expected: the selected iPad simulator appears as an available destination.

**Step 3: Perform a command-line simulator build**

Run:

`xcodebuild -project FamilyDuty.xcodeproj -scheme FamilyDuty -destination 'id=<verified-device-id>' build`

Expected: `** BUILD SUCCEEDED **`.

**Step 4: Confirm Xcode remains unaffected**

Keep the existing Xcode `Cmd+R` path as a control check. If host `simctl` succeeds but the agent shell fails, document the issue as sandbox access rather than changing the project.

### Task 4: Final verification and handoff

**Files:**
- Update only this plan or a short diagnostic note if the host service remains unavailable.

**Step 1: Run the final service probe**

Run `xcrun simctl list --json` and confirm no `CoreSimulatorService connection became invalid` message appears.

**Step 2: Check repository cleanliness**

Run `git status --short` and confirm no Swift, Xcode project, or user data files were changed.

**Step 3: Report the verified cause and recovery**

State whether the problem was a host CoreSimulator launchd service failure or an agent-sandbox permission boundary, and include the exact successful verification command.
