# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Graph analysis API (`graph-algorithms.lisp`): `graph-node-names`, `graph-order`, `graph-size`, `graph-empty-p`, `graph-successors`, `graph-predecessors`, `graph-out-degree`, `graph-in-degree`, `graph-transpose`, `graph-acyclic-p`, `graph-strongly-connected-components` (iterative Kosaraju), `graph-connected-components` (weakly connected), `graph-topological-generations` (parallelizable layers), and `graph-distance` (shortest hop count). Each builds the adjacency snapshot once and walks it with an explicit work list, so all stay linear and terminate on deep and cyclic graphs, matching the existing reachability API's guarantees.
- Graph export API (`graph-export.lisp`): deterministic `graph->dot` (Graphviz) and `graph->mermaid` renderers, plus a `graph-to-plist`/`plist-to-graph` structural round trip for persisting, diffing, and transmitting graph shape (node handlers, being runtime closures, are intentionally not serialized).
- State-machine analysis API (`state-machine-analysis.lisp`): `state-machine-states`, `state-machine-event-types`, `state-machine-reachable-states`, `state-machine-unreachable-states`, `state-machine-terminal-states`, `state-machine-deterministic-p` (structural determinism, guard-independent), and deterministic `state-machine->dot`/`state-machine->mermaid` rendering.
- Combinator API (`combinators.lisp`): handler adapters/wrappers (`mapping-handler`, `compose-handlers`, `retrying-handler`, `fallback-handler`, `memoizing-handler`, `tapping-handler`), node wrappers (`wrap-node`, `node-with-retry`, `node-with-fallback`, `node-with-memoization`, `node-with-tap`) that re-wrap an existing node's handler, and `run-pipeline-sequence` for threading one pipeline's result into the next through a shared, observable context.
- Stream/transducer API (`streams.lisp`): a lazy pull-based `flow-stream` with operators `stream-map`, `stream-filter`, `stream-scan`, `stream-take`, `stream-drop`, `stream-take-while`, `stream-drop-while`, `stream-distinct`, `stream-flat-map`, `stream-concat`, `stream-zip`, `stream-tap`; constructors `stream-of`, `list->stream`, `empty-stream`, `stream-range`; and consumers `stream-collect`, `stream-reduce`, `stream-for-each`, `stream-count`, `stream-first`, `stream-empty-p`. Operators are pure (streams re-consume identically) and their per-pull skip loops are iterative, so filtering long runs never grows the control stack.
- New runnable examples: `examples/graph-toolkit.lisp`, `examples/state-machine-visualization.lisp`, `examples/resilient-pipeline.lisp`, and `examples/streams.lisp`, each registered in the example smoke-test suite.
- 97 new tests covering the five modules (graph algorithms, export/serialization round trips, state-machine analysis, combinator behavior including retry/fallback/memoization, and stream laziness/purity/composition), bringing the suite from 189 to 286.

## [0.1.0] - 2026-07-20

First public release. `cl-dataflow` provides composable computation graphs,
sequential and branching pipelines, event-driven workflows, guarded state
machines, effect boundaries, and deterministic testing helpers behind a single
public package.

### Added

- Public graph, node, edge, context, event, effect, state-machine, and pipeline primitives behind the single `cl-dataflow` package.
- `graph-descendants` and `graph-ancestors` public readers that return every node reachable from (respectively, able to reach) a given node, as name-ordered node snapshots. They reuse the bulk-query adjacency traversal, so they are linear and terminate on cyclic graphs, and are cross-checked against a reference transitive closure in the property suite.
- `graph-path`, which returns the node names of a shortest witnessing path between two nodes (or `NIL` when unreachable) via breadth-first search over the same adjacency, completing the reachability API family and property-checked for validity and agreement with `graph-reachable-p`.
- Explicit `copy-context`, `copy-event`, `copy-effect`, and `copy-pipeline` helpers alongside the existing snapshot-safe APIs.
- Structured error conditions with detail readers for graph lookups, cycles, effect-handler misses, invalid transitions, and guard failures (`node-not-found-designator`, `graph-cycle-nodes`, and the effect/state-machine detail readers).
- Advanced cl-weave coverage: custom matchers (`:to-be-acyclic`, `:to-reach`), differential property tests that cross-check `graph-reachable-p` against a reference transitive closure over random DAGs, model-based/stateful tests that replay `gen-state-machine` traces through `run-state-machine` and compare against a reference transition model, determinism checks, guarded-selection tests, and `:to-run-under-ms` performance/anti-DoS guards for deep chains, exponential-path lattices (WIDTH^(LAYERS-1) distinct paths), and large directed cycles -- locking in that reachability stays linear and terminating on the shapes a naive recursive Prolog rule would blow up on.
- A single `./scripts/verify.sh` entrypoint for tests and example smoke checks.
- Runnable bootstrap-based examples for pipeline, event workflow, state machine, and graph-analysis flows.

### Changed

- Made the flake reference the architecture-independent `cl-prolog` source tree directly, so the dev shell, checks, and `nix run` work on every system now that upstream ships Linux-only per-system packages.
- Rebuilt `topological-sort` to read the full edge relation with a single bulk `cl-prolog:query-prolog` call and drain a merge-ordered ready queue, cutting it from O(V*E) Prolog work plus a per-iteration re-sort down to linear adjacency construction with the same deterministic order.
- Rebuilt `graph-reachable-p` to materialize the successor relation once and walk it with an explicit work list, so deep graphs no longer overflow the control stack and reachability issues one Prolog query instead of two per visited node.
- Derived source/sink boundary nodes (`graph-source-nodes`, `graph-sink-nodes`) and pipeline sink-result collection from a single adjacency snapshot instead of a per-node Prolog query that rebuilt the whole rulebase each time, cutting pipeline result collection from O(V^2 + V*E) to linear.
- Stopped the `graph-nodes` and `graph-edges` readers from running a full topological sort on every call: they now perform only cheap O(V+E) structural validation, so reads are no longer superlinear and a legally constructed cyclic graph stays inspectable and copyable.
- Cut `run-pipeline` from O(V*E) to O(V+E) per run by building the incoming-edge index once per pipeline execution instead of rescanning the full edge list for every stage.
- Cut `context-last-event`/`context-last-effect` from O(n) to O(1) by reading the most recent entry directly off the raw newest-first storage list.
- Cut event/effect `trace-index` allocation from O(n) to O(1) per call by tracking a running trace-count slot instead of re-deriving it from `(length trace)` on every `emit-event`/`perform-effect`/state-machine transition; all trace-list mutation now goes through a single `%push-context-trace-entry` append point so the counter cannot drift from the list.
- Made `add-node` reject duplicate node names and `add-edge` reject duplicate edge definitions instead of silently replacing or double-counting them.
- Made `context-result`, `event-payload`, `event-metadata`, `effect-payload`, `effect-metadata`, `effect-result`, and `transition-metadata` return independent snapshots on read.
- Made topological ordering deterministic for independent nodes so graph-backed execution and sink collection stay stable.
- Made `%normalize-name` bind the printer control variables so non-symbol node/port designators normalize deterministically regardless of the caller's `*print-base*` and related bindings.

### Fixed

- Fixed pipeline input binding for nodes with more than one incoming edge on the same port: resolution now deterministically prefers the most recently added edge instead of an insertion-order accident that silently favoured the oldest one.
- Fixed `graph-source-nodes` and `graph-sink-nodes` to stay inspectable on a legally constructed cyclic graph instead of raising `graph-cycle-error`, matching the inspectability `graph-nodes`/`graph-edges` already guarantee.
- Fixed guarded state-machine transition selection: when several transitions share a `(state, event)` pair, a rejecting guard now falls through to the next candidate, and `guard-failed-error` is signalled only when every matching guard rejects. `state-machine-can-step-p` uses the same guard-aware selection.
- Fixed `define-pipeline` and `define-workflow` to evaluate a `:metadata`/`:pipeline-metadata` form once instead of twice, and to gensym their internal `graph`, `edge`, and `machine` bindings so user handler/guard/action forms can no longer capture them.

[Unreleased]: https://github.com/takeokunn/cl-dataflow/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/takeokunn/cl-dataflow/releases/tag/v0.1.0
