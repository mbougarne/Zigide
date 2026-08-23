# Zigide Tickets

This directory turns the accepted architecture and delivery roadmap into reviewable work. The backlog covers the first public preview only; deferred tracks require measured demand and new architecture decisions before tickets are added.

## Identity

Every ticket uses an immutable identifier in the form `ZIT-NNN`, meaning **Zig IDE Ticket**. IDs are never reused, even when a ticket is cancelled or superseded.

The canonical index is [backlog.md](backlog.md). It contains every ticket's ID, title, and brief summary. Each entry links to the ticket's section inside its owning feature or epic file.

Files represent features or epics, not individual tickets. A feature file groups the small implementation, test, documentation, and validation tickets needed to complete that feature. This keeps related work readable without turning one broad feature into one oversized ticket.

## Ticket Types

- **Epic file:** a milestone-sized work package containing coordination, integration, and exit-evidence tickets.
- **Feature file:** one product or engineering capability containing multiple independently verifiable tickets.
- **Ticket:** a small unit of work with its own description, acceptance criteria, estimate, dependencies, and validation expectation.

## Fields

- **Status:** `Planned`, `Ready`, `In Progress`, `Blocked`, `Done`, `Cancelled`, or `Superseded`.
- **Priority:** `P0` blocks the next milestone, `P1` is required for the milestone, and `P2` is required before public preview but may be sequenced flexibly.
- **Estimate:** a range of focused engineering time, including implementation, tests, and documentation for that ticket. It is a planning hypothesis, not a deadline or calendar commitment.
- **Dependencies:** ticket IDs that must reach `Done`, or an explicit external prerequisite.
- **Architecture references:** governing documents; a ticket cannot silently contradict them.

## Working Rules

1. Keep acceptance criteria observable and implementation-independent where practical.
2. A ticket reaches `Done` only when its validation evidence exists and relevant repository checks pass.
3. Update estimates when a spike produces better evidence; preserve the reason in the ticket.
4. Use an ADR before changing process boundaries, public protocols, persistence formats, extension compatibility, or UI strategy.
5. Do not expand a ticket to include deferred first-release non-goals.
6. Keep a ticket small enough to review and verify independently; split it before implementation if it hides multiple meaningful outcomes.
7. When splitting a ticket, mark the original `Superseded` and link the replacement IDs. Never reuse its ID.

## Milestone Order

```mermaid
flowchart LR
    M0[Milestone 0: Foundations] --> M1[Milestone 1: Dependable Editor]
    M1 --> M2[Milestone 2: Zig Work Loop]
    M2 --> M3[Milestone 3: Extensions]
    M3 --> M4[Milestone 4: Public Preview]
```

Feature work can overlap when dependencies allow, but milestone exit evidence must be complete before the next milestone is declared complete.
