(in-package #:cl-dataflow)

;;;; Critical-node and critical-connection analysis over the undirected view of a
;;;; graph: articulation points (cut vertices) and bridges (cut connections) --
;;;; the single points of failure in a dataflow graph. Both are computed the
;;;; recursion-free way: remove the element and recount weakly connected
;;;; components. This is O(V*(V+E)) / O(E*(V+E)) -- linear traversals over the
;;;; whole graph per candidate -- but never grows the control stack, matching the
;;;; library's deep-graph guarantees, and correctly handles multigraphs.

(defun graph-articulation-points (graph)
  "Return the names of the articulation points (cut vertices) of GRAPH's undirected
view, ordered lexicographically. A node is an articulation point when removing it
increases the number of weakly connected components -- i.e. it is a single point of
failure whose loss disconnects the graph."
  (let ((base (length (graph-connected-components graph))))
    (sort (loop for name in (graph-node-names graph)
                when (> (length (graph-connected-components (remove-node (copy-graph graph) name)))
                        base)
                collect name)
          #'string<)))

(defun %unordered-pair-key (a b)
  "A canonical key for the unordered pair {A, B} so both endpoint orderings match."
  (if (string< a b)
      (format nil "~A~C~A" a #\Nul b)
      (format nil "~A~C~A" b #\Nul a)))

(defun %undirected-edge-pairs (graph)
  "The distinct unordered adjacent node pairs (A . B) with A string< B, ignoring
self-loops."
  (let ((seen (make-hash-table :test #'equal))
        (pairs '()))
    (dolist (edge (%graph-edges-list graph) pairs)
      (let ((from (edge-from edge))
            (to (edge-to edge)))
        (unless (equal from to)
          (let ((key (%unordered-pair-key from to)))
            (unless (gethash key seen)
              (setf (gethash key seen) t)
              (push (if (string< from to) (cons from to) (cons to from)) pairs))))))))

(defun %graph-without-undirected-pair (graph from to)
  "A copy of GRAPH with every edge between FROM and TO (in either direction)
removed."
  (let ((copy (copy-graph graph))
        (key (%unordered-pair-key from to)))
    (setf (%graph-edges-list copy)
          (remove-if (lambda (edge)
                       (equal (%unordered-pair-key (edge-from edge) (edge-to edge)) key))
                     (%graph-edges-list copy)))
    copy))

(defun graph-bridges (graph)
  "Return the critical connections of GRAPH's undirected view as a list of (A B)
pairs (A string< B), ordered lexicographically. A connection is critical when
removing every edge between its two nodes leaves them in different weakly connected
components. For a simple graph this is exactly the set of bridges; a connection
carried by parallel edges is critical only if severing all of them disconnects it."
  (sort (loop for pair in (%undirected-edge-pairs graph)
              for reduced = (%graph-without-undirected-pair graph (car pair) (cdr pair))
              unless (graph-undirected-reachable-p reduced (car pair) (cdr pair))
              collect (list (car pair) (cdr pair)))
        (lambda (left right)
          (string< (%unordered-pair-key (first left) (second left))
                   (%unordered-pair-key (first right) (second right))))))
