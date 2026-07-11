(in-package #:cl-dataflow.test)

(deftest graph-print-object-renders-raw-graph-summary
  (let* ((graph (make-graph))
         (source (make-node "source"))
         (sink (make-node "sink")))
    (add-node graph source)
    (add-node graph sink)
    (add-edge graph source sink)
    (is (search "2 nodes 1 edges"
                (with-output-to-string (stream)
                  (prin1 graph stream))))
    (remhash "sink" (slot-value graph 'cl-dataflow::nodes))
    (is (search "1 nodes 1 edges"
                (with-output-to-string (stream)
                  (prin1 graph stream))))))

(deftest protocol-print-object-renders-public-identifiers
  (flet ((render (object)
           (with-output-to-string (stream)
             (print-object object stream))))
    (let* ((node (make-node "source" :outputs '("out")))
           (edge (make-edge "source" "sink" :from-port "out" :to-port "input"))
           (context (make-context :events (list (make-event "boot")
                                                (make-event "tick"))
                                  :effects (list (make-effect "audit")))))
      (is (search "NODE" (render node)))
      (is (search "source" (render node)))
      (is (search "EDGE" (render edge)))
      (is (search "source:out -> sink:input"
                  (render edge)))
      (is (search "CONTEXT" (render context)))
      (is (search "events=2 effects=1"
                  (render context))))))

(deftest constructors-normalize-and-copy-input-data
  (let* ((metadata (list (list :labels "alpha")))
         (node (make-node 'source
                          :inputs '(input)
                          :outputs '(output)
                          :metadata metadata))
         (values (make-test-table "count" (list 1 2)))
         (events (list (make-event "boot" :payload 1)))
         (effects (list (make-effect "audit" :payload 2)))
         (trace (list '(:event "boot")))
         (handlers (make-test-effect-handlers
                    "log" (lambda (effect context)
                            (declare (ignore effect context))
                            :ok)))
         (context (make-context :values values
                                :events events
                                :effects effects
                                :trace trace
                                :effect-handlers handlers
                                :metadata metadata)))
    (setf (cadar metadata) "beta")
    (setf (cadr (gethash "count" values)) 3)
    (setf (car events) (make-event "mutated"))
    (setf (car effects) (make-effect "mutated"))
    (setf (car trace) '(:event "mutated"))
    (setf (gethash "log" handlers) :mutated)
    (is (equal (node-name node) "SOURCE"))
    (is (equal (node-inputs node) '("INPUT")))
    (is (equal (node-outputs node) '("OUTPUT")))
    (is (equal (node-metadata node) '((:labels "alpha"))))
    (is (equal (gethash "count" (context-values context)) '(1 2)))
    (is (equal (event-type (first (context-events context))) "boot"))
    (is (equal (effect-type (first (context-effects context))) "audit"))
    (is (equal (first (context-trace context)) '(:event "boot")))
    (is (functionp (gethash "log" (context-effect-handlers context))))
    (is (equal (context-metadata context) '((:labels "alpha"))))))

(deftest public-predicate-helpers-recognize-core-types
  (let* ((node (make-node "source"))
         (edge (make-edge "source" "sink"))
         (graph (make-graph))
         (context (make-context))
         (event (make-event "boot"))
         (effect (make-effect "audit"))
         (transition (make-transition "idle" "start" "running"))
         (machine (make-state-machine :state "idle"))
         (pipeline (make-pipeline :stages (list node))))
    (is (node-p node))
    (is (edge-p edge))
    (is (graph-p graph))
    (is (context-p context))
    (is (event-p event))
    (is (effect-p effect))
    (is (state-transition-p transition))
    (is (state-machine-p machine))
    (is (pipeline-p pipeline))
    (is (functionp (node-handler node)))))
