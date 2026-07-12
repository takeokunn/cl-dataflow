(in-package #:cl-dataflow)

(defun %incoming-edges (graph node-name)
  (remove-if-not (lambda (edge)
                    (equal (edge-to edge) node-name))
                  (%graph-edges-list graph)))

(defun %source-node-p (graph node &optional (rulebase (%graph-rulebase graph)))
  (null (%graph-predecessor-names graph rulebase (node-name node))))

(defun %sink-node-p (graph node &optional (rulebase (%graph-rulebase graph)))
  (null (%graph-successor-names graph rulebase (node-name node))))

(progn
  (defun %boundary-nodes (graph boundary-predicate)
    (let ((rulebase (%graph-rulebase graph)))
      (mapcar #'%copy-node-snapshot
              (remove-if-not (lambda (node)
                                (funcall boundary-predicate graph node rulebase))
                              (topological-sort graph)))))

  (defun graph-source-nodes (graph)
    (%boundary-nodes graph #'%source-node-p)))

(defun graph-sink-nodes (graph)
  (%boundary-nodes graph #'%sink-node-p))

(defun %initialize-topological-state (graph nodes rulebase)
  (let ((indegree (%make-result-table)))
    (maphash (lambda (name node)
                (declare (ignore node))
                (setf (gethash name indegree)
                      (length (%graph-predecessor-names graph rulebase name))))
              nodes)
    indegree))

(defun %seed-topological-queue (indegree)
  (let ((queue '()))
    (maphash (lambda (name count)
                (declare (ignore count))
                (when (zerop (gethash name indegree))
                  (push name queue)))
              indegree)
    (sort queue #'string<)))

(defun %drain-topological-queue (graph queue nodes indegree rulebase)
  (let ((result '())
        (processed (%make-result-table)))
    (loop while queue do
      (let* ((name (pop queue))
              (node (gethash name nodes)))
        (push node result)
        (setf (gethash name processed) t)
        (dolist (successor (%graph-successor-names graph rulebase name))
          (decf (gethash successor indegree))
          (when (zerop (gethash successor indegree))
            (push successor queue)))
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
          (rulebase (%graph-rulebase graph))
          (result nil)
          (processed nil))
    (let ((indegree (%initialize-topological-state graph nodes rulebase)))
      (multiple-value-setq (result processed)
        (%drain-topological-queue graph
                                  (%seed-topological-queue indegree)
                                  nodes
                                  indegree
                                  rulebase)))
    (unless (= (length result) (hash-table-count nodes))
      (error 'graph-cycle-error
              :graph graph
              :nodes (mapcar #'%copy-node-snapshot
                            (%unprocessed-cycle-nodes nodes processed))
              :detail "Graph contains a cycle or disconnected cycle component."))
    result))
