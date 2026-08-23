# Editor Input, Rendering, and Accessibility

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Connect the text model to responsive rendering, complete text input, selection, clipboard, mouse, and accessibility behavior.
- **Architecture:** [Text model](../docs/architecture/02-system-architecture.md#text-model), [ADR-0004](../docs/architecture/decisions/0004-ui-toolkit-selection.md)

## ZIT-090: Implement Viewport Text Rendering

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-048, ZIT-085
- **Description:** Render only visible lines plus bounded overscan from stable text snapshots.
- **Acceptance criteria:**
  - [ ] Scrolling does not render or allocate proportional to the full document.
  - [ ] Empty, long-line, mixed-width, and large-document fixtures render safely.

## ZIT-091: Implement Text Measurement and Font Fallback

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-090
- **Description:** Measure glyph runs, line heights, tabs, and fallback fonts through the chosen UI adapter.
- **Acceptance criteria:**
  - [ ] Measurement and rendered positions agree across representative Unicode text.
  - [ ] Missing glyphs use fallback without overlapping adjacent content.

## ZIT-092: Map Screen Coordinates and Text Positions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-045, ZIT-091
- **Description:** Convert viewport coordinates to validated text positions and positions back to caret geometry.
- **Acceptance criteria:**
  - [ ] Mapping handles scrolling, tabs, scale changes, and clicks past line ends.
  - [ ] No coordinate conversion creates a multibyte-splitting position.

## ZIT-093: Render Carets and Selections

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-058, ZIT-092
- **Description:** Draw active/inactive caret and selected ranges without mutating selection state in the renderer.
- **Acceptance criteria:**
  - [ ] Visual geometry matches model positions across viewport changes.
  - [ ] Selection contrast and focus state remain perceivable.

## ZIT-094: Implement Keyboard Editing Commands

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-016, ZIT-059, ZIT-074, ZIT-093
- **Description:** Route navigation, insertion, deletion, selection, undo, redo, save, and command shortcuts through commands and transactions.
- **Acceptance criteria:**
  - [ ] Key events do not bypass command preconditions or edit validation.
  - [ ] Core editing works with keyboard-only operation.

## ZIT-095: Implement Mouse Selection and Scrolling

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-092, ZIT-093
- **Description:** Handle click, shift-click, drag selection, wheel/trackpad scrolling, and autoscroll at viewport edges.
- **Acceptance criteria:**
  - [ ] Pointer gestures produce valid selection transactions.
  - [ ] Hover or drag cannot resize the editor layout unexpectedly.

## ZIT-096: Implement Clipboard Operations

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-059, ZIT-094
- **Description:** Implement copy, cut, and paste through a platform clipboard port with bounded text input.
- **Acceptance criteria:**
  - [ ] Multiline Unicode text round-trips through clipboard operations.
  - [ ] Cut and paste are reversible transactions and failures preserve content.

## ZIT-097: Implement IME Composition

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 4-7 days
- **Dependencies:** ZIT-091, ZIT-094
- **Description:** Handle marked-text update, replacement, commit, and cancellation without corrupting content or undo history.
- **Acceptance criteria:**
  - [ ] Partial composition is not committed as independent typing transactions.
  - [ ] Commit and cancel preserve valid selection and document state.

## ZIT-098: Expose Editor Accessibility Semantics

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 4-7 days
- **Dependencies:** ZIT-087, ZIT-092, ZIT-094
- **Description:** Expose editor text, caret, selection, visible range, and editing actions to macOS accessibility APIs.
- **Acceptance criteria:**
  - [ ] VoiceOver can identify, read, select, and edit text around the caret.
  - [ ] Accessibility queries use stable snapshots and do not block input indefinitely.

## ZIT-099: Verify Editor Latency, Input, and Accessibility

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-090, ZIT-093, ZIT-094, ZIT-095, ZIT-096, ZIT-097, ZIT-098
- **Description:** Run automated and target-device checks for rendering, typing, scrolling, clipboard, IME, scaling, keyboard, and VoiceOver behavior.
- **Acceptance criteria:**
  - [ ] Large-document and ordinary-input latency meet approved budgets or block milestone exit.
  - [ ] Captured manual evidence names exact hardware, OS, toolkit, and known limitations.
