;;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;;
;;;; $Id: $

(in-package #:clsql-base-sys)

(setf (documentation 'database-name 'function)
      "Returns the name of a database.")

;;; Database handling

(defvar *connect-if-exists* :error
  "Default value for the if-exists parameter of connect calls.")

(defvar *connected-databases* nil
  "List of active database objects.")

(defun connected-databases ()
  "Return the list of active database objects."
  *connected-databases*)

(defvar *default-database* nil
  "Specifies the default database to be used.")

;;; usql
(defun find-database (database &key (errorp t) (db-type nil))
  "The function FIND-DATABASE, given a string DATABASE, searches
amongst the connected databases for one matching the name DATABASE. If
there is exactly one such database, it is returned and the second
return value count is 1. If more than one databases match and ERRORP
is nil, then the most recently connected of the matching databases is
returned and count is the number of matches. If no matching database
is found and ERRORP is nil, then nil is returned. If none, or more
than one, matching databases are found and ERRORP is true, then an
error is signalled. If the argument database is a database, it is
simply returned."
  (etypecase database
    (database
     (values database 1))
    (string
     (let* ((matches (remove-if 
                      #'(lambda (db)
                          (not (and (string= (database-name db) database)
                                    (if db-type
                                        (equal (database-type db) db-type)
                                        t))))
                      (connected-databases)))
            (count (length matches)))
       (if (or (not errorp) (= count 1))
           (values (car matches) count)
           (cerror "Return nil."
                   'clsql-simple-error
                   :format-control "There exists ~A database called ~A."
                   :format-arguments
                   (list (if (zerop count) "no" "more than one")
                         database)))))))


(defun connect (connection-spec
		&key (if-exists *connect-if-exists*)
		(make-default t)
                (pool nil)
		(database-type *default-database-type*))
  "Connects to a database of the given database-type, using the
type-specific connection-spec.  The value of if-exists determines what
happens if a connection to that database is already established.  A
value of :new means create a new connection.  A value of :warn-new
means warn the user and create a new connect.  A value of :warn-old
means warn the user and use the old connection.  A value of :error
means fail, notifying the user.  A value of :old means return the old
connection.  If make-default is true, then *default-database* is set
to the new connection, otherwise *default-database is not changed. If
pool is t the connection will be taken from the general pool, if pool
is a conn-pool object the connection will be taken from this pool."
  (if pool
      (acquire-from-pool connection-spec database-type pool)
      (let* ((db-name (database-name-from-spec connection-spec database-type))
             (old-db (unless (eq if-exists :new)
                       (find-database db-name :db-type database-type
                                      :errorp nil)))
             (result nil))
        (if old-db
            (ecase if-exists
              (:warn-new
               (setq result
                     (database-connect connection-spec database-type))
               (warn 'clsql-exists-warning :old-db old-db :new-db result))
              (:error
               (restart-case
                   (error 'clsql-exists-error :old-db old-db)
                 (create-new ()
                   :report "Create a new connection."
                   (setq result
                         (database-connect connection-spec database-type)))
                 (use-old ()
                   :report "Use the existing connection."
                   (setq result old-db))))
              (:warn-old
               (setq result old-db)
               (warn 'clsql-exists-warning :old-db old-db :new-db old-db))
              (:old
               (setq result old-db)))
            (setq result
                  (database-connect connection-spec database-type)))
        (when result
          (pushnew result *connected-databases*)
          (when make-default (setq *default-database* result))
          result))))


(defun disconnect (&key (database *default-database*) (error nil))

  "Closes the connection to DATABASE and resets *default-database* if
that database was disconnected. If database is a database object, then
it is used directly. Otherwise, the list of connected databases is
searched to find one with DATABASE as its connection
specifications. If no such database is found, then if ERROR and
DATABASE are both non-nil an error is signaled, otherwise DISCONNECT
returns nil. If the database is from a pool it will be released to
this pool."
  (let ((database (find-database database :errorp (and database error))))
    (when database
      (if (conn-pool database)
          (when (release-to-pool database)
            (setf *connected-databases* (delete database *connected-databases*))
            (when (eq database *default-database*)
              (setf *default-database* (car *connected-databases*)))
            t)
          (when (database-disconnect database)
            (setf *connected-databases* (delete database *connected-databases*))
            (when (eq database *default-database*)
              (setf *default-database* (car *connected-databases*)))
            (change-class database 'closed-database)
            t)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;





(defun reconnect (&key (database *default-database*) (error nil) (force t))
  "Reconnects DATABASE to its underlying RDBMS. If successful, returns
t and the variable *default-database* is set to the newly reconnected
database. The default value for DATABASE is *default-database*. If
DATABASE is a database object, then it is used directly. Otherwise,
the list of connected databases is searched to find one with database
as its connection specifications (see CONNECT). If no such database is
found, then if ERROR and DATABASE are both non-nil an error is
signaled, otherwise RECONNECT returns nil. FORCE controls whether an
error should be signaled if the existing database connection cannot be
closed. When non-nil (this is the default value) the connection is
closed without error checking. When FORCE is nil, an error is signaled
if the database connection has been lost."
  ;; TODO: just a placeholder
  (declare (ignore database error force)))


  
(defun status (&optional full)
  "The function STATUS prints status information to the standard
output, for the connected databases and initialized database types. If
full is T, detailed status information is printed. The default value
of full is NIL."
  (declare (ignore full))
  ;; TODO: table details if full is true?
  (flet ((get-data ()
           (let ((data '()))
             (dolist (db (connected-databases) data)
               (push (list (database-name db)
                           (string (database-type db))
                           (when (conn-pool db) "T" "NIL")
                           (format nil "~A" (length (database-list-tables db)))
                           (format nil "~A" (length (database-list-views db)))
                           (if (equal db *default-database*) "   *" ""))
                     data))))
         (compute-sizes (data)
           (mapcar #'(lambda (x) (apply #'max (mapcar #'length x)))
                   (apply #'mapcar (cons #'list data))))
         (print-separator (size)
           (format t "~&~A" (make-string size :initial-element #\-))))
    (let ((data (get-data)))
      (when data
        (let* ((titles (list "NAME" "TYPE" "POOLED" "TABLES" "VIEWS" "DEFAULT"))
               (sizes (compute-sizes (cons titles data)))
               (total-size (+ (apply #'+ sizes) (* 2 (1- (length titles)))))
               (control-string (format nil "~~&~~{~{~~~AA  ~}~~}" sizes)))
          (print-separator total-size)
          (format t control-string titles)
          (print-separator total-size)
          (dolist (d data) (format t control-string d))
          (print-separator total-size))))
    (values)))


(defmacro with-database ((db-var connection-spec &rest connect-args) &body body)
  "Evaluate the body in an environment, where `db-var' is bound to the
database connection given by `connection-spec' and `connect-args'.
The connection is automatically closed or released to the pool on exit from the body."
  (let ((result (gensym "result-")))
    (unless db-var (setf db-var '*default-database*))
    `(let ((,db-var (connect ,connection-spec ,@connect-args))
	   (,result nil))
      (unwind-protect
	   (let ((,db-var ,db-var))
	     (setf ,result (progn ,@body)))
	(disconnect :database ,db-var))
      ,result)))


(defmacro with-default-database ((database) &rest body)
  "Perform BODY with DATABASE bound as *default-database*."
  `(progv '(*default-database*)
       (list ,database)
     ,@body))