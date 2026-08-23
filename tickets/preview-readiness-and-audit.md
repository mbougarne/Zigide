# Preview Readiness and Audit

- **Type:** Feature
- **Milestone:** 4 - Public Preview
- **Goal:** Audit migration, defects, issue intake, licensing, traces, secrets, artifacts, and release claims before publication.
- **Architecture:** [Public development trace](../docs/architecture/04-data-safety-and-operations.md#public-development-trace), [Explicit non-goals](../docs/architecture/01-vision-and-scope.md#explicit-non-goals-for-the-first-release)

## ZIT-210: Define Preview Versioning and Migration Policy

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-189
- **Description:** Define preview versions and migration/reset/rollback behavior for settings, workspace state, recovery, extensions, manifests, and protocols.
- **Acceptance criteria:**
  - [ ] Every persisted/public format has a supported migration or explicit reset policy.
  - [ ] Compatibility wording matches the extension protocol matrix.

## ZIT-211: Triage Release-Blocking Defects and Limitations

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-189, ZIT-209
- **Description:** Review open work and classify data-loss, security, crash, compatibility, performance, accessibility, and UX defects against release policy.
- **Acceptance criteria:**
  - [ ] No P0 defect remains open at publication.
  - [ ] Accepted P1 limitations appear in release notes with rationale.

## ZIT-212: Verify Issue Intake

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 0.5-1 day
- **Dependencies:** ZIT-199, ZIT-200
- **Description:** Verify issue templates collect reproduction, environment, expected/actual behavior, safe logs, and architecture context where relevant.
- **Acceptance criteria:**
  - [ ] A sample report yields actionable, non-sensitive information.
  - [ ] Security reports are directed away from public issues.

## ZIT-213: Audit Licenses and Third-Party Notices

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-3 days
- **Dependencies:** ZIT-196
- **Description:** Match source, bundled dependencies, assets, adapted code, licenses, and notices to the final bundle inventory.
- **Acceptance criteria:**
  - [ ] Every distributed third-party component has verified redistribution terms and required notice.
  - [ ] Provenance gaps block publication.

## ZIT-214: Audit Public AI Records for Privacy and IP

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-3 days
- **Dependencies:** ZIT-189, ZIT-202
- **Description:** Review public prompts, outputs, screenshots, paths, and claims for secrets, personal data, proprietary instructions, copyrighted material, and fabricated internals.
- **Acceptance criteria:**
  - [ ] Every public record passes the documented redaction and redistribution policy.
  - [ ] Corrections follow append-only trace rules rather than rewriting published history.

## ZIT-215: Scan Source and Artifacts for Secrets and Local Leakage

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-194, ZIT-213
- **Description:** Scan source, Git history, logs, screenshots, bundle, archive, and generated metadata for secrets, credentials, personal paths, and debug leakage.
- **Acceptance criteria:**
  - [ ] Findings are removed, redacted, or documented as blockers without exposing the secret in records.
  - [ ] Final artifact contains no undisclosed local or confidential data.

## ZIT-216: Publish Release Notes and Final Audit Sign-Off

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-190, ZIT-210, ZIT-211, ZIT-212, ZIT-213, ZIT-214, ZIT-215
- **Description:** Publish exact platform/tool assumptions, integrity/signing state, compatibility, security boundaries, known limitations, evidence, and all accepted exceptions.
- **Acceptance criteria:**
  - [ ] Claims match verified candidate behavior and artifacts.
  - [ ] Final sign-off links every release blocker, exception, audit, and new-user result.
