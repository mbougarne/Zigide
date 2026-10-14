# Development tooling follow-ups

## Review the pinned trace-schema validator dependencies

During the 2026-10-14 Dependable Editor work, the existing repository command
`npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s agents/history.schema.json -d agents/history.json`
passed validation. npm emitted deprecation warnings for transitive `glob@7.2.3`
and `inflight@1.0.6`; the glob warning mentions security vulnerabilities and the
inflight warning mentions a memory leak.

This is a development/CI tooling follow-up, outside ZIT-042/ZIT-043. No product
dependency was added or changed. Evaluate the resolved dependency tree and actual
exposure, then select a supported pinned validator in a separate scoped change.
Verify draft-2020 schema behavior and CI before replacing the current command.
The warning alone does not establish an exploitable Zigide product vulnerability.
