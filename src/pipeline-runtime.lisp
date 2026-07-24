(in-package #:cl-dataflow)

(progn
  (defun %build-pipeline-graph (graph stages)
    (cond
      (graph
        (let ((copied-graph (copy-graph graph)))
          (values
            copied-graph
            (%remap-pipeline-stages copied-graph (or stages (topological-sort graph))))))
      (stages (%build-sequential-graph stages))
      (t (values (make-graph) '()))))
  (defun %make-pipeline-edge-signature (edge)
    (make-instance
      'pipeline-edge-signature
      :edge
      edge
      :from
      (%copy-structured-value (edge-from edge))
      :from-port
      (%copy-structured-value (edge-from-port edge))
      :to
      (%copy-structured-value (edge-to edge))
      :to-port
      (%copy-structured-value (edge-to-port edge))))
  (defun %make-pipeline-execution-plan (graph stages)
    (let ((incoming-index (%incoming-edges-index graph)))
      (make-instance
        (quote pipeline-execution-plan)
        :graph
        graph
        :stages
        stages
        :incoming-index
        incoming-index
        :input-binding-plans
        (loop for node in stages
              for incoming-edges = (gethash (node-name node) incoming-index)
              collect (cons
            (not (endp incoming-edges))
            (%node-input-binding-plan node incoming-edges)))
        :sinks
        (%sink-nodes-in-order graph stages)
        :edge-signatures
        (loop for edge in (%graph-edges-list graph)
              collect (%make-pipeline-edge-signature edge)))))
  (defun %pipeline-edge-signature-current-p (edge signature)
    (and
      (eq edge (%pipeline-edge-signature-edge signature))
      (equal (edge-from edge) (%pipeline-edge-signature-from signature))
      (equal (edge-from-port edge) (%pipeline-edge-signature-from-port signature))
      (equal (edge-to edge) (%pipeline-edge-signature-to signature))
      (equal (edge-to-port edge) (%pipeline-edge-signature-to-port signature))))
  (defun %pipeline-stage-list-current-p (graph stages)
    (loop for stage in stages
          always (eq stage (find-node graph (node-name stage)))))
  (defun %pipeline-edge-signatures-current-p (edges signatures)
    (do ((remaining-edges edges (cdr remaining-edges))
          (remaining-signatures signatures (cdr remaining-signatures)))
      ((or (endp remaining-edges) (endp remaining-signatures))
        (and (endp remaining-edges) (endp remaining-signatures)))
      (unless (%pipeline-edge-signature-current-p
          (car remaining-edges)
          (car remaining-signatures))
        (return nil))))
  (defun %pipeline-execution-plan-current-p (pipeline plan)
    (and
      plan
      (let ((graph (pipeline-graph pipeline)))
        (and
          (eq graph (%pipeline-execution-plan-graph plan))
          (%pipeline-stage-list-current-p graph (%pipeline-execution-plan-stages plan))
          (%pipeline-edge-signatures-current-p
            (%graph-edges-list graph)
            (%pipeline-execution-plan-edge-signatures plan))))))
  (defun %rebuild-pipeline-execution-plan (pipeline)
    (let* ((graph (pipeline-graph pipeline))
            (stages (%remap-pipeline-stages graph (%pipeline-stages-list pipeline)))
            (plan (%make-pipeline-execution-plan graph stages)))
      (setf (slot-value pipeline 'stages) stages
            (%pipeline-execution-plan pipeline) plan)
      plan))
  (defun %ensure-pipeline-execution-plan (pipeline)
    (let ((plan (%pipeline-execution-plan pipeline)))
      (if (%pipeline-execution-plan-current-p pipeline plan) plan
        (%rebuild-pipeline-execution-plan pipeline)))))

(defun make-pipeline (&key graph stages metadata)
  (multiple-value-bind (resolved-graph resolved-stages) (%build-pipeline-graph graph stages)
    (validate-graph resolved-graph)
    (let ((internal-stages (copy-list resolved-stages)))
      (make-instance
        'pipeline
        :graph
        resolved-graph
        :stages
        internal-stages
        :execution-plan
        (%make-pipeline-execution-plan resolved-graph internal-stages)
        :metadata
        (%normalize-metadata metadata)))))

(defun copy-pipeline (pipeline)
  (make-pipeline
    :graph
    (pipeline-graph pipeline)
    :stages
    (pipeline-stages pipeline)
    :metadata
    (pipeline-metadata pipeline)))

(defmethod (setf pipeline-stages) (stages (pipeline pipeline))
  (let ((graph (pipeline-graph pipeline)))
    (validate-graph graph)
    (let ((remapped-stages
          (if stages (%remap-pipeline-stages graph stages)
            '())))
      (setf (slot-value pipeline 'stages) remapped-stages
            (%pipeline-execution-plan pipeline) nil)
      remapped-stages)))

(defmethod pipeline-stages ((pipeline pipeline))
  (copy-list (%pipeline-stages-list pipeline)))

(defun %copy-node-output-bindings (bindings)
  (mapcar
    (lambda (binding)
      (cons (car binding) (%copy-structured-value (cdr binding))))
    bindings))

(defun %make-node-trace-record (node node-input bindings)
  (list
    :node
    (node-name node)
    :input
    node-input
    :output
    (%copy-node-output-bindings bindings)))

(defun %record-node-run (context node node-input bindings)
  (dolist (binding bindings)
    (%store-value context (node-name node) (car binding) (cdr binding)))
  (push
    (%make-node-trace-record node node-input bindings)
    (%context-trace-list context)))

(defun %run-node/cps (context node input input-binding-plan continuation)
  (let* ((has-incoming-p (car input-binding-plan))
          (bindings (cdr input-binding-plan))
          (node-input
        (cond
          (bindings
            (%collapse-single-binding-list (%resolve-input-binding-plan context bindings)))
          (has-incoming-p nil)
          (t (%node-input-binding node input))))
          (output (funcall (node-handler node) node-input context))
          (output-bindings (%node-output-bindings node output)))
    (%record-node-run context node node-input output-bindings)
    (funcall continuation output)))

(defun %finalize-pipeline-run (context sink-nodes)
  (setf (context-result context) (%collect-cached-sink-results context sink-nodes))
  (context-result context))

(defun %ensure-pipeline-context (context)
  (or context (make-context)))

(defun %run-pipeline-stages/cps (context order sink-nodes input input-binding-plans continuation)
  (labels ((advance-stages (remaining remaining-binding-plans)
              (if (endp remaining) (funcall continuation (%finalize-pipeline-run context sink-nodes))
          (%run-node/cps
            context
            (first remaining)
            input
            (first remaining-binding-plans)
            (lambda (output)
              (declare (ignore output))
              (advance-stages (rest remaining) (rest remaining-binding-plans)))))))
    (advance-stages order input-binding-plans)))

(defun run-pipeline (pipeline &key input context)
  (let* ((plan (%ensure-pipeline-execution-plan pipeline))
          (ctx (%ensure-pipeline-context context))
          (order (%pipeline-execution-plan-stages plan))
          (sink-nodes (%pipeline-execution-plan-sinks plan))
          (input-binding-plans (%pipeline-execution-plan-input-binding-plans plan)))
    (%run-pipeline-stages/cps
      ctx
      order
      sink-nodes
      input
      input-binding-plans
      (lambda (result)
        result))))

(defun run-pipeline-with-context (pipeline &key input context)
  (let ((ctx (%ensure-pipeline-context context)))
    (values (run-pipeline pipeline :input input :context ctx) ctx)))
