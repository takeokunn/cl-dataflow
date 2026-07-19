(in-package #:cl-dataflow.test)

(deftest graph-connected-p-checks-weak-connectivity
  (with-graph-fixture (graph ((a "a") (b "b") (c "c")) :edges ((a b) (b c)))
    (is (graph-connected-p graph)))
  (with-graph-fixture (graph ((a "a") (b "b")))
    (is (not (graph-connected-p graph))))
  (is (graph-connected-p (make-graph))))

(deftest graph-strongly-connected-p-checks-mutual-reachability
  (with-graph-fixture (graph ((a "a") (b "b") (c "c")) :edges ((a b) (b c) (c a)))
    (is (graph-strongly-connected-p graph)))
  (with-graph-fixture (graph ((a "a") (b "b")) :edges ((a b)))
    (is (not (graph-strongly-connected-p graph)))))

(deftest graph-self-loop-nodes-lists-self-loops
  (with-graph-fixture (graph ((a "a") (b "b") (c "c")) :edges ((a a) (a b) (c c)))
    (is (equal (graph-self-loop-nodes graph) '("a" "c"))))
  (with-graph-fixture (graph ((a "a") (b "b")) :edges ((a b)))
    (is (null (graph-self-loop-nodes graph)))))

(deftest graph-condensation-collapses-components
  ;; a<->b form a cycle; both a->c and b->c cross into c.
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b a) (a c) (b c)))
    (let ((condensed (graph-condensation graph)))
      (is (equal (graph-node-names condensed) '("a" "c")))
      ;; The cross edges a->c and b->c collapse to a single a->c edge.
      (is (= (graph-size condensed) 1))
      (is (graph-acyclic-p condensed))
      (is (equal (getf (node-metadata (find-node condensed "a")) :members)
                 '("a" "b"))))))

(deftest graph-distances-from-gives-single-source-hops
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c") (d "d"))
                       :edges ((a b) (a c) (b d) (c d)))
    ;; d is reached via b and via c; BFS records the shorter (equal) hop of 2.
    (is (equal (graph-distances-from graph "a")
               '(("b" . 1) ("c" . 1) ("d" . 2))))
    ;; A sink reaches nothing.
    (is (null (graph-distances-from graph "d")))))

(deftest graph-eccentricity-and-diameter
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c") (d "d"))
                       :edges ((a b) (b c) (c d)))
    (is (= (graph-eccentricity graph "a") 3))
    (is (= (graph-eccentricity graph "d") 0))
    (is (= (graph-diameter graph) 3)))
  (is (= (graph-diameter (make-graph)) 0)))
