# Zigide

An experimental IDE for Zig, written in Zig, built in the open with AI assistance.

## What This Project Really Is

Zigide is an experiment, and it is honest about that. The question it tries to answer:

> Can a developer with almost no Zig experience, working with AI agents, build something as complex as an IDE in a low-level language with manual memory management — and genuinely learn the language and the architecture along the way?

Some context on where this starts from:

* The maintainer's Zig experience is roughly two weeks of exploration in 2025 — enough to see that Zig sits between C and C++ in complexity (simpler than C++, more explicit than C), not enough to call it experience.
* Zig has no garbage collector. Memory ownership, allocator lifetimes, and failure paths are the developer's problem. That is precisely what makes it a demanding test for AI-assisted development.
* An IDE is one of the harder application categories: text models, concurrency, process supervision, protocols, and UI all interact.

So the project has three goals with equal weight:

1. **Prove:** show whether AI-assisted development can produce a real, working product in this setting.
2. **Build:** end up with an IDE the maintainer and others actually use for Zig work.
3. **Learn:** use the repository itself — its architecture docs, decisions, and public AI interaction records — as teaching material for Zig, IDE internals, and AI concepts.

The outcome is genuinely unknown. It may succeed, partially succeed, or fail in instructive ways. All three results are worth publishing.

## Current Status

Architecture phase. There is no product code yet; the design, boundaries, and delivery plan are documented before implementation begins. Development tooling exists: a Zig-based repository checker (`tools/check.zig`), a pinned toolchain, git hooks, and CI.

## Working with the Repository

Requires the Zig version pinned in `build.zig.zon` (`minimum_zig_version`).

```sh
zig build check   # hygiene, Markdown links, trace-ledger consistency, zig fmt
zig build hooks   # once per clone: points git at .githooks so pre-commit runs the checks
```

CI runs the same `zig build check` on macOS arm64 plus a JSON Schema validation of the trace ledger. The checks are implemented in Zig so one implementation runs identically in your terminal, the pre-commit hook, and CI.

## Where to Look

| You want | Go to |
| --- | --- |
| The vision and first-release scope | [docs/architecture/01-vision-and-scope.md](docs/architecture/01-vision-and-scope.md) |
| The system design | [docs/architecture/](docs/architecture/README.md) |
| Accepted and proposed decisions | [docs/architecture/decisions/](docs/architecture/decisions/README.md) |
| The rules every contributor (human or AI) follows | [AGENTIC_RULES.md](AGENTIC_RULES.md) |
| The public human-AI interaction ledger | [agents/](agents/README.md) |

AI agents should start at [AGENTS.md](AGENTS.md).

## License

[ISC](LICENSE)
