(defpackage #:cl-dataflow.test
  (:use #:cl #:cl-dataflow)
  (:import-from #:cl-weave
                #:defmatcher
                #:expect
                #:gen-integer
                #:gen-list
                #:gen-member
                #:gen-state-machine
                #:gen-tuple
                #:it-property
                #:signals)
  (:export #:run-tests))

(in-package #:cl-dataflow.test)

(defmacro %load-fragment (pathname)
  (let ((source-directory
          (make-pathname :name nil
                          :type nil
                          :defaults (or *compile-file-pathname*
                                        *load-truename*))))
    `(eval-when (:compile-toplevel :load-toplevel :execute)
        (load (merge-pathnames ,pathname ,source-directory)))))

(%load-fragment #P"test-support-assertions.lisp")
(%load-fragment #P"test-support-fixtures.lisp")
(%load-fragment #P"test-runner.lisp")
