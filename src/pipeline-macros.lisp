(in-package #:cl-dataflow)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro %resolve-pipeline-stage-designators (graph stages)
    `(mapcar (lambda (stage)
               (find-node ,graph
                          (if (typep stage 'node)
                              (node-name stage)
                              stage)))
             ,stages))

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
      (error 'invalid-input-error
             :expected '((:node name &rest options)
                         (:edge from to &rest options))
             :value clause
             :detail "DEFINE-PIPELINE clauses must start with :NODE or :EDGE."))
    (case (first clause)
      (:node (%parse-pipeline-node-clause clause))
      (:edge (%parse-pipeline-edge-clause clause))
      (t
       (error 'invalid-input-error
              :expected '(:node :edge)
              :value (first clause)
              :detail (format nil "Unsupported DEFINE-PIPELINE clause: ~S"
                              (first clause))))))

  (defun %parse-pipeline-definition (options clauses)
    (%macro-validate-option-list options '(:metadata :stages)
                                 "DEFINE-PIPELINE")
    (%with-plist-bindings (options ((metadata :metadata)
                                    (stages :stages)))
      `(let ((graph (make-graph
                     ,@(when metadata
                         (list :metadata metadata)))))
         ,@(mapcar #'%parse-pipeline-clause clauses)
         (make-pipeline :graph graph
                        ,@(when stages
                            (list :stages
                                  `(%resolve-pipeline-stage-designators
                                    graph
                                    ,stages))))))))

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
      (error 'invalid-input-error
             :expected '((:transition from event to &rest options)
                         (:node name &rest options)
                         (:edge from to &rest options)
                         (:machine-node &rest options))
             :value clause
             :detail "DEFINE-WORKFLOW clauses must start with :TRANSITION, :NODE, :EDGE, or :MACHINE-NODE."))
    (case (first clause)
      (:transition `(:transition ,(%parse-workflow-transition-clause clause)))
      (:node `(:pipeline-node ,(%parse-pipeline-node-clause clause)))
      (:edge `(:pipeline-edge ,(%parse-pipeline-edge-clause clause)))
      (:machine-node `(:pipeline-node ,(%parse-workflow-machine-node-clause clause)))
      (t
       (error 'invalid-input-error
              :expected '(:transition :node :edge :machine-node)
              :value (first clause)
              :detail (format nil "Unsupported DEFINE-WORKFLOW clause: ~S"
                              (first clause))))))

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
      (let* ((parsed-clauses (mapcar #'%parse-workflow-clause clauses))
             (transition-forms (loop for (kind form) in parsed-clauses
                                     when (eq kind :transition)
                                     collect form))
             (pipeline-node-forms (loop for (kind form) in parsed-clauses
                                        when (eq kind :pipeline-node)
                                        collect form))
             (pipeline-edge-forms (loop for (kind form) in parsed-clauses
                                        when (eq kind :pipeline-edge)
                                        collect form)))
        `(let* ((machine (make-state-machine
                          ,@(when state
                              (list :state state))
                          ,@(when initial-state
                              (list :initial-state initial-state))
                          ,@(when history
                              (list :history history))
                          ,@(when machine-metadata
                              (list :metadata machine-metadata))
                          :transitions (list ,@transition-forms)))
                (graph (make-graph
                        ,@(when pipeline-metadata
                            (list :metadata pipeline-metadata)))))
           ,@pipeline-node-forms
           ,@pipeline-edge-forms
           (values
            (make-pipeline :graph graph
                           ,@(when pipeline-metadata
                               (list :metadata pipeline-metadata))
                           ,@(when stages
                               (list :stages
                                     `(%resolve-pipeline-stage-designators
                                       graph
                                       ,stages))))
            machine)))))

(defmacro define-pipeline ((&rest options) &body clauses)
  (%parse-pipeline-definition options clauses))

(defmacro define-workflow ((&rest options) &body clauses)
  (%parse-workflow-definition options clauses))
