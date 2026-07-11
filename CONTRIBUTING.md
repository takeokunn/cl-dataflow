# Contributing

`cl-dataflow` is intentionally small and test-driven. Contributions are easiest to review when they preserve that shape.

## Before you change code

- Read `README.md` to understand the public API and current verification surface.
- Prefer the smallest change that improves the real behavior or documentation.
- Keep collection readers returning snapshots unless a mutation surface is explicitly intended.

## Local verification

Use the same commands the repository documents, or run the bundled verifier:

```bash
./scripts/verify.sh
sbcl --noinform --eval '(require :asdf)' --eval '(progn (push #P"./" asdf:*central-registry*) (asdf:test-system :cl-dataflow) (quit))'
sbcl --script examples/simple-pipeline.lisp
sbcl --script examples/event-workflow.lisp
sbcl --script examples/state-machine.lisp
```

If you add or change public behavior, update or add the narrowest test that proves it.

## Style

- Keep the API surface explicit and documented.
- Prefer snapshot semantics for readers of mutable collections.
- Keep example scripts runnable as smoke tests.
- Use ASCII unless the existing file clearly needs something else.

## Pull requests

- Summarize the user-visible change first.
- Call out any compatibility impact.
- Include the verification commands you ran.
