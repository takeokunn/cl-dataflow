# cl-dataflow

[![CI](https://github.com/takeokunn/cl-dataflow/actions/workflows/ci.yml/badge.svg)](https://github.com/takeokunn/cl-dataflow/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-brightgreen.svg)](CHANGELOG.md)
[![SBCL](https://img.shields.io/badge/SBCL-supported-red.svg)](http://www.sbcl.org/)

`cl-dataflow` is a small Common Lisp library for composable computation graphs, pipelines, event-driven workflows, state machines, and effect boundaries.

## Status

- Core graph, pipeline, event, effect, and state-machine primitives are implemented.
- Runnable examples live under `examples/`.
- The canonical test system is `cl-dataflow/test`, and `asdf:test-system :cl-dataflow` dispatches to it.
- The repository verifies cleanly on SBCL with all tests and example scripts passing.

## Implementation Status

| Area | Status | Notes |
| --- | --- | --- |
| Graphs and nodes | Done | Node creation, edge construction, graph validation, and topological sort are implemented. |
| Pipelines | Done | Sequential pipelines and simple branching pipelines run against graph-ordered stages. |
| Events | Done | Event creation, emission, and trace capture are implemented. |
| Effects | Done | Effect creation, handler lookup, and test-friendly execution are implemented. |
| State machines | Done | States, transitions, guards, history, reset/copy helpers, step-based execution, context propagation, and pipeline-stage embedding are implemented. |
| Event workflows | Done | Pipeline stages can emit events, run effects, and advance a state machine in one workflow. |
| Graph algorithms | Done | Strongly/weakly connected components, topological generations, transpose, acyclicity, shortest-hop distance, degrees, and immediate neighbors, all over the bulk-query adjacency snapshot. |
| Graph export | Done | Deterministic Graphviz DOT and Mermaid rendering, plus a `graph-to-plist`/`plist-to-graph` structural round trip. |
| State-machine analysis | Done | State/event enumeration, reachability, unreachable/terminal-state detection, structural determinism check, and DOT/Mermaid rendering. |
| Combinators | Done | Handler wrappers (retry, fallback, memoize, tap, map, compose), node wrappers, and result-threading pipeline sequencing. |
| Streams | Done | A lazy transducer layer (`map`/`filter`/`scan`/`take`/`drop`/`distinct`/`flat-map`/`concat`/`zip`/`tap`) with `collect`/`reduce`/`for-each`/`count`/`first` consumers. |
| Protocols | Done | `flow-name`, `flow-metadata`, and `flow-kind` provide consistent introspection across flow objects. |
| Testing helpers | Done | Dedicated helpers assert emitted events, effects, final state, state-machine state, and pipeline results. |
| Runnable examples | Done | Scripts cover a simple pipeline, event workflow, state machine, graph analysis, the graph toolkit, state-machine visualization, resilient pipelines, and streams. |
| Public API | Stable | `cl-dataflow` is the single exported package. |

## Install

Place this checkout and `cl-prolog` in locations ASDF can see, then load the
system. The test system additionally requires `cl-weave`.

```lisp
(asdf:load-system :cl-dataflow)
```

For a Quicklisp-style local checkout:

```text
~/quicklisp/local-projects/cl-dataflow/
```

Then load it from Quicklisp:

```lisp
(ql:quickload :cl-dataflow)
```

Or register the repository directory in `asdf:*central-registry*` before loading.

The flake pins all dependencies and provides the reproducible development
environment:

```bash
nix develop
nix run
nix flake check
```

## Quick Start

```lisp
(defparameter *pipeline*
  (cl-dataflow:define-pipeline ()
    (:node "start"
     :handler (lambda (input context)
                (declare (ignore context))
                (1+ input)))
    (:node "finish"
     :handler (lambda (input context)
                (declare (ignore context))
                (* input 2)))
    (:edge "start" "finish")))

(cl-dataflow:run-pipeline *pipeline* :input 10)
;; => 22
```

## Core Concepts

- `Node`: a named computation with input ports, output ports, and a handler.
- `Edge`: a connection from one node output port to another node input port.
- `Graph`: a collection of nodes and edges with validation and topological ordering.
- `Context`: runtime state for events, effects, trace data, and workflow metadata.
- `Pipeline`: an executable graph or ordered stage list.
- `Event`: a recorded workflow occurrence with payload and trace position.
- `Effect`: a tracked side effect with handler lookup and result capture.
- `State Machine`: a small transition model with guards and actions.
- `Workflow`: a pipeline can emit events, trigger effects, and drive a state machine.

## Public API Reference

`cl-dataflow` exports a single package, `cl-dataflow`, with these public entry points:

- Errors: `cl-dataflow-error`, `graph-error`, `graph-error-graph`, `graph-error-detail`, `node-not-found-error`, `node-not-found-designator`, `graph-cycle-error`, `graph-cycle-nodes`, `effect-handler-missing-error`, `missing-effect-type`, `effect-handler-missing-effect`, `effect-handler-missing-detail`, `invalid-input-error`, `invalid-input-expected`, `invalid-input-value`, `invalid-input-detail`, `invalid-transition-error`, `invalid-transition-state`, `invalid-transition-event-type`, `invalid-transition-detail`, `guard-failed-error`, `guard-failed-state`, `guard-failed-event-type`, `guard-failed-transition`, `guard-failed-detail`
- Core data types: `node`, `edge`, `graph`, `context`, `event`, `effect`, `state-transition`, `state-machine`, `pipeline`
- Predicates: `node-p`, `edge-p`, `graph-p`, `context-p`, `event-p`, `effect-p`, `state-transition-p`, `state-machine-p`, `pipeline-p`
- Node APIs: `node-name`, `node-inputs`, `node-outputs`, `node-handler`, `node-metadata`, `make-node`
- Edge APIs: `edge-from`, `edge-from-port`, `edge-to`, `edge-to-port`, `edge-metadata`, `make-edge`
- Graph APIs: `graph-nodes`, `graph-edges`, `graph-metadata`, `make-graph`, `copy-graph`, `add-node`, `add-edge`, `find-node`, `graph-source-nodes`, `graph-sink-nodes`, `graph-reachable-p`, `graph-descendants`, `graph-ancestors`, `graph-path`, `validate-graph`, `topological-sort`
- Context APIs: `make-context`, `copy-context`, `context-values`, `context-value`, `context-node-values`, `context-events`, `context-events-in-order`, `context-event-types`, `context-events-of-type`, `context-effects`, `context-effects-in-order`, `context-effect-types`, `context-effects-of-type`, `context-trace`, `context-trace-in-order`, `context-last-event`, `context-last-effect`, `context-metadata`, `context-effect-handlers`, `context-result`, `context-state`
- Event APIs: `make-event`, `copy-event`, `emit-event`, `event-type`, `event-payload`, `event-metadata`, `event-trace-index`
- Effect APIs: `make-effect`, `copy-effect`, `perform-effect`, `effect-type`, `effect-payload`, `effect-metadata`, `effect-trace-index`, `effect-result`
- State machine APIs: `make-transition`, `define-state-machine`, `step-state-machine`, `run-state-machine`, `run-state-machine-with-context`, `make-state-machine-node`, `make-state-machine`, `copy-state-machine`, `state-machine-last-transition`, `state-machine-available-transitions`, `state-machine-can-step-p`, `reset-state-machine`, `transition-from`, `transition-event-type`, `transition-to`, `transition-guard`, `transition-action`, `transition-metadata`, `state-machine-state`, `state-machine-initial-state`, `state-machine-transitions`, `state-machine-history`, `state-machine-metadata`
- Pipeline APIs: `make-pipeline`, `define-pipeline`, `define-workflow`, `copy-pipeline`, `run-pipeline`, `run-pipeline-with-context`, `run-pipeline-sequence`, `pipeline-graph`, `pipeline-stages`, `pipeline-metadata`
- Graph analysis APIs: `graph-node-names`, `graph-order`, `graph-size`, `graph-empty-p`, `graph-successors`, `graph-predecessors`, `graph-out-degree`, `graph-in-degree`, `graph-transpose`, `graph-acyclic-p`, `graph-strongly-connected-components`, `graph-connected-components`, `graph-topological-generations`, `graph-distance`
- Graph export APIs: `graph->dot`, `graph->mermaid`, `graph-to-plist`, `plist-to-graph`
- State-machine analysis APIs: `state-machine-states`, `state-machine-event-types`, `state-machine-reachable-states`, `state-machine-unreachable-states`, `state-machine-terminal-states`, `state-machine-deterministic-p`, `state-machine->dot`, `state-machine->mermaid`
- Combinator APIs: `mapping-handler`, `compose-handlers`, `retrying-handler`, `fallback-handler`, `memoizing-handler`, `tapping-handler`, `wrap-node`, `node-with-retry`, `node-with-fallback`, `node-with-memoization`, `node-with-tap`
- Stream APIs: `flow-stream-p`, `empty-stream`, `list->stream`, `stream-of`, `stream-range`, `stream-map`, `stream-filter`, `stream-scan`, `stream-take`, `stream-drop`, `stream-take-while`, `stream-drop-while`, `stream-distinct`, `stream-flat-map`, `stream-concat`, `stream-zip`, `stream-tap`, `stream-collect`, `stream-reduce`, `stream-for-each`, `stream-count`, `stream-first`, `stream-empty-p`
- Protocols: `flow-name`, `flow-metadata`, `flow-kind` across nodes, edges, graphs, contexts, events, effects, transitions, state machines, and pipelines
- Testing helpers: `run-pipeline-with-test-context`, `assert-emitted-events`, `assert-performed-effects`, `assert-final-state`, `assert-state-machine-state`, `assert-pipeline-result`

Collection-oriented readers such as `graph-nodes`, `graph-edges`, `graph-source-nodes`,
`graph-sink-nodes`, `context-values`, `context-events`, `context-effects`,
`context-trace`, `event-payload`, `event-metadata`, `effect-payload`,
`effect-metadata`, `effect-result`, `transition-metadata`,
`state-machine-transitions`, and `pipeline-stages` return independent snapshots.
Their setters replace the entire live collection.
`context-effect-handlers` is intentionally mutable and returns the live handler
table so callers can register handlers directly.
`pipeline-graph` returns the live, validated graph owned by the pipeline, so
mutating it intentionally affects the pipeline. Use `copy-pipeline` when you
need an isolated graph clone.
`node-not-found-error` exposes the missing designator so callers can inspect
whether the failure came from a node name or an edge reference.
`graph-cycle-error` exposes the remaining cyclic nodes so callers can inspect
the exact cycle component that blocked ordering.
`effect-handler-missing-error` includes the missing effect type and a copied
effect snapshot so callers can inspect the payload that triggered the failure.

## API Overview

The library is organized around a small set of composable primitives:

- Graphs and nodes model the structure of a flow.
- Contexts capture runtime values, trace data, events, effects, and final result state.
- `copy-context`, `copy-event`, and `copy-effect` provide explicit clone helpers for the main runtime value types.
- `copy-context` clones the effect-handler table as well, so derived contexts can register different handlers without cross-talk.
- `context-result` returns an independent snapshot on read, so callers can inspect pipeline output without mutating the stored result.
- Graph node names are unique within a graph; `add-node` rejects duplicate names so edges do not silently retarget to a replacement node.
- Graph edges are unique by source node, source port, destination node, and destination port; `add-edge` rejects duplicate connections instead of counting them twice.
- `copy-pipeline` provides an explicit clone helper that preserves the pipeline graph, stage order, and metadata, while remapping stages onto the copied graph.
- `copy-state-machine` clones transitions, history, and metadata so derived machines can evolve independently from the original instance.
- Pipelines execute graphs and stage lists against a context.
- `define-pipeline`, `define-state-machine`, and `define-workflow` provide declarative entry points, so graph structure and transition data can stay separate from handler logic.
- Node handlers receive structured inputs normalized from hash tables, alists, plists, or scalars, and structured outputs are normalized back into the pipeline context and sink result data.
- Events, effects, and state machines let one pipeline drive another workflow boundary.
- `make-state-machine-node` turns a state machine into a pipeline stage without handwritten glue, and its `event-fn` and `result-fn` hooks let callers adapt pipeline input and emitted output without wrapping the machine manually. `event-fn` may return an event designator or a full event object.
- `define-workflow` unifies graph edges, state-machine transitions, and embedded machine nodes in one macro expansion while still returning ordinary `pipeline` and `state-machine` values.
- `step-state-machine` and `run-state-machine` return transition records so the state machine can behave like a reducer in pipeline and workflow code.
- When `step-state-machine` receives a `context`, it updates `context-state` and appends the transition record to `context-trace`.
- `copy-state-machine`, `reset-state-machine`, and `state-machine-history` make the mutable state machine reusable and observable across runs.
- State machine transitions are copied on construction and assignment, so caller-owned transition objects do not leak into the machine.
- State-machine transition failures surface structured condition data, including the current state, event type, and the transition snapshot for guard failures.
- Graph cycle failures surface the remaining cyclic nodes so callers can inspect the exact component that prevented ordering.
- `graph-reachable-p`, `graph-descendants`, `graph-ancestors`, and `graph-path` answer reachability questions over the Prolog edge relation: `graph-reachable-p` is the boolean predicate, `graph-descendants` returns every node reachable from a node and `graph-ancestors` returns every node that reaches it (both as name-ordered node snapshots), and `graph-path` returns the node names of a shortest witnessing path (`FROM` first, `TO` last) or `NIL`. All follow the same one-or-more-edges rule and terminate on cyclic graphs.
- Pipeline stage lists are copied on construction and assignment, so caller-owned stage lists do not leak into the pipeline object.
- Pipelines copy supplied graphs on construction and assignment, so caller-owned graph mutations do not leak into the pipeline object. When a pipeline is built from a graph, its stage list is remapped onto that copied graph so the pipeline stays internally coherent.
- Collection readers return snapshots, so callers can inspect state without mutating the live object by accident.
- Effect handlers are stored on the context with normalized lowercase string keys, so symbols and strings both resolve consistently through `make-context` and `perform-effect`.
- `state-machine-available-transitions` and `state-machine-can-step-p` expose the active control surface for orchestration; `state-machine-can-step-p` accepts `:context` so callers can preflight guarded transitions with the same runtime data they will use for stepping.
- `run-state-machine-with-context` returns the machine, transition records, and context for workflow embedding. If you omit `:context`, it creates a fresh context seeded with the machine's current state.
- Protocols provide uniform introspection across the major flow objects.

## Architecture

`cl-dataflow` keeps the implementation deliberately small:

- `src/package.lisp` defines the public package and exported API surface.
- `src/core.lisp` holds the shared graph, node, and context primitives.
- `src/protocols.lisp` defines the shared introspection and printing protocols.
- `src/pipeline.lisp`, `src/events.lisp`, `src/effects.lisp`, and `src/state-machine.lisp` split the runtime behavior into focused files.
- `src/testing.lisp` contains deterministic test helpers, including state-machine assertions.
- The graph runtime models edges as a `cl-prolog` fact base. `topological-sort`
  and `graph-reachable-p` read the edge relation with a single bulk
  `cl-prolog:query-prolog`, then run linear, stack-safe traversals (Kahn's
  algorithm and a work-list search) over the materialized adjacency. This uses
  Prolog as the relational store while deliberately keeping the bounded graph
  algorithms in Lisp, so cyclic or adversarially deep graphs cannot trigger the
  non-termination or exponential-path blow-ups that a naive recursive
  `reachable/2` rule would.
- `cl-dataflow.asd` loads the library system and routes `asdf:test-system :cl-dataflow` to `cl-dataflow/test`.
- `examples/` contains runnable scripts that bootstrap the ASDF system for zero-setup demonstrations.

## Examples

Runnable examples are provided as plain scripts:

- `examples/simple-pipeline.lisp`
- `examples/event-workflow.lisp` - a pipeline that emits events and advances a state machine
- `examples/state-machine.lisp` - a standalone state machine transition flow
- `examples/graph-analysis.lisp` - reachability analysis (descendants, ancestors, shortest path, boundaries) over a dataflow graph
- `examples/graph-toolkit.lisp` - strongly connected components, topological generations, transpose, distance, and DOT/Mermaid rendering
- `examples/state-machine-visualization.lisp` - state/event enumeration, reachability, terminal and unreachable states, and DOT/Mermaid rendering
- `examples/resilient-pipeline.lisp` - retrying and fallback node wrappers plus result-threading pipeline sequencing
- `examples/streams.lisp` - lazy stream pipelines (map/filter/take/scan/flat-map/distinct) over an unbounded range

Run them with SBCL:

```bash
sbcl --script examples/simple-pipeline.lisp
sbcl --script examples/event-workflow.lisp
sbcl --script examples/state-machine.lisp
sbcl --script examples/graph-analysis.lisp
sbcl --script examples/graph-toolkit.lisp
sbcl --script examples/state-machine-visualization.lisp
sbcl --script examples/resilient-pipeline.lisp
sbcl --script examples/streams.lisp
```

Expected outputs:

- `examples/simple-pipeline.lisp` prints `Simple pipeline result: rendered: 70`
- `examples/event-workflow.lisp` prints the final workflow state and event trace
- `examples/state-machine.lisp` prints `Final state: completed`, the transition count, and the last transition record
- `examples/graph-analysis.lisp` prints the downstream/upstream node sets, the shortest `ingest -> load` path, and the graph's source and sink nodes
- `examples/graph-toolkit.lisp` prints the graph order/size, topological generations, `a -> d` distance, strongly connected components, and DOT/Mermaid diagrams
- `examples/state-machine-visualization.lisp` prints the state and event sets, reachable/unreachable/terminal states, the determinism verdict, and DOT/Mermaid diagrams
- `examples/resilient-pipeline.lisp` prints `Retry result: 70 (after 3 attempts)`, the fallback results, and the sequenced pipeline result
- `examples/streams.lisp` prints `First 3 even squares: (4 16 36)`, the running totals, the flat-mapped list, and the distinct sum

## Testing

The test ASDF system is `cl-dataflow/test`. `asdf:test-system :cl-dataflow`
dispatches to the cl-weave suite. The suite dogfoods advanced cl-weave usage:
property-based generators (`gen-tuple`, `gen-list`, `gen-integer`), custom
matchers (`:to-have-valid-topological-order`, `:to-be-acyclic`, `:to-reach`),
differential property tests that cross-check `graph-reachable-p` against an
independent reference transitive closure over random DAGs, and a
`:to-run-under-ms` performance guard that keeps deep-graph topological sort and
reachability from regressing into superlinear behavior.

GitHub Actions runs the CI workflow on a matrix of `ubuntu-latest`
(`x86_64-linux`) and `macos-latest` (`aarch64-darwin`), so the documented
cross-platform support is verified on every push and pull request. Each job runs
the same `nix flake check` and coverage build as local verification and uploads
the generated per-system coverage report as an artifact. Pushing a `vX.Y.Z` tag
additionally triggers the release workflow, which publishes a GitHub release
using the matching `CHANGELOG.md` section.

```bash
nix run
nix flake check
```

Coverage is measured only for source files owned by the `cl-dataflow` ASDF
system. The coverage check requires at least 84% expression coverage and 100%
branch coverage; falling below either threshold fails the command. Run the same
gate locally with `./scripts/coverage.sh`. The output paths and thresholds can
be overridden with `COVERAGE_OUTPUT`, `COVERAGE_REPORT_DIR`,
`COVERAGE_MIN_EXPRESSION`, and `COVERAGE_MIN_BRANCH`.

The current verification commands are:

```bash
./scripts/verify.sh
nix build .#checks.$(nix eval --impure --raw --expr builtins.currentSystem).coverage
sbcl --script examples/simple-pipeline.lisp
sbcl --script examples/event-workflow.lisp
sbcl --script examples/state-machine.lisp
```

The test suite currently covers branching pipeline behavior, event emission,
state-machine transitions, effect handling, and the pipeline/state-machine
workflow integration used by the examples. It also covers the exported testing
helpers, including singleton expectations for event/effect assertions and
runtime-context seeding via `run-pipeline-with-test-context`.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the local workflow and verification commands.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md) for the current project history.

## Security

See [`SECURITY.md`](SECURITY.md) for vulnerability reporting guidance.

## Code Of Conduct

See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) for discussion expectations and project norms.

## Development Notes

- The repository is verified with SBCL and the commands above. Other Common Lisp implementations may work, but they are not currently part of the documented verification surface.
- Collection readers return snapshots for safe inspection. Use the documented setters when you want to replace the live collection.
- `context-effect-handlers` is the one intentionally mutable collection reader because it is the registration surface for effect handlers.
- `copy-context` copies the handler table, so you can fork a context and mutate handler registration independently from the original.
- `run-pipeline-with-test-context` seeds `state`, `metadata`, and effect handlers onto a fresh context and returns that live context after execution.
- `assert-emitted-events` and `assert-performed-effects` accept either a single expected type or a list of expected types.
- `topological-sort` is deterministic for independent nodes, which keeps graph execution order stable across implementations.
- The example scripts double as smoke tests for the core execution paths, so keep them green when changing runtime behavior.

## Design Non-Goals

`cl-dataflow` is intentionally not:

- a CLI framework
- parser combinators
- terminal or TTY handling
- a Prolog engine
- an HTTP server
- a database adapter
- a distributed execution runtime
- an async runtime
- a large dependency injection framework
- a generic utility package

## Repository Layout

```text
cl-dataflow/
  README.md
  LICENSE
  cl-dataflow.asd
  src/
  tests/
  examples/
```

## License

MIT
