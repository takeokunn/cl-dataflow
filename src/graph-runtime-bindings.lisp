(in-package #:cl-dataflow)

(defun %node-output-bindings (node result)
  (let ((outputs (%node-outputs-list node)))
    (cond
      ((null outputs) '())
      ((%single-output-scalar-result-p outputs result)
       (%scalar-output-binding outputs result))
      (t (%normalize-output-structure result outputs)))))

(defun %binding-list-p (value)
  (and (listp value)
       (or (null value)
           (every #'consp value))))

(defun %single-output-scalar-result-p (outputs result)
  (and (= (length outputs) 1)
       (not (%binding-list-p result))))

(defun %scalar-output-binding (outputs result)
  (list (cons (first outputs) result)))

(defun %node-input-binding (node input)
  (%normalize-structured-input input (%node-inputs-list node)))

(defun %collapse-single-binding-list (bindings)
  (if (= (length bindings) 1)
      (cdar bindings)
      bindings))

(defun %edge-binding-table (incoming-edges)
  (let ((bindings (%make-result-table)))
    (dolist (edge incoming-edges)
      (setf (gethash (edge-to-port edge) bindings) edge))
    bindings))

(defun %incoming-edge-bindings (context node incoming-edges)
  (let ((binding-table (%edge-binding-table incoming-edges)))
    (let ((bindings '()))
      (dolist (port (%node-inputs-list node) (nreverse bindings))
        (let ((edge (gethash port binding-table)))
          (when edge
            (push (cons port
                        (%read-value context
                                     (edge-from edge)
                                     (edge-from-port edge)))
                  bindings)))))))

(defun %collect-node-inputs (context graph node input)
  (let ((incoming (%incoming-edges graph (node-name node))))
    (if incoming
        (%collapse-single-binding-list
         (%incoming-edge-bindings context node incoming))
        (%node-input-binding node input))))

(defun %sink-output-bindings (context node)
  (loop for port in (%node-outputs-list node)
        collect (cons port (%read-value context (node-name node) port))))

(defun %sink-result-entry (context node)
  (cons (node-name node)
        (%sink-output-bindings context node)))

(defun %collapse-single-sink-result (sink-entry)
  (let ((values (cdr sink-entry)))
    (if (= (length values) 1)
        (cdar values)
        values)))

(defun %sink-nodes-in-order (graph order)
  (remove-if-not (lambda (node)
                   (%sink-node-p graph node))
                 order))

(defun %collect-sink-results (graph context order)
  (let ((sinks (mapcar (lambda (node)
                         (%sink-result-entry context node))
                       (%sink-nodes-in-order graph order))))
    (cond
      ((null sinks) nil)
      ((= (length sinks) 1)
       (%collapse-single-sink-result (first sinks)))
      (t sinks))))
