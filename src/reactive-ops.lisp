(in-package #:cl-dataflow)

;;;; Stateful and combining operators over reactive subjects, bringing the
;;;; push-based side toward parity with the pull-based stream operators. Each
;;;; returns a derived subject that subscribes to its source(s) and re-emits;
;;;; per-operator state lives in the closure. Everything is synchronous, so an
;;;; emission propagates through the whole derived graph before EMIT returns.

(defun subject-scan (subject function seed)
  "Return a derived subject that emits a running accumulation: starting from SEED,
each source value V produces and emits (FUNCALL FUNCTION ACCUMULATOR V)."
  (let ((result (make-subject))
        (accumulator seed))
    (subject-subscribe subject
                       (lambda (value)
                         (setf accumulator (funcall function accumulator value))
                         (subject-emit result accumulator)))
    result))

(defun subject-distinct (subject &key (test 'equal))
  "Return a derived subject that re-emits only values not previously emitted (under
TEST). Runs in O(n) membership per emission."
  (let ((result (make-subject))
        (seen '()))
    (subject-subscribe subject
                       (lambda (value)
                         (unless (member value seen :test test)
                           (push value seen)
                           (subject-emit result value))))
    result))

(defun subject-tap (subject function)
  "Return a derived subject that calls FUNCTION on each source value for its side
effect, then re-emits the value unchanged."
  (let ((result (make-subject)))
    (subject-subscribe subject
                       (lambda (value)
                         (funcall function value)
                         (subject-emit result value)))
    result))

(defun subject-take (subject n)
  "Return a derived subject that re-emits only the first N values of SUBJECT and
ignores the rest."
  (let ((result (make-subject))
        (remaining n))
    (subject-subscribe subject
                       (lambda (value)
                         (when (plusp remaining)
                           (decf remaining)
                           (subject-emit result value))))
    result))

(defun subject-zip (subject-a subject-b)
  "Return a derived subject that pairs values of SUBJECT-A and SUBJECT-B in
lockstep, emitting (A . B) once the Nth value of each has arrived. Values queue
until their counterpart arrives."
  (let ((result (make-subject))
        (queue-a '())
        (tail-a '())
        (queue-b '())
        (tail-b '()))
    (flet ((enqueue-a (value)
             (let ((cell (list value)))
               (if queue-a
                   (setf (rest tail-a) cell
                         tail-a cell)
                   (setf queue-a cell
                         tail-a cell))))
           (enqueue-b (value)
             (let ((cell (list value)))
               (if queue-b
                   (setf (rest tail-b) cell
                         tail-b cell)
                   (setf queue-b cell
                         tail-b cell))))
           (emit-if-ready ()
             (when (and queue-a queue-b)
               (let ((value-a (first queue-a))
                     (value-b (first queue-b)))
                 (setf queue-a (rest queue-a)
                       queue-b (rest queue-b))
                 (unless queue-a
                   (setf tail-a '()))
                 (unless queue-b
                   (setf tail-b '()))
                 (subject-emit result (cons value-a value-b))))))
      (subject-subscribe subject-a
                         (lambda (value)
                           (enqueue-a value)
                           (emit-if-ready)))
      (subject-subscribe subject-b
                         (lambda (value)
                           (enqueue-b value)
                           (emit-if-ready))))
    result))

(defun subject-combine-latest (subject-a subject-b)
  "Return a derived subject that emits (LATEST-A . LATEST-B) whenever either source
emits, once both have emitted at least once."
  (let ((result (make-subject))
        (latest-a nil) (has-a nil)
        (latest-b nil) (has-b nil))
    (flet ((emit-combined ()
             (when (and has-a has-b)
               (subject-emit result (cons latest-a latest-b)))))
      (subject-subscribe subject-a
                         (lambda (value) (setf latest-a value has-a t) (emit-combined)))
      (subject-subscribe subject-b
                         (lambda (value) (setf latest-b value has-b t) (emit-combined))))
    result))

(defun subject-buffer (subject n)
  "Return a derived subject that collects every N source values into a list and
emits that list. A trailing partial buffer is not emitted. N must be positive."
  (%positive-size n "SUBJECT-BUFFER")
  (let ((result (make-subject))
        (buffer '())
        (count 0))
    (subject-subscribe subject
                       (lambda (value)
                         (push value buffer)
                         (incf count)
                         (when (= count n)
                           (subject-emit result (reverse buffer))
                           (setf buffer '() count 0))))
    result))

(defun subject-drop (subject n)
  "Return a derived subject that ignores the first N source values and re-emits the
rest. The push-side dual of STREAM-DROP."
  (let ((result (make-subject))
        (remaining n))
    (subject-subscribe subject
                       (lambda (value)
                         (if (plusp remaining)
                             (decf remaining)
                             (subject-emit result value))))
    result))

(defun subject-take-while (subject predicate)
  "Return a derived subject that re-emits the leading run of source values
satisfying PREDICATE and permanently stops at (and excluding) the first that does
not."
  (let ((result (make-subject))
        (active t))
    (subject-subscribe subject
                       (lambda (value)
                         (when active
                           (if (funcall predicate value)
                               (subject-emit result value)
                               (setf active nil)))))
    result))

(defun subject-drop-while (subject predicate)
  "Return a derived subject that drops the leading run of source values satisfying
PREDICATE, then re-emits every value from the first that does not onward."
  (let ((result (make-subject))
        (dropping t))
    (subject-subscribe subject
                       (lambda (value)
                         (unless (and dropping (funcall predicate value))
                           (setf dropping nil)
                           (subject-emit result value))))
    result))

(defun subject-flat-map (subject function)
  "Return a derived subject that, for each value V of SUBJECT, calls FUNCTION to
obtain an inner subject and forwards all of that inner subject's later emissions.
The higher-order (flatten) reactive operator."
  (let ((result (make-subject)))
    (subject-subscribe subject
                       (lambda (value)
                         (subject-subscribe (funcall function value)
                                            (lambda (inner-value)
                                              (subject-emit result inner-value)))))
    result))

(defun subject-partition (subject predicate)
  "Return (VALUES MATCHING NON-MATCHING): two derived subjects that split SUBJECT's
values by PREDICATE -- each value is emitted on MATCHING when PREDICATE holds, and
on NON-MATCHING otherwise."
  (let ((matching (make-subject))
        (non-matching (make-subject)))
    (subject-subscribe subject
                       (lambda (value)
                         (if (funcall predicate value)
                             (subject-emit matching value)
                             (subject-emit non-matching value))))
    (values matching non-matching)))

(defun subject-count (subject)
  "Return a derived subject that emits the running count of source emissions
(1, 2, 3, ...)."
  (let ((result (make-subject))
        (count 0))
    (subject-subscribe subject
                       (lambda (value)
                         (declare (ignore value))
                         (incf count)
                         (subject-emit result count)))
    result))
