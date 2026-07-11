(in-package #:cl-dataflow)

(%load-fragment #P"core-normalization.lisp")
(%load-fragment #P"core-copying.lisp")
(%load-fragment #P"core-slot-accessors.lisp")
(%load-fragment #P"core-runtime-helpers.lisp")

(declaim (notinline %copy-structured-value
                    %copy-node-snapshot
                    %copy-edge-snapshot
                    %copy-graph-snapshot
                    %copy-event
                    %copy-effect
                    graph-nodes
                    graph-edges
                    graph-metadata
                    context-values
                    context-events
                    context-effects
                    context-trace
                    context-metadata
                    context-effect-handlers
                    context-result
                    context-state
                    event-type
                    event-payload
                    event-metadata
                    event-trace-index
                    effect-type
                    effect-payload
                    effect-metadata
                    effect-trace-index))

(%load-fragment #P"core-conditions.lisp")
(%load-fragment #P"core-models.lisp")
