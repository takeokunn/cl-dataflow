(in-package #:cl-dataflow)

(defun %build-pipeline-graph (graph stages)
  (cond
    (graph
     (let ((copied-graph (copy-graph graph)))
       (values copied-graph
               (%remap-pipeline-stages copied-graph
                                       (or stages (topological-sort graph))))))
    (stages
     (%build-sequential-graph stages))
    (t
     (values (make-graph) '()))))

(defun make-pipeline (&key graph stages metadata)
  (multiple-value-bind (resolved-graph resolved-stages)
      (%build-pipeline-graph graph stages)
    (validate-graph resolved-graph)
    (make-instance 'pipeline
                   :graph resolved-graph
                   :stages (copy-list resolved-stages)
                   :metadata (%normalize-metadata metadata))))

(defun copy-pipeline (pipeline)
  (make-pipeline :graph (pipeline-graph pipeline)
                 :stages (pipeline-stages pipeline)
                 :metadata (pipeline-metadata pipeline)))

(defmethod (setf pipeline-stages) (stages (pipeline pipeline))
  (let ((graph (pipeline-graph pipeline)))
    (validate-graph graph)
    (setf (slot-value pipeline 'stages)
          (if stages
              (%remap-pipeline-stages graph stages)
              '()))))

(defmethod pipeline-stages ((pipeline pipeline))
  (copy-list (%pipeline-stages-list pipeline)))

(defun %copy-node-output-bindings (bindings)
  (mapcar (lambda (binding)
            (cons (car binding)
                  (%copy-structured-value (cdr binding))))
          bindings))

(defun %make-node-trace-record (node node-input bindings)
  (list :node (node-name node)
        :input node-input
        :output (%copy-node-output-bindings bindings)))

(defun %record-node-run (context node node-input bindings)
  (dolist (binding bindings)
    (%store-value context (node-name node) (car binding) (cdr binding)))
  (push (%make-node-trace-record node node-input bindings)
        (%context-trace-list context)))

(defun %run-node/cps (context graph node input incoming-index continuation)
  (let* ((node-input (%collect-node-inputs context graph node input incoming-index))
         (output (funcall (node-handler node) node-input context))
         (bindings (%node-output-bindings node output)))
    (%record-node-run context node node-input bindings)
    (funcall continuation output)))

(defun %finalize-pipeline-run (graph context order)
  (setf (context-result context) (%collect-sink-results graph context order))
  (context-result context))

(defun %ensure-pipeline-context (context)
  (or context (make-context)))

(defun %run-pipeline-stages/cps (context graph order input continuation)
  ;; The incoming-edge index is built once per pipeline run (O(E)) instead of
  ;; once per node (O(V*E) total for a run through V stages).
  (let ((incoming-index (%incoming-edges-index graph)))
    (labels ((advance-stages (remaining)
               (if (endp remaining)
                   (funcall continuation (%finalize-pipeline-run graph context order))
                   (%run-node/cps context
                                  graph
                                  (first remaining)
                                  input
                                  incoming-index
                                  (lambda (output)
                                    (declare (ignore output))
                                    (advance-stages (rest remaining)))))))
      (advance-stages order))))

(defun run-pipeline (pipeline &key input context)
  (let* ((graph (pipeline-graph pipeline))
         (ctx (%ensure-pipeline-context context))
         (order (%remap-pipeline-stages graph (pipeline-stages pipeline))))
    (%run-pipeline-stages/cps ctx graph order input
                              (lambda (result)
                                result))))

(defun run-pipeline-with-context (pipeline &key input context)
  (let ((ctx (%ensure-pipeline-context context)))
    (values (run-pipeline pipeline :input input :context ctx)
            ctx)))
