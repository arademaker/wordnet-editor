(in-package :wordnet)

(defvar *suggestions-core* (make-instance 'solr:solr :uri "http://localhost:8983/solr/suggestions"))

(defun search-suggestions/solr ()
  (solr:solr-result->doc-alist
   (solr:solr-query *suggestions-core*
		    :query "status:committed" 
		    :param-alist '((:rows . 1000000)))))

;; we need to follow https://github.com/franzinc/solr/blob/master/solr.lisp#L292
;; so we can be compatible with the way their package generates alist
(defun my-intern (x)
  (intern x :keyword))

;; to use this option, first dump the SOLR core with the following url
;; http://localhost:8983/solr/suggestions/select?q=*%3A*&fq=status%3Acommitted&rows=1000000&wt=json&indent=false
(defun search-suggestions/file (file)
  (setf yason:*parse-object-as* :alist)
  (setf yason:*parse-object-key-fn* #'my-intern)
  (cdr (assoc :docs (cdr (assoc :response (with-open-file (s file) (yason:parse s)))))))

(defun search-suggestions ()
  (search-suggestions/file "/tmp/s.json"))

(defun process-suggestions ()
  (dolist (s (search-suggestions))
    (let* ((action (cdr (assoc :action s)))
	   (status (cdr (assoc :status s)))
	   (doc-id (cdr (assoc :doc_id s)))
	   (doc-type (cdr (assoc :doc_type s)))
	   (params (cdr (assoc :params s)))
	   (res (resource (format nil "synset-~a" doc-id) "wn30pt")))
      (when (and (string-equal "committed" status)
		 (string-equal "synset" doc-type))
	(cond ((string-equal "add-word-pt" action)
	       (format t "add-w [~a] to [~a]~%" params res)
	       (add-synset-word res params))
	      ((string-equal "remove-word-pt" action)
	       (format t "rm-w  [~a] to [~a]~%" params res)
	       (remove-word params :synset res))
	      ((string-equal "add-gloss-pt" action)
	       (format t "add-g  [~a] to [~a]~%" params res)
	       (add-synset-prop res !wn30:gloss params))
	      ((string-equal "add-example-pt" action)
	       (format t "add-e  [~a] to [~a]~%" params res)
	       (add-synset-prop res !wn30:example params)))))))

