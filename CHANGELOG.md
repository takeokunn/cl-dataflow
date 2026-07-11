# Changelog

## Unreleased

- Added a single `./scripts/verify.sh` entrypoint for tests and example smoke checks.
- Documented the verification script in the README and contributing guide.
- Exported detail readers for effect and state-machine error conditions so callers can inspect failures directly.
- Added a copied effect snapshot to `effect-handler-missing-error` for richer diagnostics.
- Added `node-not-found-designator` so graph lookup failures expose the missing node name or edge reference.
- Added `graph-cycle-nodes` so cycle detection exposes the remaining cyclic component.
- Made `add-node` reject duplicate node names instead of silently replacing existing nodes.
- Made `add-edge` reject duplicate edge definitions instead of counting them twice.
- Added structured state-machine error readers for invalid transitions and guard failures.
- Added explicit `copy-context`, `copy-event`, and `copy-effect` helpers alongside the existing snapshot-safe APIs.
- Clarified that `copy-context` clones the effect-handler table so derived contexts can customize registrations safely.
- Made `context-result` return an independent snapshot on read so pipeline results stay isolated from caller-side mutation.
- Made `event-payload`, `event-metadata`, `effect-payload`, `effect-metadata`, `effect-result`, and `transition-metadata` return independent snapshots on read.
- Documented that `state-machine-can-step-p` accepts `:context` for guarded-transition preflighting and that `run-state-machine-with-context` creates a seeded context when one is omitted.
- Clarified that `make-state-machine-node` accepts event objects from `event-fn` in addition to event designators.
- Documented the public pipeline contract for normalized structured node inputs and outputs.
- Clarified that `pipeline-graph` is the live validated graph owned by a pipeline, and that `copy-pipeline` is the isolated-clone entry point.
- Added explicit `copy-pipeline` support to clone pipeline graphs, stage order, and metadata together.
- Ensured graph-backed pipelines remap stages onto the copied graph so cloned pipelines stay internally coherent.
- Ensured `pipeline-graph` setter remaps existing stages onto the new copied graph.
- Made topological ordering deterministic for independent nodes so graph-backed execution and sink collection stay stable.
- Documented that `graph-source-nodes` and `graph-sink-nodes` return independent snapshots like the other collection readers.
- Added snapshot-safe graph, context, pipeline, and state-machine APIs.
- Added runnable bootstrap-based examples for pipeline, event workflow, and state machine flows.
- Expanded test coverage for copy semantics, protocol introspection, and example execution.
