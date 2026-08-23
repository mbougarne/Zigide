# UI Toolkit Spike

- **Type:** Feature
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Select the production UI strategy using IDE-grade input, accessibility, packaging, and performance evidence.
- **Architecture:** [ADR-0004](../docs/architecture/decisions/0004-ui-toolkit-selection.md)

## ZIT-034: Build the Shared UI Spike Scenario

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-005, ZIT-012
- **Description:** Define the same explorer/editor/panel scenario, document fixture, background result, measurements, and scoring weights for all candidates.
- **Acceptance criteria:**
  - [ ] Candidate implementations are compared against identical required behavior.
  - [ ] Correct input and accessibility carry more weight than visual novelty.

## ZIT-035: Spike Direct AppKit Integration

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-034
- **Description:** Implement the shared scenario through Zig-to-AppKit integration and record binding and platform costs.
- **Acceptance criteria:**
  - [ ] The scenario builds and bundles on macOS arm64 or documents the exact blocker.
  - [ ] Toolkit types remain confined to the spike adapter.

## ZIT-036: Spike the Strongest Native Zig Toolkit

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-034
- **Description:** Select the best-maintained candidate among the documented native Zig options and implement the shared scenario.
- **Acceptance criteria:**
  - [ ] Exact version, license, maintenance evidence, and missing IDE capabilities are recorded.
  - [ ] Build or behavior failures remain published evidence rather than being hidden.

## ZIT-037: Spike the System WebView Option

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-034
- **Description:** Implement the shared scenario with WKWebView without bundling a browser runtime and measure the non-Zig surface.
- **Acceptance criteria:**
  - [ ] Native/web boundary, packaging, startup, memory, and debugging costs are recorded.
  - [ ] The scenario does not imply future webview extension support.

## ZIT-038: Verify Clipboard and IME Behavior

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days per viable candidate
- **Dependencies:** ZIT-035, ZIT-036, ZIT-037
- **Description:** Test multiline Unicode clipboard and marked-text IME update, commit, and cancellation on the target Mac.
- **Acceptance criteria:**
  - [ ] Behavior is exercised manually and captured for every viable candidate.
  - [ ] Candidates that corrupt or prematurely commit composition are marked failed.

## ZIT-039: Verify UI Accessibility Behavior

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days per viable candidate
- **Dependencies:** ZIT-035, ZIT-036, ZIT-037
- **Description:** Test labels, focus order, text exposure, selection reporting, and basic editing with VoiceOver.
- **Acceptance criteria:**
  - [ ] Results come from target-device inspection rather than documentation claims.
  - [ ] Missing accessibility primitives are scored as production costs.

## ZIT-040: Measure UI Performance and Packaging

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-035, ZIT-036, ZIT-037
- **Description:** Measure startup, idle memory, large-document scrolling, background-result responsiveness, package size, and bundling complexity.
- **Acceptance criteria:**
  - [ ] Measurements identify hardware, build mode, fixtures, and limitations.
  - [ ] Each viable candidate produces a distributable bundle or an exact packaging blocker.

## ZIT-041: Score Candidates and Resolve ADR-0004

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-038, ZIT-039, ZIT-040
- **Description:** Publish the scored comparison and accept, reject, or supersede ADR-0004 with the selected production UI strategy.
- **Acceptance criteria:**
  - [ ] Source, versions, licenses, measurements, screenshots, and failures are linked.
  - [ ] Production editor UI work remains blocked until an accepted ADR exists.
