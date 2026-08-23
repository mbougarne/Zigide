# Human-AI Development Records

This directory makes substantive human-AI collaboration inspectable alongside the code it affects. It records intent, observable process, decisions, results, and limitations. Git remains the authoritative source of change history.

## Layout

```text
agents/
|-- README.md
|-- history.json
|-- history.schema.json
|-- conversations/
|   `-- YYYY-MM-DD-HH-MM-SS-UUID.md
|-- researches/
|   `-- YYYY-MM-DD-HH-MM-SS-UUID.md
`-- commands/
    `-- YYYY-MM-DD-HH-MM-SS-UUID.md
```

Timestamps are UTC. UUIDs are lowercase version 4 identifiers. A conversation, its research note, its command inventory, and its history entry share one ID and filename stem.

The directory name `researches` is retained as a project convention even though "research" is normally uncountable in English.

## Conversation Record

One prompt, one record. Every prompt gets its own conversation file, its own research file, and its own `history.json` entry — regardless of whether it changes the repository. Feedback, corrections, questions, and rule discussions are collaboration evidence and belong in the ledger as much as code changes do; a records-only-when-code-changed policy would bias the public history toward actions and hide the steering. Never merge multiple prompts into one record: merging hides which prompt caused which change and makes a long session unreadable.

Record files are write-once from the moment they exist, staged or committed. Never edit a conversation, research, or command file afterward — not to add cross-references, not to fix omissions. A mistake or gap in a record is documented and repaired through the records of a later prompt; the mistakes and their fixes are part of what this ledger exists to show. (A merged record discovered before commit is the one exception, replaced with per-prompt records as established in the ledger's own history.)

Every prompt gets one Markdown file with:

1. Metadata and visibility.
2. Raw user input, after explicit redaction review.
3. Agent-normalized requirements.
4. Agent interpretation, including assumptions, disagreement, and limits.
5. Assistant answer.
6. Observable evidence and tool activity.
7. Changed-file summary.
8. Verification and open items.

"Interpretation" is a concise decision record, not hidden chain-of-thought. Agents must not expose confidential system instructions or fabricate private reasoning.

## Research Record

The matching `researches` file is required and educational. It can explain tokenization, embeddings, attention, probability, tool orchestration, retrieval, or verification using small reproducible examples. It must label mocked values and distinguish general model concepts from facts observable in the interaction.

Actual model parameters, attention maps, logits, hidden activations, gradients, and private reasoning are unavailable unless an explicit diagnostic tool supplies them. A plausible simulation must never be labeled as captured data.

## Command Record

When answering a prompt involved running shell commands, the matching `commands` file records **which** commands were used — not what they produced or when they ran. It is a deduplicated inventory for learning which tools the work actually required, not an execution log; Git history and the conversation record carry outcomes.

Rules:

1. List each distinct command once, with a one-line purpose. Repeated invocations of the same command appear one time.
2. Deduplicate by command and subcommand (for example, three `git show` runs are one line). Keep flags only when they are the point of the command (`git diff --cached` and `git diff` may be separate lines when the distinction matters).
3. Omit noise: interactive shells, aborted typos, and commands that only re-ran a listed one.
4. Apply the same redaction review as other records: no secrets, tokens, private URLs, or personal paths in arguments.
5. A prompt answered without running any command needs no command record; the history entry's `commands` field is then absent or null.

## Machine History

`history.json` is an append-only index optimized for agents and automation. It must validate against `history.schema.json`. Summaries should be compact and searchable; full prose belongs in Markdown records.

Corrections after publication append a new record or a clearly dated correction. Do not silently rewrite history.

Entries are a ledger: each one describes the state at the moment it was written and is never mutated afterward. In particular, `publication` records whether the work was committed and pushed **when the entry was created**. A later commit or push does not make an older entry wrong and must not be edited into it; Git history is the authority for what eventually happened.

## Workflow

1. Generate the UTC timestamp and UUID when beginning substantive work.
2. Review the raw input for secrets, personal information, private URLs, proprietary prompts, and redistribution restrictions.
3. Complete and verify the work.
4. Add the conversation and research records, and the command inventory when commands were run.
5. Append the machine-readable history entry.
6. Validate JSON, links, Markdown hygiene, and the repository's relevant tests.
7. Commit the records with the changes they describe.
8. Push only after a maintainer approves publication and a remote is configured.

Never record or claim a commit, push, test, or publication that was not verified.

## Redaction

Prefer a marked placeholder such as `[REDACTED: access token]` over deleting text invisibly. Summarize the removed material only enough to preserve technical meaning. If safe redaction would destroy the meaning, keep the record private and publish a separate sanitized summary.
