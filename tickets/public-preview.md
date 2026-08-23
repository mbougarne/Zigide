# Public Preview

- **Type:** Epic
- **Milestone:** 4 - Public Preview
- **Goal:** Package, document, measure, audit, and verify a usable macOS arm64 preview for new users.
- **Architecture:** [Delivery roadmap](../docs/architecture/05-delivery-roadmap.md), [Vision and scope](../docs/architecture/01-vision-and-scope.md)

## ZIT-189: Define the Preview Release-Candidate Checklist

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-188
- **Description:** Define exact source revision, tool versions, required tests, artifacts, documents, audits, owners, and blocking severity for a preview candidate.
- **Acceptance criteria:**
  - [ ] Every Milestone 4 deliverable and exit condition has an owning ticket.
  - [ ] Unverified signing, security, compatibility, or data guarantees cannot be implied by checklist completion.

## ZIT-190: Verify the Clean New-User Journey

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-201, ZIT-207, ZIT-214
- **Description:** Verify install, launch, project open, edit/save/recovery, search, build, ZLS, example extension, failure recovery, and issue reporting in an isolated user environment.
- **Acceptance criteria:**
  - [ ] A new user completes the first-release journey using only published instructions.
  - [ ] Every observed mismatch becomes a blocker, accepted limitation, or follow-up ticket before publication.
