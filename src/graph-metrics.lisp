(in-package #:cl-dataflow)

;;;; Whole-graph metrics and comparisons: edge density, degree distribution,
;;;; bipartiteness, structural equality, and weak (undirected) reachability.
;;;; Structural predicates reuse the deterministic GRAPH-TO-PLIST snapshot and the
;;;; connected-component / adjacency machinery rather than re-deriving structure.

(defun %distinct-edge-count (graph)
  "Number of distinct (from . to) pairs in GRAPH; parallel edges count once."
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (edge (%graph-edges-list graph))
      (setf (gethash (cons (edge-from edge) (edge-to edge)) seen) t))
    (hash-table-count seen)))

(defun graph-density (graph)
  "Return the directed edge density of GRAPH: distinct edges divided by the maximum
possible V*(V-1). Returns 0 when GRAPH has fewer than two nodes. Parallel edges
across distinct ports count once."
  (let ((order (graph-order graph)))
    (if (< order 2)
        0
        (/ (%distinct-edge-count graph) (* order (1- order))))))

(defun graph-degree-histogram (graph)
  "Return an alist (DEGREE . COUNT) over each node's total degree -- the number of
distinct successors plus distinct predecessors -- ordered by ascending degree."
  (let ((successors (%graph-adjacency-snapshot graph :successors))
        (predecessors (%graph-adjacency-snapshot graph :predecessors))
        (counts (make-hash-table :test #'eql)))
    (dolist (name (%graph-node-name-set graph))
      (incf (gethash (+ (length (gethash name successors))
                        (length (gethash name predecessors)))
                     counts 0)))
    (sort (loop for degree being the hash-keys of counts using (hash-value count)
                collect (cons degree count))
          #'< :key #'car)))

(defun graph-bipartite-p (graph)
  "Return true when GRAPH's underlying undirected graph is 2-colourable (bipartite).
Edge direction is ignored; a self-loop makes the graph non-bipartite."
  (let ((adjacency (%undirected-adjacency graph))
        (color (make-hash-table :test #'equal)))
    (block done
      (dolist (start (%graph-node-name-set graph) t)
        (unless (gethash start color)
          (setf (gethash start color) 0)
          (let ((frontier (list start)))
            (loop while frontier do
              (let ((next '()))
                (dolist (name frontier)
                  (let ((name-color (gethash name color)))
                    (dolist (neighbor (gethash name adjacency))
                      (let ((neighbor-color (gethash neighbor color)))
                        (cond
                          ((null neighbor-color)
                           (setf (gethash neighbor color) (- 1 name-color))
                           (push neighbor next))
                          ((= neighbor-color name-color)
                           (return-from done nil)))))))
                (setf frontier next)))))))))

(defun graph-equal-p (graph-a graph-b)
  "Return true when GRAPH-A and GRAPH-B are structurally identical: the same nodes
(names, ports, metadata) and the same edges (endpoints, ports, metadata),
independent of insertion order. Node handlers are runtime closures and are not
compared (see GRAPH-TO-PLIST)."
  (equal (graph-to-plist graph-a) (graph-to-plist graph-b)))

(defun graph-undirected-reachable-p (graph from to)
  "Return true when FROM and TO lie in the same weakly connected component of GRAPH
(edge direction ignored). A node is always undirected-reachable from itself."
  (let ((from-name (%node-designator-name from))
        (to-name (%node-designator-name to)))
    (%ensure-graph-node graph from-name)
    (%ensure-graph-node graph to-name)
    (let ((component (find-if (lambda (names) (member from-name names :test #'equal))
                              (graph-connected-components graph))))
      (and (member to-name component :test #'equal) t))))
