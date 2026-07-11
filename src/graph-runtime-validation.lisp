(in-package #:cl-dataflow)

(defun %ensure-node (designator)
  (typecase designator
    (node designator)
    (t (error 'invalid-input-error
              :expected 'node
              :value (%copy-error-value designator)
              :detail (%expected-object-detail "NODE" designator)))))

(defun %validate-node-port-lists (graph node)
  (labels ((validate (kind ports)
             (let ((seen (make-hash-table :test #'equal)))
               (dolist (port ports)
                 (when (gethash port seen)
                   (error 'graph-error
                          :graph (%copy-error-value graph)
                          :detail (format nil "Node ~A has duplicate ~A port ~A"
                                          (node-name node)
                                          kind
                                          port)))
                 (setf (gethash port seen) t)))))
    (validate "input" (%normalize-port-list (%read-slot node 'inputs)))
    (validate "output" (%normalize-port-list (%read-slot node 'outputs)))))

(defun %ensure-graph-node (graph designator)
  (let* ((name (%node-designator-name designator))
         (node (gethash name (%graph-nodes-table graph))))
    (or node
        (error 'node-not-found-error
               :graph (%copy-error-value graph)
               :designator (%copy-error-value designator)
               :detail (format nil "Node not found: ~A" name)))))

(defun %validate-node-ports (graph edge)
  (let ((from-node (find-node graph (edge-from edge)))
        (to-node (find-node graph (edge-to edge))))
    (unless from-node
      (error 'node-not-found-error
             :graph (%copy-error-value graph)
             :designator (%copy-error-value edge)
             :detail (format nil "Missing source node: ~A" (edge-from edge))))
    (unless to-node
      (error 'node-not-found-error
             :graph (%copy-error-value graph)
             :designator (%copy-error-value edge)
             :detail (format nil "Missing destination node: ~A" (edge-to edge))))
    (%validate-node-port-lists graph from-node)
    (%validate-node-port-lists graph to-node)
    (unless (member (edge-from-port edge) (%node-outputs-list from-node) :test #'equal)
      (error 'graph-error
             :graph (%copy-error-value graph)
             :detail (format nil "Edge ~A -> ~A uses unknown output port ~A"
                             (edge-from edge) (edge-to edge) (edge-from-port edge))))
    (unless (member (edge-to-port edge) (%node-inputs-list to-node) :test #'equal)
      (error 'graph-error
             :graph (%copy-error-value graph)
             :detail (format nil "Edge ~A -> ~A uses unknown input port ~A"
                             (edge-from edge) (edge-to edge) (edge-to-port edge))))))

(defun validate-graph (graph)
  (maphash (lambda (name node)
             (declare (ignore name))
             (%validate-node-port-lists graph node))
           (%graph-nodes-table graph))
  (dolist (edge (%graph-edges-list graph))
    (%validate-node-ports graph edge))
  (topological-sort graph)
  t)

(defun add-node (graph node)
  (let ((normalized-node (%ensure-node node)))
    (%validate-node-port-lists graph normalized-node)
    (when (find-node graph (node-name normalized-node))
      (error 'graph-error
             :graph (%copy-error-value graph)
             :detail (format nil "Node already exists: ~A"
                             (node-name normalized-node))))
    (let ((name (node-name normalized-node))
          (nodes (%graph-nodes-table graph)))
      (setf (gethash name nodes) normalized-node))
    normalized-node))

(defun find-node (graph name)
  (gethash (%normalize-name name) (%graph-nodes-table graph)))

(defun add-edge (graph from to &key from-port to-port)
  (let* ((from-node (%ensure-graph-node graph from))
         (to-node (%ensure-graph-node graph to))
         (edge (make-edge from-node to-node
                          :from-port from-port
                          :to-port to-port)))
    (%validate-node-ports graph edge)
    (when (find-if (lambda (existing)
                     (and (equal (edge-from existing) (edge-from edge))
                          (equal (edge-from-port existing) (edge-from-port edge))
                          (equal (edge-to existing) (edge-to edge))
                          (equal (edge-to-port existing) (edge-to-port edge))))
                   (%graph-edges-list graph))
      (error 'graph-error
             :graph (%copy-error-value graph)
             :detail (format nil "Edge already exists: ~A:~A -> ~A:~A"
                             (edge-from edge)
                             (edge-from-port edge)
                             (edge-to edge)
                             (edge-to-port edge))))
    (setf (slot-value graph 'edges)
          (cons edge (%graph-edges-list graph)))
    edge))
