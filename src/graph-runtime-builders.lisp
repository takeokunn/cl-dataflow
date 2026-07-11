(in-package #:cl-dataflow)

(defun %remap-pipeline-stages (graph stages)
  (mapcar (lambda (stage)
            (or (find-node graph (node-name stage))
                (error 'node-not-found-error
                       :graph (%copy-error-value graph)
                       :designator (%copy-error-value stage)
                       :detail (format nil "Pipeline stage is not present in the graph: ~A"
                                       (node-name stage)))))
          stages))

(defun (setf pipeline-graph) (graph-value pipeline)
  (let ((copied-graph (copy-graph graph-value))
        (stages (%pipeline-stages-list pipeline)))
    (validate-graph copied-graph)
    (setf (slot-value pipeline 'graph) copied-graph
          (slot-value pipeline 'stages)
          (if stages
              (%remap-pipeline-stages copied-graph stages)
              '()))))

(defun pipeline-graph (pipeline)
  (slot-value pipeline 'graph))

(defun (setf pipeline-metadata) (metadata pipeline)
  (setf (slot-value pipeline 'metadata)
        (%normalize-metadata metadata)))

(defun pipeline-metadata (pipeline)
  (copy-tree (slot-value pipeline 'metadata)))

(defun %normalize-stage-spec (stage)
  (typecase stage
    (node stage)
    (t (%with-plist-bindings (stage ((name :name)
                                     (inputs :inputs)
                                     (outputs :outputs)
                                     (handler :handler)
                                     (metadata :metadata)))
         (make-node name
                    :inputs inputs
                    :outputs outputs
                    :handler handler
                    :metadata metadata)))))

(defun %build-sequential-graph (stages)
  (let ((graph (make-graph))
        (nodes (mapcar #'%normalize-stage-spec stages)))
    (dolist (node nodes)
      (add-node graph node))
    (do ((remaining nodes (rest remaining)))
        ((null (rest remaining)))
      (let ((previous (first remaining))
            (current (second remaining)))
        (add-edge graph previous current
                  :from-port (first (%node-outputs-list previous))
                  :to-port (first (%node-inputs-list current)))))
    (values graph nodes)))
