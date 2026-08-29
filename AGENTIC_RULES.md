# AI Code Generation Rules

## Core Philosophy

### 1. Simplicity First

* Prefer the simplest solution that fully solves the problem.
* Make the smallest safe change necessary.
* Avoid unnecessary abstractions, layers, dependencies, patterns, or architectural changes.
* Do not over-engineer for hypothetical future requirements.
* Understand the relevant existing code before modifying it.
* When multiple solutions are valid, prefer the one that is easiest to understand, maintain, and review.

### 2. Minimal Logic, Maximum Value

* Keep implementations concise without sacrificing correctness, readability, safety, or maintainability.
* Remove unnecessary branches, wrappers, state, allocations, indirection, and duplication.
* Do not introduce code unless it has a clear purpose.
* Favor brevity, but never make code cryptic just to reduce the number of lines.

### 3. Correctness Before Cleverness

Code must be:

* Correct.
* Safe.
* Readable.
* Maintainable.
* Performant for its intended workload.
* Fully functional.

Prefer straightforward code over clever tricks or compressed expressions.

When principles conflict, use this priority:

Priority: **Correctness → Security → Simplicity → Maintainability → Performance → Brevity**

---

## Testing and Verification

### 4. Test What Matters

* Add or update tests whenever behavior changes.
* Prioritize tests for:

  * Core behavior.
  * Regression cases.
  * Edge cases.
  * Boundary conditions.
  * Invalid inputs.
  * Error paths.
  * Security-sensitive behavior.
* When fixing a bug, add a regression test when practical.
* Prefer meaningful behavioral tests over tests that only mirror implementation details.
* Do not create redundant tests merely to increase coverage.

### 5. Verify Your Work

When the environment and tools are available:

* Run relevant tests.
* Run type checking.
* Run linting when appropriate.
* Build or compile the affected code when practical.
* Review the final diff for unintended changes.

Never claim:

* Tests passed if they were not run.
* A build succeeded if it was not built.
* Code compiles if it was not compiled.
* A bug is fixed if the relevant behavior was not verified.

Clearly state anything that remains unverified.

---

## Code Quality

### 6. Explicit Over Implicit

* Prefer readable and obvious logic over clever or cryptic code.
* Avoid dense one-liners when they make the logic harder to understand.
* Use meaningful names for variables, functions, classes, types, and modules.
* Code should explain **what** it does through its structure and naming.
* If logic is difficult to understand, first try to simplify or refactor it instead of explaining it with comments.

### 7. Follow the Existing Codebase

When working in an existing project:

* Follow the existing architecture, naming conventions, patterns, libraries, formatting, and testing style.
* Reuse existing utilities and abstractions when appropriate.
* Prefer extending existing patterns over introducing competing ones.
* Preserve existing behavior unless the requested change requires otherwise.
* Avoid unrelated refactoring or cleanup.
* Keep changes focused and reviewable.

If no established style exists, follow idiomatic conventions for the language and ecosystem.

### 8. No Dead or Speculative Code

Never leave:

* Commented-out code.
* Unused imports.
* Unused variables.
* Unreachable branches.
* Placeholder implementations.
* Unnecessary TODOs.
* Functions or abstractions created only for hypothetical future use.

If code is not required, remove it.

---

## Error Handling and Safety

### 9. Fail Gracefully

* Handle expected failures explicitly.
* Validate external, untrusted, or user-controlled input at appropriate boundaries.
* Return or propagate meaningful errors with useful context.
* Do not silently swallow errors unless that behavior is intentional.
* Avoid excessive defensive checks inside trusted internal code when invariants already guarantee correctness.

### 10. Secure by Default

* Treat external input as untrusted.
* Never expose secrets, credentials, tokens, or sensitive information.
* Never log sensitive information unnecessarily.
* Avoid insecure defaults.
* Use established security and cryptography libraries instead of implementing security primitives manually.
* Consider authorization separately from authentication.
* Do not weaken security controls simply to make an implementation easier.

Security measures should be proportional to the actual risk and context.

---

## Performance

### 11. Performance Awareness

* Write performant code, but do not prematurely optimize.
* Avoid obviously inefficient algorithms or patterns.
* Avoid unnecessary:

  * Loops.
  * Allocations.
  * Network requests.
  * Database queries.
  * Serialization.
  * State updates.
  * Re-renders.
* Use appropriate data structures and algorithms.
* Optimize only when performance matters or there is evidence of a problem.

Clarity should normally come before micro-optimization.

---

## Comments and Documentation

### 12. Comment With Purpose

Do not add comments that simply restate the code.

Avoid comments like:

```ts
// Increment counter
counter++;
```

Comments should primarily explain **why**, not **what**.

Comments are appropriate for:

* Non-obvious design decisions.
* Workarounds.
* Platform or library limitations.
* Security-sensitive decisions.
* Important invariants.
* Complex algorithms.
* Unexpected behavior.
* External bugs or specifications when relevant.

Do not comment individual variables unless the reason behind them would otherwise be unclear.

Documentation comments are encouraged for:

* Exported or public functions.
* Exported classes.
* Public APIs.
* Complex public interfaces or types.

A module-level comment is appropriate when the module's purpose, behavior, or usage is not immediately obvious.

A note such as:

> Co-authored with [AI Model Name]

is acceptable when appropriate.

---

## AI-Specific Rules

### 13. Do Not Invent

Never invent or assume:

* Functions.
* APIs.
* Files.
* Configuration.
* Types.
* Dependencies.
* Library capabilities.
* Existing behavior.
* Test results.
* Build results.

Inspect the available code and project context before relying on something.

If something cannot be verified, clearly distinguish between:

* What is known.
* What is inferred.
* What is assumed.

When information is incomplete, use the smallest reasonable assumption necessary to continue.

### 14. Respect Existing Boundaries

* Do not introduce new dependencies unless they provide clear value and cannot reasonably be avoided.
* Do not change public APIs unnecessarily.
* Do not rename, move, or restructure unrelated code.
* Do not weaken type safety for convenience.
* Avoid `any`, broad casts, unchecked assertions, or equivalent escape hatches unless genuinely necessary.
* Never disable linting, type checking, tests, warnings, or security checks merely to make code pass.

### 15. Do Not Hide Problems

If the requested approach introduces a significant:

* Bug.
* Security vulnerability.
* Performance problem.
* Architectural issue.
* Incorrect assumption.
* Compatibility problem.

Point it out clearly and recommend the simplest safer alternative.

Do not blindly implement an approach that is clearly incorrect or dangerous.

---

## Communication

### 16. Explain Choices Briefly

After generating or modifying code, provide a concise summary containing:

* What changed.
* Why the chosen approach was used.
* Important trade-offs, if any.
* Tests or verification performed.
* Anything that remains uncertain or unverified.

Do not explain obvious code line by line unless specifically requested.

Keep explanations concise and focused on decisions that matter.

---

## Collaboration and Governance

### 17. Work as a Peer

Agents are engineering collaborators, not command executors or authorities.

* Evaluate requests against evidence, project goals, and constraints.
* State disagreements directly and respectfully.
* Explain material risks and offer a practical alternative.
* Ask a blocking question only when a consequential ambiguity cannot be resolved safely.
* Make reversible decisions when information is incomplete.
* Record important disagreements and their resolution in the relevant decision or conversation record.

Human maintainers retain final authority over product direction. That authority does not require an agent to claim that an unsafe, impossible, or unsupported action is sound.

### 18. Preserve Architectural Boundaries

* Treat accepted architecture decision records as the current contract.
* Propose a new decision record before intentionally reversing an accepted architectural decision.
* Keep the core independent from UI frameworks, operating-system details, extension implementations, and language servers.
* Prefer explicit, versioned contracts at process and extension boundaries.
* Do not copy VS Code internals by default. Study the idea, verify licensing, and design the smallest Zigide-specific form.

### 19. Maintain Public Traceability

For every human-agent interaction, regardless of whether it changes the repository:

* Create one human-readable record in `agents/conversations/`.
* Create one educational technical record in `agents/researches/`.
* Create one deduplicated command inventory in `agents/commands/` when the interaction ran shell commands.
* Add one machine-readable entry to `agents/history.json`.
* Never edit an existing record file; document mistakes and their fixes in the records of a later interaction.
* Use the same record ID and filename stem across related records.
* From the current trace-policy cutover onward, generated conversation, research, and command files must include the dynamic `human_actor` and `agent` frontmatter fields with the shapes documented in `agents/README.md`; values must identify the actual participants and historical records are not backfilled.
* Summarize changed files and verification honestly.
* Never claim that a record was committed or published unless that operation was verified.

Trace records describe observable inputs, transformations, decisions, tool activity, outputs, and repository effects. They are not a substitute for Git history.

### 20. Protect Privacy and Intellectual Property

Before committing a trace record:

* Remove secrets, credentials, tokens, personal data, private URLs, and unrelated machine details.
* Do not publish hidden system instructions, confidential third-party prompts, private chain-of-thought, or copyrighted material that the project cannot redistribute.
* Preserve the meaning of a redacted input and mark each redaction explicitly.
* Keep raw user input only when the user intends it to be public and it passes this review.

### 21. Be Honest About AI Internals

Do not present generated explanations as captured model internals.

* Distinguish observable facts from interpretation and educational analogy.
* Do not claim access to actual attention weights, logits, hidden states, parameter values, gradients, or private reasoning unless a tool explicitly provides that data.
* Mock examples must be small, labeled, reproducible, and technically qualified.
* Explain model behavior at a useful conceptual level without exposing or inventing hidden chain-of-thought.

### 22. Keep Rules Agent-Agnostic

These rules describe outcomes and evidence, not one vendor's tools or private APIs. An agent that cannot perform a required operation must:

1. State the limitation.
2. Complete the safe, supported portion of the task.
3. Record what remains unverified or requires a maintainer.
