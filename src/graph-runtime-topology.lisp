(in-package #:cl-dataflow)

(defun %incoming-edges (graph node-name)
  (remove-if-not (lambda (edge)
                    (equal (edge-to edge) node-name))
                  (%graph-edges-list graph)))

(defun %boundary-nodes (graph boundary-key)
  "Copies of the graph's source (BOUNDARY-KEY :source) or sink (:sink) nodes in
topological order. Boundaries are read from a single adjacency snapshot -- a node
with indegree 0 is a source, a node with no successors is a sink -- instead of a
Prolog query per node."
  (let ((rulebase (%graph-rulebase graph)))
    (multiple-value-bind (successors indegree)
        (%graph-adjacency graph rulebase)
      (mapcar #'%copy-node-snapshot
              (remove-if-not
                (lambda (node)
                  (let ((name (node-name node)))
                    (ecase boundary-key
                      (:source (zerop (gethash name indegree)))
                      (:sink (null (gethash name successors))))))
                (topological-sort graph))))))

(defun graph-source-nodes (graph)
  (%boundary-nodes graph :source))

(defun graph-sink-nodes (graph)
  (%boundary-nodes graph :sink))

(defun %seed-topological-queue (indegree)
  (let ((queue '()))
    (maphash (lambda (name count)
                (declare (ignore count))
                (when (zerop (gethash name indegree))
                  (push name queue)))
              indegree)
    (sort queue #'string<)))

(defun %drain-topological-queue (queue successors indegree nodes)
  "Kahn's algorithm over precomputed SUCCESSORS/INDEGREE tables.

The ready queue is kept in string< order by merging each batch of newly-ready
successors into it, so it never re-sorts the whole queue per iteration yet still
pops the lexicographically smallest ready node -- giving a deterministic order
identical to the previous full-re-sort implementation."
  (let ((result '())
        (processed (%make-result-table)))
    (loop while queue do
      (let* ((name (pop queue))
              (node (gethash name nodes))
              (newly-ready '()))
        (push node result)
        (setf (gethash name processed) t)
        (dolist (successor (gethash name successors))
          (when (zerop (decf (gethash successor indegree)))
            (push successor newly-ready)))
        (when newly-ready
          (setf queue (merge 'list queue (sort newly-ready #'string<) #'string<)))))
    (values (nreverse result) processed)))

(defun %unprocessed-cycle-nodes (nodes processed)
  (let ((cycle-nodes '()))
    (maphash (lambda (name node)
                (unless (gethash name processed)
                  (push node cycle-nodes)))
              nodes)
    (sort cycle-nodes #'string< :key #'node-name)))

(defun topological-sort (graph)
  (let ((nodes (%graph-nodes-table graph))
        (rulebase (%graph-rulebase graph)))
    (multiple-value-bind (successors indegree)
        (%graph-adjacency graph rulebase)
      (multiple-value-bind (result processed)
          (%drain-topological-queue (%seed-topological-queue indegree)
                                    successors
                                    indegree
                                    nodes)
        (unless (= (length result) (hash-table-count nodes))
          (error 'graph-cycle-error
                  :graph graph
                  :nodes (mapcar #'%copy-node-snapshot
                                (%unprocessed-cycle-nodes nodes processed))
                  :detail "Graph contains a cycle or disconnected cycle component."))
        result))))
