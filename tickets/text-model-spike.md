# Text Model Spike

- **Type:** Feature
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Compare a piece table with a simple baseline under realistic correctness and performance workloads.
- **Architecture:** [Text model](../docs/architecture/02-system-architecture.md#text-model), [Verification strategy](../docs/architecture/04-data-safety-and-operations.md#verification-strategy)

## ZIT-027: Define Text-Model Reference Behavior

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-004
- **Description:** Implement a simple reference string model and define valid edit, position, line-ending, and invalid-input semantics for the spike.
- **Acceptance criteria:**
  - [ ] The reference model favors obvious correctness over performance.
  - [ ] Edge-case behavior is documented before optimized structures are compared.

## ZIT-028: Prototype Piece-Table Storage

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-027
- **Description:** Prototype original/add buffers and piece operations for insert, delete, replace, and snapshot reads.
- **Acceptance criteria:**
  - [ ] Basic and boundary edits match reference-model content.
  - [ ] Ownership and allocator lifetime are explicit.

## ZIT-029: Prototype the Line-Start Index

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-028
- **Description:** Add offset-to-line/column and line/column-to-offset lookup that updates after edits.
- **Acceptance criteria:**
  - [ ] Empty, mixed-ending, long-line, and multibyte cases match the reference model.
  - [ ] Invalid positions fail before mutation or lookup reads out of bounds.

## ZIT-030: Add Randomized Edit Equivalence Tests

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-027, ZIT-028, ZIT-029
- **Description:** Generate valid edit sequences and compare piece-table content and positions with the reference model after each step.
- **Acceptance criteria:**
  - [ ] Failures print a reproducible seed and minimized operation sequence where practical.
  - [ ] Zig's test allocator reports no leaks across generated cases.

## ZIT-031: Define Representative Text Workloads

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-027
- **Description:** Define small, medium, large, long-line, UTF-8, and sustained-edit fixtures and operation distributions.
- **Acceptance criteria:**
  - [ ] Fixture provenance and generation commands are documented.
  - [ ] Workloads include memory growth and non-best-case editing patterns.

## ZIT-032: Benchmark Text Storage and Line Lookup

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-029, ZIT-031
- **Description:** Measure open, insert, delete, snapshot, lookup, memory, and sustained-edit behavior against the baseline.
- **Acceptance criteria:**
  - [ ] Results include target hardware, build mode, iterations, and latency distribution context.
  - [ ] Preliminary large-file and sustained-edit budgets are proposed.

## ZIT-033: Publish Text-Model Recommendation

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-030, ZIT-032
- **Description:** Recommend piece table, tree-backed variant, rope, or another structure using correctness and benchmark evidence.
- **Acceptance criteria:**
  - [ ] Trade-offs and rejected alternatives are explicit.
  - [ ] Disposable prototype code is removed if it is not the production starting point.
