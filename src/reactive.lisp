(in-package #:cl-dataflow)

;;;; Synchronous push-based reactive subjects -- the producer-driven dual of the
;;;; consumer-driven FLOW-STREAM. A SUBJECT holds an ordered list of subscriber
;;;; functions; SUBJECT-EMIT pushes a value to each of them, immediately and in
;;;; subscription order (no threads, fully deterministic). Derived subjects
;;;; (map/filter/merge) subscribe to their sources and re-emit, so a small reactive
;;;; graph can be wired up for event-driven workflows. The SUBJECT type is opaque;
;;;; use SUBJECT-P and the operators below.

(defstruct (subject (:constructor %make-subject ())
                    (:copier nil)
                    (:predicate subject-p))
  (subscribers '()))

(defun make-subject ()
  "Return a fresh subject with no subscribers."
  (%make-subject))

(defun subject-subscribe (subject function)
  "Register FUNCTION (called with each emitted value) as a subscriber of SUBJECT,
after any existing subscribers, and return FUNCTION (usable as an unsubscribe
token)."
  (setf (subject-subscribers subject)
        (append (subject-subscribers subject) (list function)))
  function)

(defun subject-unsubscribe (subject function)
  "Remove FUNCTION from SUBJECT's subscribers (all occurrences) and return SUBJECT."
  (setf (subject-subscribers subject)
        (remove function (subject-subscribers subject)))
  subject)

(defun subject-subscriber-count (subject)
  "Return the number of subscribers currently registered on SUBJECT."
  (length (subject-subscribers subject)))

(defun subject-emit (subject value)
  "Push VALUE to every current subscriber of SUBJECT, synchronously and in
subscription order, and return SUBJECT. Subscribers are notified from a snapshot,
so a subscriber may unsubscribe during emission without disturbing the current
pass."
  (dolist (subscriber (copy-list (subject-subscribers subject)) subject)
    (funcall subscriber value)))

(defun subject-map (subject function)
  "Return a derived subject that emits (FUNCALL FUNCTION VALUE) whenever SUBJECT
emits VALUE."
  (let ((result (make-subject)))
    (subject-subscribe subject
                       (lambda (value) (subject-emit result (funcall function value))))
    result))

(defun subject-filter (subject predicate)
  "Return a derived subject that re-emits only the values of SUBJECT for which
PREDICATE is true."
  (let ((result (make-subject)))
    (subject-subscribe subject
                       (lambda (value)
                         (when (funcall predicate value)
                           (subject-emit result value))))
    result))

(defun subject-merge (&rest subjects)
  "Return a derived subject that emits whenever any of SUBJECTS emits."
  (let ((result (make-subject)))
    (dolist (source subjects result)
      (subject-subscribe source (lambda (value) (subject-emit result value))))))

(defun subject-collect (subject &key limit (on-limit :error))
  "Subscribe a collector to SUBJECT and return a function of no arguments yielding
the list of values SUBJECT has emitted since, in emission order.
LIMIT bounds retained values. ON-LIMIT is :ERROR (signal from SUBJECT-EMIT) or
:DROP-NEWEST (ignore values after LIMIT)."
  (%validate-stream-limit limit "SUBJECT-COLLECT")
  (%validate-stream-limit-mode on-limit "SUBJECT-COLLECT" '(:error :drop-newest))
  (let ((collected '())
        (count 0))
    (subject-subscribe subject
                       (lambda (value)
                         (cond ((and limit (= count limit))
                                (ecase on-limit
                                  (:error (%signal-stream-limit-exceeded
                                           "SUBJECT-COLLECT"
                                           limit))
                                  (:drop-newest nil)))
                               (t
                                (push value collected)
                                (incf count)))))
    (lambda () (reverse collected))))
