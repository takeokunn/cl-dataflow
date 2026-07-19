(in-package #:cl-dataflow)

(defun graph-nodes (graph)
  ;; Readers verify structural integrity (ports, edge endpoints) but not
  ;; acyclicity: the old topological-sort on every read was O(V*E) Prolog work
  ;; and, worse, raised on a legally constructed cyclic graph, making it
  ;; impossible to inspect or copy. Acyclicity stays at the explicit entry
  ;; points (validate-graph, topological-sort, pipeline construction).
  (%validate-graph-structure graph)
  (%copy-node-table-snapshot (slot-value graph 'nodes)))

(defun (setf graph-nodes) (nodes graph)
  (setf (slot-value graph 'nodes) (%copy-node-table-snapshot nodes)))

(defun graph-edges (graph)
  (%validate-graph-structure graph)
  (mapcar #'%copy-edge-snapshot (slot-value graph 'edges)))

(defun (setf graph-edges) (edges graph)
  (setf (slot-value graph 'edges) (mapcar #'%copy-edge-snapshot edges)))

(define-slot-apis
  (:copy context-values context values %copy-result-table)
  (:copy context-trace context trace %copy-structured-value)
  (:copy context-result context result %copy-structured-value)
  (:mapcar-copy context-events context events %copy-event)
  (:mapcar-copy context-effects context effects %copy-effect)
  (:transform graph-metadata graph metadata
              (copy-tree (slot-value graph 'metadata))
              (%normalize-metadata value))
  (:transform context-metadata context metadata
              (copy-tree (slot-value context 'metadata))
              (%normalize-metadata value)))

(defun context-events-in-order (context)
  (reverse (context-events context)))

(defun context-effects-in-order (context)
  (reverse (context-effects context)))

(defun context-trace-in-order (context)
  (reverse (context-trace context)))

(defun context-event-types (context)
  (mapcar #'event-type (context-events-in-order context)))

(defun context-effect-types (context)
  (mapcar #'effect-type (context-effects-in-order context)))

(defun context-events-of-type (context type)
  (let ((normalized (%normalize-name type)))
    (remove-if-not (lambda (event)
                      (equal (event-type event) normalized))
                    (context-events-in-order context))))

(defun context-effects-of-type (context type)
  (let ((normalized (%normalize-name type)))
    (remove-if-not (lambda (effect)
                      (equal (effect-type effect) normalized))
                    (context-effects-in-order context))))

(defun %last-copied-item (items copier)
  (let ((item (first (last items))))
    (when item
      (funcall copier item))))

(defun context-last-event (context)
  (%last-copied-item (context-events-in-order context) #'%copy-event))

(defun context-last-effect (context)
  (%last-copied-item (context-effects-in-order context) #'%copy-effect))

(defun context-value (context node &optional (port "value"))
  (%read-value context (%node-designator-name node) (%normalize-name port)))

(defun context-node-values (context node)
  (mapcar (lambda (port)
            (cons port (context-value context node port)))
          (%node-outputs-list node)))
