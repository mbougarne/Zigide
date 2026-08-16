# ADR-0001: Zig-First Modular Architecture

* Status: Accepted
* Date: 2026-08-16

## Context

Zigide must be useful, educational, and recognizably a Zig system. A VS Code-sized service graph would obstruct learning and delivery, while a single unstructured executable would make testing and extension boundaries fragile.

## Decision

Build one main Zig application as a modular architecture with inward dependencies. Domain and application code are toolkit- and platform-independent. External language servers and extensions are child processes behind explicit adapters.

Use direct construction and explicit interfaces. Do not introduce a general dependency-injection framework unless concrete complexity later justifies it.

## Consequences

* Most behavior is testable without a window or child process.
* The first executable remains simple to build and debug.
* Module boundaries require review discipline because one process does not enforce them.
* Platform and UI adapters may use C APIs or libraries without moving domain logic out of Zig.

## Alternatives

* A microservice-style IDE was rejected as operationally expensive.
* A monolithic module was rejected because it provides no stable seams for tests or adapters.
* Reproducing VS Code's decorator-based service graph was rejected as unnecessary in Zig.

## Validation

Milestone 0 must compose the application headlessly and substitute file, clock, process, and UI ports in tests.
