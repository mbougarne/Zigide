# macOS Packaging and Integrity

- **Type:** Feature
- **Milestone:** 4 - Public Preview
- **Goal:** Produce a reproducible macOS arm64 application bundle and distributable artifact with verifiable integrity.
- **Architecture:** [Milestone 4](../docs/architecture/05-delivery-roadmap.md#milestone-4-public-preview), [Local data](../docs/architecture/04-data-safety-and-operations.md#local-data)

## ZIT-191: Define the Application Bundle Layout

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-089, ZIT-189
- **Description:** Define executable, resources, metadata, identity, icons, libraries, and data-location boundaries for the macOS bundle.
- **Acceptance criteria:**
  - [ ] User settings, logs, recovery, extensions, and workspace state remain outside the bundle.
  - [ ] Bundle identity and resource paths are stable and documented.

## ZIT-192: Produce Final Application Assets and Metadata

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-191
- **Description:** Add required icon assets, property metadata, version fields, and accessibility-facing product name for the candidate.
- **Acceptance criteria:**
  - [ ] Assets render correctly at required scales without generated-path leakage.
  - [ ] Metadata matches release version, platform, license, and actual capabilities.

## ZIT-193: Implement the Clean Release Build

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-191, ZIT-192
- **Description:** Add one documented command that produces the app bundle and archive from a clean checkout with pinned inputs.
- **Acceptance criteria:**
  - [ ] Build succeeds on the target environment without unrecorded manual file edits.
  - [ ] Artifact contains no debug-only resources, secrets, or local absolute paths.

## ZIT-194: Generate Checksums and Compare Reproducibility

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-193
- **Description:** Generate cryptographic digests and compare two clean builds under documented reproducibility conditions.
- **Acceptance criteria:**
  - [ ] Checksum verification detects a modified archive.
  - [ ] Nondeterministic differences are identified and either fixed or documented.

## ZIT-195: Evaluate Signing and Notarization

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-3 days
- **Dependencies:** ZIT-193
- **Description:** Determine whether signing/notarization can be completed and document the exact verified state without storing credentials.
- **Acceptance criteria:**
  - [ ] Successful signing/notarization is verified end to end, or unsupported status is stated prominently.
  - [ ] Credentials, certificates, and secrets never enter repository or agent records.

## ZIT-196: Test Install, Upgrade, Uninstall, and Bundle Integrity

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-193, ZIT-194, ZIT-195
- **Description:** Test archive verification, install, first launch, upgrade from a prior fixture, removal, user-data retention, and bundle inventory.
- **Acceptance criteria:**
  - [ ] Removal does not delete user data unexpectedly.
  - [ ] Bundle inventory matches dependencies, licenses, notices, and published integrity data.
