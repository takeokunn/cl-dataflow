(in-package #:cl-dataflow)

(defparameter +graph-node-predicate+ 'graph-node)
(defparameter +graph-edge-predicate+ 'graph-edge)

(defun %graph-rulebase (graph)
  (let ((clauses '()))
    (maphash (lambda (name node)
                (declare (ignore node))
                (push (cl-prolog:make-clause
                      (list +graph-node-predicate+ name)
                      '())
                      clauses))
              (%graph-nodes-table graph))
    (dolist (edge (%graph-edges-list graph))
      (unless (and (gethash (edge-from edge) (%graph-nodes-table graph))
                    (gethash (edge-to edge) (%graph-nodes-table graph)))
        (%signal-node-not-found-error
          graph
          edge
          (format nil "Edge references missing node: ~A -> ~A"
                  (edge-from edge)
                  (edge-to edge))))
      (push (cl-prolog:make-clause
              (list +graph-edge-predicate+
                    (edge-from edge)
                    (edge-to edge))
              '())
            clauses))
    (cl-prolog:make-rulebase :clauses (nreverse clauses))))

(defun %graph-related-node-names (rulebase query variable)
  (let ((names '()))
    (cl-prolog:map-prolog-solutions
      (lambda (solution)
        (pushnew (cl-prolog:solution-binding variable solution)
                names
                :test #'equal))
      rulebase
      query)
    (sort names #'string<)))

(defun %graph-predecessor-names (graph rulebase node-name)
  (when (%graph-edges-list graph)
    (%graph-related-node-names
      rulebase
      (list +graph-edge-predicate+ '?predecessor node-name)
      '?predecessor)))

(defun %graph-successor-names (graph rulebase node-name)
  (when (%graph-edges-list graph)
    (%graph-related-node-names
      rulebase
      (list +graph-edge-predicate+ node-name '?successor)
      '?successor)))

(defun %graph-edge-exists-p (graph rulebase from to)
  (and (%graph-edges-list graph)
        (cl-prolog:prolog-succeeds-p
        rulebase
        (list +graph-edge-predicate+ from to))))

(defun graph-reachable-p (graph from to)
  "Return true when TO is reachable from FROM through one or more graph edges."
  (let* ((from-name (%node-designator-name from))
          (to-name (%node-designator-name to))
          (rulebase (%graph-rulebase graph))
          (visited (make-hash-table :test #'equal)))
    (%ensure-graph-node graph from-name)
    (%ensure-graph-node graph to-name)
    (labels ((reachable-p (name)
                (or (%graph-edge-exists-p graph rulebase name to-name)
                    (progn
                      (setf (gethash name visited) t)
                      (some (lambda (successor)
                              (and (not (gethash successor visited))
                                  (reachable-p successor)))
                            (%graph-successor-names graph rulebase name))))))
      (reachable-p from-name))))
