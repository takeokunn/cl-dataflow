;;; Run with:
;;;   sbcl --script examples/event-workflow.lisp

(require :asdf)

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil :type nil :defaults *load-truename*)))

(load-cl-dataflow)

(let* ((machine (cl-dataflow:make-state-machine
                 :state "idle"
                 :transitions (list
                               (cl-dataflow:make-transition "idle" "order-created" "order-created")
                               (cl-dataflow:make-transition "order-created" "reserve-inventory" "inventory-reserved")
                               (cl-dataflow:make-transition "inventory-reserved" "payment-requested" "payment-requested")
                               (cl-dataflow:make-transition "payment-requested" "order-confirmed" "order-confirmed"))))
       (stage (lambda (name event)
                (cl-dataflow:make-node name
                                       :handler (lambda (input context)
                                                  (cl-dataflow:emit-event context event :payload input)
                                                  (cl-dataflow:step-state-machine machine event
                                                                                  :context context)
                                                  input))))
       (pipeline (cl-dataflow:make-pipeline
                  :stages (list (funcall stage "create-order" "order-created")
                                (funcall stage "reserve-inventory" "reserve-inventory")
                                (funcall stage "request-payment" "payment-requested")
                                (funcall stage "confirm-order" "order-confirmed"))))
       (context (cl-dataflow:run-pipeline-with-test-context pipeline
                                                            :input '(:order-id "A-100")
                                                            :state (cl-dataflow:state-machine-state machine))))
  (format t "~&Workflow state: ~A~%" (cl-dataflow:context-state context))
  (format t "~&Workflow events: ~S~%"
          (mapcar #'cl-dataflow:event-type (nreverse (cl-dataflow:context-events context)))))
