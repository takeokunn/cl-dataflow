# cl-dataflow Implementation Prompt

You are an expert Common Lisp library author and OSS maintainer.

Create a new OSS Common Lisp library named `cl-dataflow`.

## Goal

`cl-dataflow` is a framework for building composable pipelines, event-driven workflows, and stateful computation graphs.

It should provide a small, general, well-tested foundation for:

- computation graphs
- pipelines
- event-driven workflows
- state machines
- effect boundaries
- deterministic workflow testing

## Non-Goals

Do not implement:

- CLI framework
- parser combinators
- terminal/TTY handling
- Prolog engine
- HTTP server
- database adapter
- distributed execution
- async runtime
- large dependency injection framework
- generic utility package

## Design Principles

- Keep the core small.
- Prefer protocols and generic functions over inheritance-heavy designs.
- Avoid app-specific concepts.
- Avoid unnecessary dependencies.
- Public exported symbols are API.
- Every public behavior must have tests.
- Make examples practical and minimal.
- Design for SBCL first.
- Avoid SBCL-specific code unless isolated.
- Use ASDF systems and packages cleanly.
- Do not create a catch-all `utils` package.
- Avoid excessive comments.

## Repository Structure

```text
cl-dataflow/
  README.md
  LICENSE
  cl-dataflow.asd
  src/
    package.lisp
    core.lisp
    protocols.lisp
    events.lisp
    state-machine.lisp
    effects.lisp
    pipeline.lisp
    testing.lisp
  tests/
    package.lisp
    core-test.lisp
    events-test.lisp
    state-machine-test.lisp
    effects-test.lisp
    pipeline-test.lisp
  examples/
    simple-pipeline.lisp
    event-workflow.lisp
    state-machine.lisp
```

## ASDF Systems

Define:

```lisp
:cl-dataflow
:cl-dataflow/test
```

The test system must support:

```lisp
(asdf:test-system :cl-dataflow)
```

Use FiveAM if a test dependency is needed. Keep the main library dependency-light.

## Public Package

Create one public package:

```lisp
:cl-dataflow
```

Internal packages are allowed only if they reduce complexity.

## Core Concepts

### Node

A node represents a unit of computation.

A node has:

- name
- input ports
- output ports
- handler function
- metadata

### Edge

An edge connects one node output port to another node input port.

### Graph

A graph contains nodes and edges.

Support:

- create graph
- add node
- add edge
- find node
- validate graph
- topological sort

### Context

A context carries runtime values, emitted events, performed effects, effect handlers, and metadata.

### Pipeline

A pipeline is an executable graph or sequence of stages.

Support:

- sequential pipelines
- branching pipelines if simple
- error propagation
- result collection

### Events

Provide:

- event object
- event type
- payload
- metadata
- event trace
- `emit-event`

### State Machine

Provide:

- states
- transitions
- guards
- actions
- current state
- step function

State machines should work independently and inside pipelines.

### Effects

Provide practical effect boundaries.

Support:

- effect object
- effect type
- payload
- effect handler lookup
- `perform-effect`
- test handlers

This is not a full algebraic effects system.

### Testing Helpers

Provide helpers for:

- running pipelines with test context
- asserting emitted events
- asserting performed effects
- asserting final state
- asserting pipeline result

## Suggested Public API

Use this as a starting point:

```lisp
make-node
node-name
node-inputs
node-outputs
node-metadata

make-edge
edge-from
edge-to

make-graph
graph-nodes
graph-edges
copy-graph
add-node
add-edge
find-node
validate-graph
topological-sort

make-context
context-events
context-effects
context-metadata

make-event
event-type
event-payload
emit-event

make-effect
effect-type
effect-payload
perform-effect

make-pipeline
run-pipeline

make-state-machine
step-state-machine
state-machine-state
```

You may adjust names if the resulting API is cleaner, but keep it small and coherent.

## Examples

Create runnable examples for:

### Simple Pipeline

```text
parse input -> validate -> transform -> render
```

### Event Workflow

```text
order-created -> reserve-inventory -> payment-requested -> order-confirmed
```

### State Machine

```text
idle -> running -> completed
idle -> running -> failed
```

## README Requirements

Write an OSS-quality README with:

- project description
- installation using ASDF/local-projects
- basic example
- core concepts
- API overview
- testing instructions
- design non-goals
- license

The README must clearly state that `cl-dataflow` is about computation flow, not CLI, parsing, terminal handling, Prolog, or generic utilities.

## Tests

Write tests for:

- node creation
- edge creation
- graph validation
- topological sort
- sequential pipeline execution
- branching pipeline execution if implemented
- event emission
- event trace
- effect handler execution
- missing effect handler behavior
- state machine transition
- guard behavior
- invalid transition behavior

## Verification

Before finishing:

- Ensure ASDF systems load cleanly.
- Ensure tests run.
- Ensure README examples match implemented API.
- Ensure exported symbols are intentional.
- Ensure there are no circular package dependencies.
- Ensure code is formatted consistently.
- Keep implementation simple enough to understand from tests.

## Deliverable

Create the complete repository files.

After implementation, report:

- files created
- public API symbols
- how to run tests
- intentionally deferred features
