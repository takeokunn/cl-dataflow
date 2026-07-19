(in-package #:cl-dataflow.test)

(deftest graph->dot-renders-deterministic-digraph
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (a c)))
    (let ((dot (graph->dot graph :name "flow")))
      (is (search "digraph flow {" dot))
      (is (search "\"a\";" dot))
      (is (search "\"a\" -> \"b\" [label=\"value -> value\"];" dot))
      (is (search "\"a\" -> \"c\" [label=\"value -> value\"];" dot))
      ;; Node "a" is emitted before its edges, and edges are endpoint-sorted.
      (is (< (search "\"a\" -> \"b\"" dot)
             (search "\"a\" -> \"c\"" dot))))))

(deftest graph->dot-escapes-quotes-in-names
  (with-graph-fixture (graph ((weird "a\"b")))
    (is (search "\"a\\\"b\"" (graph->dot graph)))))

(deftest graph->mermaid-renders-flowchart
  (with-graph-fixture (graph
                       ((a "a") (b "b"))
                       :edges ((a b)))
    (let ((mermaid (graph->mermaid graph :direction "LR")))
      (is (search "flowchart LR" mermaid))
      (is (search "n0[\"a\"]" mermaid))
      (is (search "n1[\"b\"]" mermaid))
      (is (search "n0 -->|value -> value| n1" mermaid)))))

(deftest graph-to-plist-captures-structure
  (with-graph-fixture (graph
                       ((a "a" :outputs '("out") :metadata '((:kind :source)))
                        (b "b" :inputs '("in")))
                       :edges ((a b :from-port "out" :to-port "in")))
    (let* ((plist (graph-to-plist graph))
           (nodes (getf plist :nodes))
           (edges (getf plist :edges)))
      (is (equal (mapcar (lambda (n) (getf n :name)) nodes) '("a" "b")))
      (is (equal (getf (first nodes) :outputs) '("out")))
      (is (equal (getf (first nodes) :metadata) '((:kind :source))))
      (is (= (length edges) 1))
      (assert-plist-entry (first edges)
                          (:from "a") (:from-port "out") (:to "b") (:to-port "in")))))

(deftest plist-to-graph-round-trips-structure
  (with-graph-fixture (graph
                       ((a "a" :outputs '("out") :metadata '((:kind :source)))
                        (b "b" :inputs '("in") :outputs '("done")))
                       :edges ((a b :from-port "out" :to-port "in")))
    (let ((rebuilt (plist-to-graph (graph-to-plist graph))))
      (is (equal (graph-node-names rebuilt) '("a" "b")))
      (is (equal (node-outputs (find-node rebuilt "a")) '("out")))
      (is (equal (node-inputs (find-node rebuilt "b")) '("in")))
      (is (equal (node-metadata (find-node rebuilt "a")) '((:kind :source))))
      (is (graph-reachable-p rebuilt "a" "b"))
      ;; A rebuilt graph serialises back to the same plist (idempotent shape).
      (is (equal (graph-to-plist rebuilt) (graph-to-plist graph))))))

(deftest empty-graph-serialisation-is-well-formed
  (let ((plist (graph-to-plist (make-graph))))
    (is (null (getf plist :nodes)))
    (is (null (getf plist :edges)))
    (is (graph-empty-p (plist-to-graph plist)))))
