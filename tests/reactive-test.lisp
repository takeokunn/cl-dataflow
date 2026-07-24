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

(deftest subject-collect-supports-bounded-history
  (let* ((subject (make-subject))
         (collector (subject-collect subject :limit 2 :on-limit :drop-newest)))
    (subject-emit subject 1)
    (subject-emit subject 2)
    (subject-emit subject 3)
    (is (equal (funcall collector) '(1 2)))))

(deftest subject-collect-errors-when-limit-is-exceeded
  (let* ((subject (make-subject))
         (collector (subject-collect subject :limit 2)))
    (subject-emit subject 1)
    (subject-emit subject 2)
    (signals invalid-input-error
      (subject-emit subject 3))
    (is (equal (funcall collector) '(1 2)))))

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

(deftest subject-subscribe-preserves-order-after-unsubscribe
  (let ((subject (make-subject))
        (seen '()))
    (labels ((record (tag)
               (lambda (value) (push (cons tag value) seen))))
      (let ((first (record :first))
            (second (record :second))
            (third (record :third)))
        (subject-subscribe subject first)
        (subject-subscribe subject second)
        (subject-unsubscribe subject first)
        (subject-subscribe subject third)
        (subject-emit subject :value)
        (is (equal (reverse seen) '((:second . :value) (:third . :value))))
        (is (= (subject-subscriber-count subject) 2))))))

;; Single-source operators (and their compositions) as declarative specs; see
;; DEFINE-SINGLE-SOURCE-SUBJECT-TESTS. SUBJECT-MERGE below has two sources and
;; stays a hand-written DEFTEST.
(define-single-source-subject-tests
  (subject-map-transforms-emissions
   (lambda (s) (subject-map s (lambda (x) (* x 2)))) (1 5) (2 10))
  (subject-filter-drops-non-matching
   (lambda (s) (subject-filter s #'evenp)) (1 2 3 4 5 6) (2 4 6))
  ;; A small reactive pipeline: source -> filter evens -> map (*10).
  (reactive-graph-chains-operators
   (lambda (s) (subject-map (subject-filter s #'evenp) (lambda (x) (* x 10))))
   (1 2 3 4) (20 40)))

(deftest subject-merge-combines-sources
  (let* ((a (make-subject))
         (b (make-subject))
         (merged (subject-merge a b))
         (collector (subject-collect merged)))
    (subject-emit a 1)
    (subject-emit b 2)
    (subject-emit a 3)
    (is (equal (funcall collector) '(1 2 3)))))
