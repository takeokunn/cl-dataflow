(in-package #:cl-dataflow)

(defun (setf graph-nodes) (nodes graph)
  (setf (slot-value graph 'nodes) (%copy-node-table-snapshot nodes)))

(defun graph-nodes (graph)
  (validate-graph graph)
  (%copy-node-table-snapshot (slot-value graph 'nodes)))

(defun (setf graph-edges) (edges graph)
  (setf (slot-value graph 'edges)
        (mapcar #'%copy-edge-snapshot edges)))

(defun graph-edges (graph)
  (validate-graph graph)
  (mapcar #'%copy-edge-snapshot (slot-value graph 'edges)))

(defun (setf graph-metadata) (metadata graph)
  (setf (slot-value graph 'metadata)
        (%normalize-metadata metadata)))

(defun graph-metadata (graph)
  (copy-tree (slot-value graph 'metadata)))

(defun (setf context-values) (values context)
  (setf (slot-value context 'values)
        (%copy-result-table values)))

(defun context-values (context)
  (%copy-result-table (slot-value context 'values)))

(defun context-events (context)
  (mapcar #'%copy-event (slot-value context 'events)))

(defun (setf context-events) (events context)
  (setf (slot-value context 'events)
        (mapcar #'%copy-event events)))

(defun context-effects (context)
  (mapcar #'%copy-effect (slot-value context 'effects)))

(defun (setf context-effects) (effects context)
  (setf (slot-value context 'effects)
        (mapcar #'%copy-effect effects)))

(defun context-trace (context)
  (mapcar #'%copy-structured-value (slot-value context 'trace)))

(defun (setf context-trace) (trace context)
  (setf (slot-value context 'trace)
        (mapcar #'%copy-structured-value trace)))

(defun (setf context-metadata) (metadata context)
  (setf (slot-value context 'metadata)
        (%normalize-metadata metadata)))

(defun context-metadata (context)
  (copy-tree (slot-value context 'metadata)))

(defun (setf context-result) (result context)
  (setf (slot-value context 'result)
        (%copy-structured-value result)))

(defun context-result (context)
  (%copy-structured-value (slot-value context 'result)))

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
