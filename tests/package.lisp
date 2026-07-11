(defpackage #:cl-dataflow.test
  (:use #:cl #:cl-dataflow)
  (:export #:run-tests))

(in-package #:cl-dataflow.test)

(defmacro %load-fragment (pathname)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (let ((source-path (merge-pathnames ,pathname
                                         (or *load-truename*
                                             *compile-file-truename*))))
       (with-open-file (stream source-path :direction :input)
         (load stream)))))

(%load-fragment #P"test-support-assertions.lisp")
(%load-fragment #P"test-support-fixtures.lisp")
(%load-fragment #P"test-runner.lisp")
