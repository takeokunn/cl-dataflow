(in-package #:cl-dataflow.test)

(deftest subjects-emit-to-subscribers-in-order
  (let* ((subject (make-subject))
         (collector (subject-collect subject)))
    (is (subject-p subject))
    (is (= (subject-subscriber-count subject) 1))
    (subject-emit subject 1)
    (subject-emit subject 2)
    (subject-emit subject 3)
    (is (equal (funcall collector) '(1 2 3)))))

(deftest subject-unsubscribe-stops-delivery
  (let* ((subject (make-subject))
         (seen '())
         (handler (lambda (value) (push value seen))))
    (subject-subscribe subject handler)
    (subject-emit subject :a)
    (subject-unsubscribe subject handler)
    (subject-emit subject :b)
    (is (equal seen '(:a)))
    (is (zerop (subject-subscriber-count subject)))))

(deftest subject-map-transforms-emissions
  (let* ((source (make-subject))
         (doubled (subject-map source (lambda (x) (* x 2))))
         (collector (subject-collect doubled)))
    (subject-emit source 1)
    (subject-emit source 5)
    (is (equal (funcall collector) '(2 10)))))

(deftest subject-filter-drops-non-matching
  (let* ((source (make-subject))
         (evens (subject-filter source #'evenp))
         (collector (subject-collect evens)))
    (dolist (value '(1 2 3 4 5 6)) (subject-emit source value))
    (is (equal (funcall collector) '(2 4 6)))))

(deftest subject-merge-combines-sources
  (let* ((a (make-subject))
         (b (make-subject))
         (merged (subject-merge a b))
         (collector (subject-collect merged)))
    (subject-emit a 1)
    (subject-emit b 2)
    (subject-emit a 3)
    (is (equal (funcall collector) '(1 2 3)))))

(deftest reactive-graph-chains-operators
  ;; A small reactive pipeline: source -> filter evens -> map (*10).
  (let* ((source (make-subject))
         (result (subject-map (subject-filter source #'evenp) (lambda (x) (* x 10))))
         (collector (subject-collect result)))
    (dolist (value '(1 2 3 4)) (subject-emit source value))
    (is (equal (funcall collector) '(20 40)))))
