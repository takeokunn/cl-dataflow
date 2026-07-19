(in-package #:cl-dataflow.test)

(deftest graph-density-is-edges-over-possible
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c) (a c)))
    ;; 3 edges out of a possible 3*2 = 6.
    (is (= (graph-density graph) 1/2)))
  ;; Fewer than two nodes has zero density.
  (with-graph-fixture (graph ((solo "solo")))
    (is (= (graph-density graph) 0)))
  (is (= (graph-density (make-graph)) 0)))

(deftest graph-degree-histogram-counts-total-degree
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c)))
    ;; a: out1 in0 = 1; b: out1 in1 = 2; c: out0 in1 = 1.
    (is (equal (graph-degree-histogram graph) '((1 . 2) (2 . 1))))))

(deftest graph-bipartite-p-detects-two-colourability
  ;; A path is bipartite; two disjoint components are still handled.
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c") (x "x") (y "y"))
                       :edges ((a b) (b c) (x y)))
    (is (graph-bipartite-p graph)))
  ;; An odd cycle is not bipartite.
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c) (c a)))
    (is (not (graph-bipartite-p graph))))
  ;; A self-loop is not bipartite.
  (with-graph-fixture (graph ((x "x")) :edges ((x x)))
    (is (not (graph-bipartite-p graph)))))

(deftest graph-equal-p-compares-structure-order-independently
  (let ((left (make-graph))
        (right (make-graph)))
    ;; Build the same graph in different insertion orders.
    (dolist (name '("a" "b")) (add-node left (make-node name)))
    (add-edge left "a" "b")
    (dolist (name '("b" "a")) (add-node right (make-node name)))
    (add-edge right "a" "b")
    (is (graph-equal-p left right))
    ;; A structural difference is detected.
    (add-node right (make-node "c"))
    (is (not (graph-equal-p left right)))))

(deftest graph-undirected-reachable-p-follows-weak-connectivity
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b)))
    ;; a and b are weakly connected even though the edge is directed a -> b.
    (is (graph-undirected-reachable-p graph "b" "a"))
    (is (graph-undirected-reachable-p graph "a" "a"))
    ;; c is isolated.
    (is (not (graph-undirected-reachable-p graph "a" "c")))
    (signals node-not-found-error (graph-undirected-reachable-p graph "a" "missing"))))
