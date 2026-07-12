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

  (defun %parse-pipeline-node-clause (clause)
    (destructuring-bind (_ name &rest options) clause
      (declare (ignore _))
      (%macro-validate-option-list options
                                   '(:inputs :outputs :handler :metadata)
                                   "DEFINE-PIPELINE node")
      `(add-node graph (make-node ,name ,@options))))

  (defun %parse-pipeline-edge-clause (clause)
    (destructuring-bind (_ from to &rest options) clause
      (declare (ignore _))
      (%macro-validate-option-list options
                                   '(:from-port :to-port :metadata)
                                   "DEFINE-PIPELINE edge")
      (%with-plist-bindings (options ((metadata :metadata)))
        `(let ((edge (add-edge graph ,from ,to
                               ,@(loop for (key value) on options by #'cddr
                                       unless (eql key :metadata)
                                       append (list key value)))))
           ,(when metadata
              `(setf (edge-metadata edge) ,metadata))
           edge))))

  (defun %parse-pipeline-clause (clause)
    (unless (and (listp clause) (consp clause))
      (%invalid-structured-clause-error
       '((:node name &rest options)
         (:edge from to &rest options))
       clause
       "DEFINE-PIPELINE clauses must start with :NODE or :EDGE."))
    (case (first clause)
      (:node (%parse-pipeline-node-clause clause))
      (:edge (%parse-pipeline-edge-clause clause))
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
      `(let ((graph (make-graph
                     ,@(%plist-option :metadata metadata))))
         ,@(mapcar #'%parse-pipeline-clause clauses)
         (make-pipeline :graph graph
                        ,@(%plist-option :metadata metadata)
                        ,@(when stages
                            (list :stages
                                  `(%resolve-pipeline-stage-designators
                                    graph
                                    ,stages)))))))

  (defun %parse-workflow-transition-clause (clause)
    (destructuring-bind (_ from event to &rest options) clause
      (declare (ignore _))
      (%macro-validate-option-list options
                                   '(:guard :action :metadata)
                                   "DEFINE-WORKFLOW transition")
      `(make-transition ,from ,event ,to
                        ,@options)))

  (defun %parse-workflow-machine-node-clause (clause)
    (destructuring-bind (_ &rest options) clause
      (declare (ignore _))
      (%macro-validate-option-list options
                                   '(:name :event-fn :result-fn :metadata)
                                   "DEFINE-WORKFLOW machine node")
      `(add-node graph (make-state-machine-node machine ,@options))))

  (defun %parse-workflow-clause (clause)
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
      (:node `(:pipeline-node ,(%parse-pipeline-node-clause clause)))
      (:edge `(:pipeline-edge ,(%parse-pipeline-edge-clause clause)))
      (:machine-node `(:pipeline-node ,(%parse-workflow-machine-node-clause clause)))
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
      (multiple-value-bind (transition-forms pipeline-node-forms pipeline-edge-forms)
          (%workflow-clause-forms (mapcar #'%parse-workflow-clause clauses))
        `(let* ((machine (make-state-machine
                          ,@(%plist-option :state state)
                          ,@(%plist-option :initial-state initial-state)
                          ,@(%plist-option :history history)
                          ,@(%plist-option :metadata machine-metadata)
                          :transitions (list ,@transition-forms)))
                (graph (make-graph
                        ,@(%plist-option :metadata pipeline-metadata))))
           ,@pipeline-node-forms
           ,@pipeline-edge-forms
           (values
            (make-pipeline :graph graph
                           ,@(%plist-option :metadata pipeline-metadata)
                           ,@(when stages
                               (list :stages
                                     `(%resolve-pipeline-stage-designators
                                       graph
                                       ,stages))))
            machine))))

  (defmacro define-pipeline ((&rest options) &body clauses)
    (%parse-pipeline-definition options clauses))

  (defmacro define-workflow ((&rest options) &body clauses)
    (%parse-workflow-definition options clauses))
)
)
