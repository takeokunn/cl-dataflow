(in-package #:cl-dataflow)

(define-slot-apis
  (:copy graph-nodes graph nodes %copy-node-table-snapshot)
  (:copy context-values context values %copy-result-table)
  (:copy context-trace context trace %copy-structured-value)
  (:copy context-result context result %copy-structured-value)
  (:mapcar-copy graph-edges graph edges %copy-edge-snapshot)
  (:mapcar-copy context-events context events %copy-event)
  (:mapcar-copy context-effects context effects %copy-effect)
  (:transform graph-metadata graph metadata
              (copy-tree (slot-value graph 'metadata))
              (%normalize-metadata value))
  (:transform context-metadata context metadata
              (copy-tree (slot-value context 'metadata))
              (%normalize-metadata value)))
