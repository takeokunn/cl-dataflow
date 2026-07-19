(in-package #:cl-dataflow.test)

(deftest subject-scan-emits-running-accumulations
  (let* ((source (make-subject))
         (running (subject-scan source #'+ 0))
         (collector (subject-collect running)))
    (dolist (value '(1 2 3)) (subject-emit source value))
    (is (equal (funcall collector) '(1 3 6)))))

(deftest subject-distinct-suppresses-repeats
  (let* ((source (make-subject))
         (unique (subject-distinct source))
         (collector (subject-collect unique)))
    (dolist (value '(1 2 1 3 2 4)) (subject-emit source value))
    (is (equal (funcall collector) '(1 2 3 4)))))

(deftest subject-tap-observes-without-changing
  (let* ((source (make-subject))
         (seen '())
         (tapped (subject-tap source (lambda (v) (push v seen))))
         (collector (subject-collect tapped)))
    (dolist (value '(1 2 3)) (subject-emit source value))
    (is (equal (funcall collector) '(1 2 3)))
    (is (equal (nreverse seen) '(1 2 3)))))

(deftest subject-take-limits-emissions
  (let* ((source (make-subject))
         (first-two (subject-take source 2))
         (collector (subject-collect first-two)))
    (dolist (value '(10 20 30 40)) (subject-emit source value))
    (is (equal (funcall collector) '(10 20)))))

(deftest subject-zip-pairs-in-lockstep
  (let* ((a (make-subject))
         (b (make-subject))
         (zipped (subject-zip a b))
         (collector (subject-collect zipped)))
    (subject-emit a 1)     ; queued, b empty -> nothing yet
    (subject-emit a 2)     ; queued
    (subject-emit b 10)    ; pairs with 1
    (subject-emit b 20)    ; pairs with 2
    (is (equal (funcall collector) '((1 . 10) (2 . 20))))))

(deftest subject-combine-latest-tracks-both
  (let* ((a (make-subject))
         (b (make-subject))
         (combined (subject-combine-latest a b))
         (collector (subject-collect combined)))
    (subject-emit a 1)     ; b not seen yet -> nothing
    (subject-emit b 10)    ; -> (1 . 10)
    (subject-emit a 2)     ; -> (2 . 10)
    (subject-emit b 20)    ; -> (2 . 20)
    (is (equal (funcall collector) '((1 . 10) (2 . 10) (2 . 20))))))

(deftest subject-buffer-groups-fixed-batches
  (let* ((source (make-subject))
         (batches (subject-buffer source 2))
         (collector (subject-collect batches)))
    (dolist (value '(1 2 3 4 5)) (subject-emit source value))
    ;; (1 2) and (3 4); the trailing 5 stays buffered.
    (is (equal (funcall collector) '((1 2) (3 4))))
    (signals invalid-input-error (subject-buffer source 0))))

(deftest subject-drop-skips-the-first-n
  (let* ((source (make-subject))
         (dropped (subject-drop source 2))
         (collector (subject-collect dropped)))
    (dolist (value '(10 20 30 40)) (subject-emit source value))
    (is (equal (funcall collector) '(30 40)))))

(deftest subject-take-while-stops-at-first-failure
  (let* ((source (make-subject))
         (taken (subject-take-while source (lambda (x) (< x 3))))
         (collector (subject-collect taken)))
    ;; 1,2 pass; 3 fails and stops forever, so the later 1 is not re-emitted.
    (dolist (value '(1 2 3 1)) (subject-emit source value))
    (is (equal (funcall collector) '(1 2)))))

(deftest subject-drop-while-forwards-after-first-failure
  (let* ((source (make-subject))
         (kept (subject-drop-while source (lambda (x) (< x 3))))
         (collector (subject-collect kept)))
    ;; 1,2 dropped; from 3 on everything is forwarded, including the later 1.
    (dolist (value '(1 2 3 1)) (subject-emit source value))
    (is (equal (funcall collector) '(3 1)))))

(deftest subject-count-emits-running-total
  (let* ((source (make-subject))
         (counted (subject-count source))
         (collector (subject-collect counted)))
    (dolist (value '(:a :b :c)) (subject-emit source value))
    (is (equal (funcall collector) '(1 2 3)))))

(deftest subject-flat-map-forwards-inner-emissions
  (let* ((source (make-subject))
         (inner-a (make-subject))
         (inner-b (make-subject))
         (flattened (subject-flat-map source (lambda (v) (if (eq v :a) inner-a inner-b))))
         (collector (subject-collect flattened)))
    (subject-emit source :a)   ; subscribe to inner-a
    (subject-emit source :b)   ; subscribe to inner-b
    (subject-emit inner-a 1)
    (subject-emit inner-b 2)
    (subject-emit inner-a 3)
    (is (equal (funcall collector) '(1 2 3)))))

(deftest subject-partition-splits-by-predicate
  (let ((source (make-subject)))
    (multiple-value-bind (evens odds) (subject-partition source #'evenp)
      (let ((even-log (subject-collect evens))
            (odd-log (subject-collect odds)))
        (dolist (value '(1 2 3 4 5 6)) (subject-emit source value))
        (is (equal (funcall even-log) '(2 4 6)))
        (is (equal (funcall odd-log) '(1 3 5)))))))
