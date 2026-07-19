(in-package #:cl-dataflow)

;;;; Whole-graph connectivity predicates, the strongly-connected-component
;;;; condensation, and single-source distance metrics. These build on the
;;;; component and adjacency machinery and stay iterative; the condensation is
;;;; always a DAG (a cycle would contradict the components being maximal).

(defun graph-connected-p (graph)
  "Return true when GRAPH is weakly connected -- all nodes lie in one component
(edge direction ignored). The empty graph and a single node are connected."
  (<= (length (graph-connected-components graph)) 1))

(defun graph-strongly-connected-p (graph)
  "Return true when GRAPH is strongly connected -- every node reaches every other,
i.e. it has at most one strongly connected component. The empty graph and a single
node qualify."
  (<= (length (graph-strongly-connected-components graph)) 1))

(defun graph-self-loop-nodes (graph)
  "Return the names of nodes carrying a self-loop edge, ordered lexicographically."
  (sort (remove-duplicates
         (loop for edge in (%graph-edges-list graph)
               when (equal (edge-from edge) (edge-to edge))
               collect (edge-from edge))
         :test #'equal)
        #'string<))

(defun graph-condensation (graph)
  "Return the condensation of GRAPH: a new DAG with one node per strongly connected
component (named by the component's smallest member, with the full member list in
its `:members` metadata) and an edge between components wherever an original edge
crosses between them. GRAPH is not modified."
  (let ((representative (make-hash-table :test #'equal))
        (result (make-graph :metadata (graph-metadata graph))))
    (dolist (component (graph-strongly-connected-components graph))
      (let ((rep (first component)))
        (dolist (member component)
          (setf (gethash member representative) rep))
        (add-node result (make-node rep :metadata (list :members component)))))
    (let ((seen (make-hash-table :test #'equal)))
      (dolist (edge (%graph-edges-list graph))
        (let ((from-rep (gethash (edge-from edge) representative))
              (to-rep (gethash (edge-to edge) representative)))
          (unless (equal from-rep to-rep)
            (let ((key (cons from-rep to-rep)))
              (unless (gethash key seen)
                (setf (gethash key seen) t)
                (add-edge result from-rep to-rep)))))))
    result))

(defun graph-distances-from (graph from)
  "Return an alist (NAME . HOP-DISTANCE) of every node reachable from FROM through
one or more edges, via breadth-first search. FROM itself appears only when a cycle
returns to it. Ordered by name."
  (let ((from-name (%node-designator-name from)))
    (%ensure-graph-node graph from-name)
    (let ((successors (%graph-adjacency graph (%graph-rulebase graph)))
          (distance (make-hash-table :test #'equal))
          (frontier '())
          (depth 1))
      ;; FROM's successors are distinct and DISTANCE starts empty, so no seed
      ;; needs a presence guard (see GRAPH-DISTANCE).
      (dolist (successor (gethash from-name successors))
        (setf (gethash successor distance) depth)
        (push successor frontier))
      (setf frontier (nreverse frontier))
      (loop while frontier do
        (incf depth)
        (let ((next '()))
          (dolist (name frontier)
            (dolist (successor (gethash name successors))
              (unless (gethash successor distance)
                (setf (gethash successor distance) depth)
                (push successor next))))
          (setf frontier (nreverse next))))
      (sort (loop for name being the hash-keys of distance using (hash-value d)
                  collect (cons name d))
            #'string< :key #'car))))

(defun graph-bfs-order (graph from)
  "Return the node names reachable from FROM in breadth-first order, starting with
FROM itself, each appearing once. Ties within a level are broken by name. Iterative,
so deep graphs are safe."
  (let ((from-name (%node-designator-name from)))
    (%ensure-graph-node graph from-name)
    (let ((successors (%graph-adjacency-snapshot graph :successors))
          (visited (make-hash-table :test #'equal))
          (order '())
          (frontier (list from-name)))
      (setf (gethash from-name visited) t)
      (loop while frontier do
        (let ((next '()))
          (dolist (name frontier)
            (push name order)
            (dolist (successor (gethash name successors))
              (unless (gethash successor visited)
                (setf (gethash successor visited) t)
                (push successor next))))
          (setf frontier (nreverse next))))
      (nreverse order))))

(defun graph-dfs-order (graph from)
  "Return the node names reachable from FROM in depth-first preorder, starting with
FROM, each appearing once. The name-least successor is descended first. Iterative
(explicit stack), so deep graphs are safe."
  (let ((from-name (%node-designator-name from)))
    (%ensure-graph-node graph from-name)
    (let ((successors (%graph-adjacency-snapshot graph :successors))
          (visited (make-hash-table :test #'equal))
          (order '())
          (stack (list from-name)))
      (loop while stack do
        (let ((name (pop stack)))
          (unless (gethash name visited)
            (setf (gethash name visited) t)
            (push name order)
            (dolist (successor (reverse (gethash name successors)))
              (unless (gethash successor visited)
                (push successor stack))))))
      (nreverse order))))

(defun graph-eccentricity (graph node)
  "Return the eccentricity of NODE: the greatest hop distance to any node reachable
from it, or 0 when NODE reaches nothing."
  (let ((distances (mapcar #'cdr (graph-distances-from graph node))))
    (if distances
        (reduce #'max distances)
        0)))

(defun graph-closeness-centrality (graph node)
  "Return the closeness centrality of NODE: the number of nodes reachable from it
divided by the total hop distance to all of them, or 0 when NODE reaches nothing. A
higher value means NODE reaches the rest of the graph in fewer hops on average."
  (let* ((distances (mapcar #'cdr (graph-distances-from graph node)))
         (total (reduce #'+ distances :initial-value 0)))
    (if (zerop total)
        0
        (/ (length distances) total))))

(defun graph-diameter (graph)
  "Return the diameter of GRAPH: the largest eccentricity over all nodes -- the
longest shortest-path distance between any reachable pair. 0 for a graph with no
edges."
  (let ((eccentricities (mapcar (lambda (name) (graph-eccentricity graph name))
                                (graph-node-names graph))))
    (if eccentricities
        (reduce #'max eccentricities)
        0)))
