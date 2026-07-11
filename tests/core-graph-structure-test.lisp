(in-package #:cl-dataflow.test)

(deftest node-construction-and-graph-sort
  (let* ((graph (make-graph))
         (source (make-node "source"))
         (middle (make-node "middle"))
         (sink (make-node "sink")))
    (add-node graph source)
    (add-node graph middle)
    (add-node graph sink)
    (add-edge graph source middle)
    (add-edge graph middle sink)
    (assert-node-order (topological-sort graph)
                       '("source" "middle" "sink"))
    (is (validate-graph graph))))

(deftest topological-sort-is-stable-for-independent-sources
  (let* ((graph (make-graph))
         (beta (make-node "beta"))
         (alpha (make-node "alpha"))
         (sink (make-node "sink")))
    (add-node graph beta)
    (add-node graph alpha)
    (add-node graph sink)
    (add-edge graph beta sink)
    (add-edge graph alpha sink)
    (assert-node-order (topological-sort graph)
                       '("alpha" "beta" "sink"))
    (assert-node-order (graph-source-nodes graph)
                       '("alpha" "beta"))
    (assert-node-order (graph-sink-nodes graph)
                       '("sink"))))

(deftest graph-sink-nodes-are-stable-for-independent-sinks
  (let* ((graph (make-graph))
         (source (make-node "source"))
         (beta (make-node "beta"))
         (alpha (make-node "alpha")))
    (add-node graph source)
    (add-node graph beta)
    (add-node graph alpha)
    (add-edge graph source beta)
    (add-edge graph source alpha)
    (assert-node-order (graph-sink-nodes graph)
                       '("alpha" "beta"))
    (assert-node-order (topological-sort graph)
                       '("source" "alpha" "beta"))))

(deftest graph-source-and-sink-nodes-return-copy-snapshots
  (let* ((graph (make-graph))
         (source (make-node "source" :metadata '((:kind :source))))
         (sink (make-node "sink" :metadata '((:kind :sink)))))
    (add-node graph source)
    (add-node graph sink)
    (add-edge graph source sink)
    (let ((sources (graph-source-nodes graph))
          (sinks (graph-sink-nodes graph)))
      (is (not (eq (first sources) (find-node graph "source"))))
      (is (not (eq (first sinks) (find-node graph "sink"))))
      (setf (node-metadata (first sources)) '((:kind :mutated-source))
            (node-metadata (first sinks)) '((:kind :mutated-sink)))
      (is (equal (node-metadata (find-node graph "source"))
                 '((:kind :source))))
      (is (equal (node-metadata (find-node graph "sink"))
                 '((:kind :sink)))))))

(deftest graph-cycle-detection
  (let* ((graph (make-graph))
         (a (make-node "a"))
         (b (make-node "b")))
    (add-node graph a)
    (add-node graph b)
    (add-edge graph a b)
    (add-edge graph b a)
    (signals graph-cycle-error
      (topological-sort graph))))

(deftest graph-cycle-error-exposes-cyclic-nodes
  (let* ((graph (make-graph))
         (a (make-node "a"))
         (b (make-node "b")))
    (add-node graph a)
    (add-node graph b)
    (add-edge graph a b)
    (add-edge graph b a)
    (let ((captured
            (capture-condition (condition graph-cycle-error)
              (topological-sort graph))))
      (is captured)
      (assert-node-order (graph-cycle-nodes captured)
                         '("a" "b"))
      (is (not (eq (graph-error-graph captured) graph)))
      (is (equal (graph-error-detail captured)
                 "Graph contains a cycle or disconnected cycle component."))
      (assert-condition-report captured "Cyclic nodes: a, b"))))

(deftest graph-cycle-error-report-omits-node-list-when-empty
  (let* ((graph (make-graph))
         (captured (make-condition 'graph-cycle-error
                                   :graph graph
                                   :nodes '()
                                   :detail "Graph contains a cycle or disconnected cycle component.")))
    (assert-condition-report captured
                             "Graph contains a cycle or disconnected cycle component.")))

(deftest missing-node-rejected-on-edge-addition
  (let ((graph (make-graph))
        (node (make-node "only")))
    (add-node graph node)
    (handler-case
        (add-edge graph node "missing")
      (node-not-found-error (condition)
        (is (equal (node-not-found-designator condition) "missing"))
        (is (not (eq (graph-error-graph condition) graph)))
        (is (equal (graph-error-detail condition)
                   "Node not found: missing"))
        (assert-condition-report condition "Node not found: missing")))))

(deftest add-node-rejects-non-node-designators-with-condition-data
  (let* ((graph (make-graph))
         (captured
           (capture-condition (condition invalid-input-error)
             (add-node graph "missing-node"))))
    (is captured)
    (is (equal (invalid-input-expected captured) 'node))
    (is (equal (invalid-input-value captured) "missing-node"))
    (is (equal (invalid-input-detail captured)
               "Expected NODE, got \"missing-node\""))
    (is (typep captured 'cl-dataflow-error))))

(deftest add-node-rejects-duplicate-node-names
  (let* ((graph (make-graph))
         (source (make-node "source"))
         (replacement (make-node "source")))
    (add-node graph source)
    (let ((captured
            (capture-condition (condition graph-error)
              (add-node graph replacement))))
      (is captured)
      (is (not (eq (graph-error-graph captured) graph)))
      (is (equal (graph-error-detail captured)
                 "Node already exists: source")))))

(deftest add-edge-rejects-duplicate-edge-definitions
  (let* ((graph (make-graph))
         (source (make-node "source" :outputs '("left")))
         (sink (make-node "sink" :inputs '("right")))
         (captured nil))
    (add-node graph source)
    (add-node graph sink)
    (add-edge graph source sink :from-port "left" :to-port "right")
    (handler-case
        (add-edge graph source sink :from-port "left" :to-port "right")
      (graph-error (condition)
        (setf captured condition)))
    (is captured)
    (is (not (eq (graph-error-graph captured) graph)))
    (is (equal (graph-error-detail captured)
               "Edge already exists: source:left -> sink:right"))))

(deftest add-edge-rejects-unknown-ports-immediately
  (let* ((graph (make-graph))
         (source (make-node "source" :outputs '("left")))
         (sink (make-node "sink" :inputs '("right"))))
    (add-node graph source)
    (add-node graph sink)
    (signals graph-error
      (add-edge graph source sink :from-port "missing" :to-port "right"))
    (signals graph-error
      (add-edge graph source sink :from-port "left" :to-port "missing"))))

(deftest edge-construction-normalizes-designators
  (let ((edge (make-edge 'source 'sink :from-port 'left :to-port 'right)))
    (is (equal (edge-from edge) "SOURCE"))
    (is (equal (edge-to edge) "SINK"))
    (is (equal (edge-from-port edge) "LEFT"))
    (is (equal (edge-to-port edge) "RIGHT"))))

(deftest graph-validation-rejects-unknown-ports
  (let* ((graph (make-graph))
         (source (make-node "source" :outputs '("left")))
         (sink (make-node "sink" :inputs '("right"))))
    (add-node graph source)
    (add-node graph sink)
    (setf (graph-edges graph)
          (list (make-instance 'edge
                               :from (node-name source)
                               :from-port "missing"
                               :to (node-name sink)
                               :to-port "right")))
    (signals graph-error
      (validate-graph graph))))

(deftest add-node-rejects-duplicate-port-names
  (let ((graph (make-graph)))
    (signals graph-error
      (add-node graph (make-instance 'node
                                     :name "source"
                                     :inputs '("dup" "dup")
                                     :outputs '("ok"))))
    (signals graph-error
      (add-node graph (make-instance 'node
                                     :name "source"
                                     :inputs '("ok")
                                     :outputs '("dup" "dup"))))))

(deftest graph-error-accessors-expose-condition-data
  (let* ((graph (make-graph))
         (source (make-node "source" :outputs '("left")))
         (sink (make-node "sink" :inputs '("right")))
         (captured nil))
    (add-node graph source)
    (add-node graph sink)
    (setf (graph-edges graph)
          (list (make-edge source sink :from-port "left" :to-port "missing")))
    (handler-case
        (validate-graph graph)
      (graph-error (condition)
        (setf captured condition)))
    (is captured)
    (is (not (eq (graph-error-graph captured) graph)))
    (is (equal (graph-error-detail captured)
               "Edge source -> sink uses unknown input port missing"))))

(deftest graph-validation-rejects-malformed-node-port-lists
  (let ((graph (make-graph))
        (node (make-instance 'node
                             :name "source"
                             :inputs '("ok")
                             :outputs '("dup" "dup"))))
    (setf (gethash (node-name node) (slot-value graph 'cl-dataflow::nodes)) node)
    (signals graph-error
      (validate-graph graph))))

(deftest node-not-found-exposes-designator-when-topological-sort-fails
  (let ((graph (make-graph))
        (source (make-node "source"))
        (edge nil)
        (captured nil))
    (add-node graph source)
    (setf edge (make-instance 'edge
                              :from "source"
                              :from-port "value"
                              :to "missing"
                              :to-port "value")
          (graph-edges graph) (list edge))
    (handler-case
        (topological-sort graph)
      (node-not-found-error (condition)
        (setf captured condition)))
    (is captured)
    (is (typep (node-not-found-designator captured) 'edge))
    (is (equal (edge-from (node-not-found-designator captured)) "source"))
    (is (equal (edge-to (node-not-found-designator captured)) "missing"))
    (is (not (eq (graph-error-graph captured) graph)))
    (is (equal (graph-error-detail captured)
               "Edge references missing node: source -> missing"))))

(deftest graph-errors-inherit-from-cl-dataflow-error
  (let* ((graph (make-graph))
         (source (make-node "source" :outputs '("left")))
         (sink (make-node "sink" :inputs '("right")))
         (captured nil))
    (add-node graph source)
    (add-node graph sink)
    (setf (graph-edges graph)
          (list (make-edge source sink :from-port "left" :to-port "missing")))
    (handler-case
        (validate-graph graph)
      (graph-error (condition)
        (setf captured condition)))
    (is captured)
    (is (typep captured 'cl-dataflow-error))))

(deftest invalid-input-errors-copy-mutable-designators
  (let* ((designator (list :missing "node"))
         (captured nil))
    (handler-case
        (add-node (make-graph) designator)
      (invalid-input-error (condition)
        (setf captured condition)))
    (is captured)
    (is (not (eq (invalid-input-value captured) designator)))
    (setf (second designator) "changed")
    (is (equal (invalid-input-value captured) '(:missing "node")))
    (is (equal (invalid-input-detail captured)
               "Expected NODE, got (:MISSING \"node\")"))))
