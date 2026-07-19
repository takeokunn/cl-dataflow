(in-package #:cl-dataflow)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro %resolve-pipeline-stage-designators (graph stages)
    `(mapcar (lambda (stage)
                (find-node ,graph
                          (if (typep stage 'node)
                              (node-name stage)
                              stage)))
              ,stages))

  (defun %plist-option (key value)
    (when value
      (list key value)))

  (defun %invalid-structured-clause-error (expected value detail)
    (error 'invalid-input-error
            :expected expected
            :value value
            :detail detail))

  (defun %unsupported-structured-clause-error (macro-name expected clause)
    (%invalid-structured-clause-error expected
                                        (first clause)
                                        (format nil "Unsupported ~A clause: ~S"
                                                macro-name
                                                (first clause))))

  (defun %parse-pipeline-node-clause (clause graph-var)
    (destructuring-bind (_ name &rest options) clause
      (declare (ignore _))
      (%macro-validate-option-list options
                                    '(:inputs :outputs :handler :metadata)
                                    "DEFINE-PIPELINE node")
      `(add-node ,graph-var (make-node ,name ,@options))))

  (defun %parse-pipeline-edge-clause (clause graph-var)
    (destructuring-bind (_ from to &rest options) clause
      (declare (ignore _))
      (%macro-validate-option-list options
                                    '(:from-port :to-port :metadata)
                                    "DEFINE-PIPELINE edge")
      (%with-plist-bindings (options ((metadata :metadata)))
        (let ((edge-var (gensym "EDGE")))
          `(let ((,edge-var (add-edge ,graph-var ,from ,to
                                  ,@(loop for (key value) on options by #'cddr
                                          unless (eql key :metadata)
                                          append (list key value)))))
              ,(when metadata
                `(setf (edge-metadata ,edge-var) ,metadata))
              ,edge-var)))))

  (defun %parse-pipeline-clause (clause graph-var)
    (unless (and (listp clause) (consp clause))
      (%invalid-structured-clause-error
        '((:node name &rest options)
          (:edge from to &rest options))
        clause
        "DEFINE-PIPELINE clauses must start with :NODE or :EDGE."))
    (case (first clause)
      (:node (%parse-pipeline-node-clause clause graph-var))
      (:edge (%parse-pipeline-edge-clause clause graph-var))
      (t
        (%unsupported-structured-clause-error
        "DEFINE-PIPELINE"
        '(:node :edge)
        clause))))

  (defun %parse-pipeline-definition (options clauses)
    (%macro-validate-option-list options '(:metadata :stages)
                                  "DEFINE-PIPELINE")
    (%with-plist-bindings (options ((metadata :metadata)
                                    (stages :stages)))
      (let ((graph-var (gensym "GRAPH"))
            (metadata-var (and metadata (gensym "METADATA"))))
        ;; METADATA is evaluated once into METADATA-VAR and shared by the graph
        ;; and the pipeline, and the internal GRAPH binding is a gensym so user
        ;; option forms cannot capture a variable named GRAPH.
        `(let* (,@(when metadata-var `((,metadata-var ,metadata)))
                (,graph-var (make-graph
                              ,@(when metadata-var `(:metadata ,metadata-var)))))
            ,@(mapcar (lambda (clause)
                        (%parse-pipeline-clause clause graph-var))
                      clauses)
            (make-pipeline :graph ,graph-var
                          ,@(when metadata-var `(:metadata ,metadata-var))
                          ,@(when stages
                              (list :stages
                                    `(%resolve-pipeline-stage-designators
                                      ,graph-var
                                      ,stages))))))))

  (defun %parse-workflow-transition-clause (clause)
    (destructuring-bind (_ from event to &rest options) clause
      (declare (ignore _))
      (%macro-validate-option-list options
                                    '(:guard :action :metadata)
                                    "DEFINE-WORKFLOW transition")
      `(make-transition ,from ,event ,to
                        ,@options)))

  (defun %parse-workflow-machine-node-clause (clause graph-var machine-var)
    (destructuring-bind (_ &rest options) clause
      (declare (ignore _))
      (%macro-validate-option-list options
                                    '(:name :event-fn :result-fn :metadata)
                                    "DEFINE-WORKFLOW machine node")
      `(add-node ,graph-var (make-state-machine-node ,machine-var ,@options))))

  (defun %parse-workflow-clause (clause graph-var machine-var)
    (unless (and (listp clause) (consp clause))
      (%invalid-structured-clause-error
        '((:transition from event to &rest options)
          (:node name &rest options)
          (:edge from to &rest options)
          (:machine-node &rest options))
        clause
        "DEFINE-WORKFLOW clauses must start with :TRANSITION, :NODE, :EDGE, or :MACHINE-NODE."))
    (case (first clause)
      (:transition `(:transition ,(%parse-workflow-transition-clause clause)))
      (:node `(:pipeline-node ,(%parse-pipeline-node-clause clause graph-var)))
      (:edge `(:pipeline-edge ,(%parse-pipeline-edge-clause clause graph-var)))
      (:machine-node `(:pipeline-node ,(%parse-workflow-machine-node-clause clause graph-var machine-var)))
      (t
        (%unsupported-structured-clause-error
        "DEFINE-WORKFLOW"
        '(:transition :node :edge :machine-node)
        clause))))

  (defun %workflow-clause-forms (parsed-clauses)
    (values (loop for (kind form) in parsed-clauses
                  when (eq kind :transition)
                  collect form)
            (loop for (kind form) in parsed-clauses
                  when (eq kind :pipeline-node)
                  collect form)
            (loop for (kind form) in parsed-clauses
                  when (eq kind :pipeline-edge)
                  collect form)))

  (defun %parse-workflow-definition (options clauses)
    (%macro-validate-option-list options
                                  '(:state :initial-state :history
                                    :machine-metadata :pipeline-metadata :stages)
                                  "DEFINE-WORKFLOW")
    (%with-plist-bindings (options ((state :state)
                                    (initial-state :initial-state)
                                    (history :history)
                                    (machine-metadata :machine-metadata)
                                    (pipeline-metadata :pipeline-metadata)
                                    (stages :stages)))
      (let* ((graph-var (gensym "GRAPH"))
             (machine-var (gensym "MACHINE"))
             (pipeline-metadata-var (and pipeline-metadata (gensym "PIPELINE-METADATA"))))
        (multiple-value-bind (transition-forms pipeline-node-forms pipeline-edge-forms)
            (%workflow-clause-forms
             (mapcar (lambda (clause)
                       (%parse-workflow-clause clause graph-var machine-var))
                     clauses))
          ;; MACHINE and GRAPH are gensyms so user guard/action/event-fn forms
          ;; cannot capture them, and PIPELINE-METADATA is evaluated once and
          ;; shared by the graph and the pipeline.
          `(let* ((,machine-var (make-state-machine
                            ,@(%plist-option :state state)
                            ,@(%plist-option :initial-state initial-state)
                            ,@(%plist-option :history history)
                            ,@(%plist-option :metadata machine-metadata)
                            :transitions (list ,@transition-forms)))
                  ,@(when pipeline-metadata-var
                      `((,pipeline-metadata-var ,pipeline-metadata)))
                  (,graph-var (make-graph
                          ,@(when pipeline-metadata-var
                              `(:metadata ,pipeline-metadata-var)))))
              ,@pipeline-node-forms
              ,@pipeline-edge-forms
              (values
              (make-pipeline :graph ,graph-var
                              ,@(when pipeline-metadata-var
                                  `(:metadata ,pipeline-metadata-var))
                              ,@(when stages
                                  (list :stages
                                        `(%resolve-pipeline-stage-designators
                                          ,graph-var
                                          ,stages))))
              ,machine-var))))))

  )

(defmacro define-pipeline ((&rest options) &body clauses)
  (%parse-pipeline-definition options clauses))

(defmacro define-workflow ((&rest options) &body clauses)
  (%parse-workflow-definition options clauses))
