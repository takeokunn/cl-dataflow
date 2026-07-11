(in-package #:cl-dataflow)

(defun %incoming-edges (graph node-name)
  (remove-if-not (lambda (edge)
                   (equal (edge-to edge) node-name))
                 (%graph-edges-list graph)))

(defun %outgoing-edges (graph node-name)
  (remove-if-not (lambda (edge)
                   (equal (edge-from edge) node-name))
                 (%graph-edges-list graph)))

(defun %source-node-p (graph node)
  (null (%incoming-edges graph (node-name node))))

(defun %sink-node-p (graph node)
  (null (%outgoing-edges graph (node-name node))))

(defun graph-source-nodes (graph)
  (mapcar #'%copy-node-snapshot
          (remove-if-not (lambda (node)
                           (%source-node-p graph node))
                         (topological-sort graph))))

(defun graph-sink-nodes (graph)
  (mapcar #'%copy-node-snapshot
          (remove-if-not (lambda (node)
                           (%sink-node-p graph node))
                         (topological-sort graph))))

(defun %initialize-topological-state (nodes)
  (let ((indegree (%make-result-table))
        (adjacency (%make-result-table)))
    (maphash (lambda (name node)
               (declare (ignore node))
               (setf (gethash name indegree) 0
                     (gethash name adjacency) '()))
             nodes)
    (values indegree adjacency)))

(defun %register-topological-edge (graph edge nodes indegree adjacency)
  (unless (and (gethash (edge-from edge) nodes)
               (gethash (edge-to edge) nodes))
    (error 'node-not-found-error
           :graph (%copy-error-value graph)
           :designator (%copy-error-value edge)
           :detail (format nil "Edge references missing node: ~A -> ~A"
                           (edge-from edge) (edge-to edge))))
  (push edge (gethash (edge-from edge) adjacency))
  (incf (gethash (edge-to edge) indegree)))

(defun %seed-topological-queue (indegree)
  (let ((queue '()))
    (maphash (lambda (name count)
               (declare (ignore count))
               (when (zerop (gethash name indegree))
                 (push name queue)))
             indegree)
    (sort queue #'string<)))

(defun %drain-topological-queue (queue nodes indegree adjacency)
  (let ((result '())
        (processed (%make-result-table)))
    (loop while queue do
      (let* ((name (pop queue))
             (node (gethash name nodes)))
        (push node result)
        (setf (gethash name processed) t)
        (dolist (edge (gethash name adjacency))
          (decf (gethash (edge-to edge) indegree))
          (when (zerop (gethash (edge-to edge) indegree))
            (push (edge-to edge) queue)))
        (setf queue (sort queue #'string<))))
    (values (nreverse result) processed)))

(defun %unprocessed-cycle-nodes (nodes processed)
  (let ((cycle-nodes '()))
    (maphash (lambda (name node)
               (unless (gethash name processed)
                 (push node cycle-nodes)))
             nodes)
    (sort cycle-nodes #'string< :key #'node-name)))

(defun topological-sort (graph)
  (let* ((nodes (%graph-nodes-table graph))
         (result nil)
         (processed nil))
    (multiple-value-bind (indegree adjacency)
        (%initialize-topological-state nodes)
      (dolist (edge (%graph-edges-list graph))
        (%register-topological-edge graph edge nodes indegree adjacency))
      (multiple-value-setq (result processed)
        (%drain-topological-queue (%seed-topological-queue indegree)
                                  nodes
                                  indegree
                                  adjacency)))
    (unless (= (length result) (hash-table-count nodes))
      (error 'graph-cycle-error
             :graph (%copy-error-value graph)
             :nodes (mapcar #'%copy-node-snapshot
                            (%unprocessed-cycle-nodes nodes processed))
             :detail "Graph contains a cycle or disconnected cycle component."))
    result))
