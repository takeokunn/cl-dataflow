(in-package #:cl-dataflow)

;;;; Search, predicate, and combinatorial helpers over streams: first-match index,
;;;; a "no element matches" predicate, the most frequent element, and the Cartesian
;;;; product of two streams. Consumers iterate; STREAM-CARTESIAN stays lazy.

(defun stream-find-index (predicate stream)
  "Return the 0-based index of the first element of STREAM satisfying PREDICATE, or
NIL when none does."
  (let ((index 0)
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return nil))
        (when (funcall predicate (car step)) (return index))
        (incf index)
        (setf current (cdr step))))))

(defun stream-none-p (predicate stream)
  "Return true when no element of STREAM satisfies PREDICATE (true for an empty
stream)."
  (let ((current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return t))
        (when (funcall predicate (car step)) (return nil))
        (setf current (cdr step))))))

(defun stream-mode (stream &key (test 'equal))
  "Return the most frequently occurring element of STREAM (the first-seen element
wins ties), or NIL when STREAM is empty. TEST is the hash-table equality used to
group elements."
  (let ((counts (make-hash-table :test test))
        (order '())
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return))
        (let ((element (car step)))
          (unless (nth-value 1 (gethash element counts))
            (push element order)
            (setf (gethash element counts) 0))
          (incf (gethash element counts)))
        (setf current (cdr step))))
    (let ((best nil)
          (best-count -1))
      (dolist (element (nreverse order) best)
        (when (> (gethash element counts) best-count)
          (setf best-count (gethash element counts)
                best element))))))

(defun stream-cartesian (stream-a stream-b)
  "Return a stream of (A . B) conses for every pair drawn from STREAM-A and
STREAM-B, with B varying fastest. STREAM-B is re-consumed once per element of
STREAM-A (streams are pure, so this is safe)."
  (stream-flat-map (lambda (a)
                     (stream-map (lambda (b) (cons a b)) stream-b))
                   stream-a))
