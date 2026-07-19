(in-package #:cl-dataflow.test)

(deftest state-machine-to-plist-round-trips-structure
  (with-state-machine-fixture (machine
                               :state "idle"
                               :metadata '((:kind :demo))
                               :transitions ((start "idle" "start" "running")
                                             (finish "running" "finish" "done")))
    (let* ((plist (state-machine-to-plist machine))
           (rebuilt (plist-to-state-machine plist)))
      (is (equal (getf plist :state) "idle"))
      (is (equal (getf plist :initial-state) "idle"))
      (is (equal (state-machine-state rebuilt) "idle"))
      (is (equal (state-machine-states rebuilt) '("done" "idle" "running")))
      ;; The rebuilt machine serialises identically.
      (is (equal (state-machine-to-plist rebuilt) plist)))))

(deftest state-machine-complete-p-checks-totality
  ;; Every (state, event) is defined: a/go->b and b/go->a.
  (with-state-machine-fixture (machine
                               :state "a"
                               :transitions ((ab "a" "go" "b") (ba "b" "go" "a")))
    (is (state-machine-complete-p machine)))
  ;; (b, go) is missing, so it is not complete.
  (with-state-machine-fixture (machine
                               :state "a"
                               :transitions ((ab "a" "go" "b")))
    (is (not (state-machine-complete-p machine)))))

(deftest state-machine-transition-for-looks-up-by-state-and-event
  (with-state-machine-fixture (machine
                               :state "a"
                               :transitions ((go "a" "go" "b") (stop "a" "stop" "c")))
    (let ((found (state-machine-transition-for machine "a" "stop")))
      (is (equal (transition-to found) "c")))
    ;; No transition from b at all.
    (is (null (state-machine-transition-for machine "b" "go")))
    ;; Right state, wrong event.
    (is (null (state-machine-transition-for machine "a" "pause")))))

(deftest add-and-remove-transition-mutate-in-place
  (with-state-machine-fixture (machine
                               :state "a"
                               :transitions ((ab "a" "go" "b")))
    (add-transition machine "b" "back" "a")
    (is (= (length (state-machine-transitions machine)) 2))
    (is (state-machine-transition-for machine "b" "back"))
    (remove-transition machine "a" "go" "b")
    (is (= (length (state-machine-transitions machine)) 1))
    (is (null (state-machine-transition-for machine "a" "go")))))

(deftest state-machine-relabel-state-renames-everywhere
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((start "idle" "start" "running")
                                             (finish "running" "finish" "idle")))
    (let ((relabeled (state-machine-relabel-state machine "idle" "ready")))
      (is (equal (state-machine-state relabeled) "ready"))
      (is (equal (state-machine-initial-state relabeled) "ready"))
      (is (equal (state-machine-states relabeled) '("ready" "running")))
      ;; The original is unchanged.
      (is (equal (state-machine-state machine) "idle")))))
