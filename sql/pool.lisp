;;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;; FILE IDENTIFICATION
;;;;
;;;; Name:          pool.cl
;;;; Purpose:       Support function for connection pool
;;;; Programmers:   Kevin M. Rosenberg, Marc Battyani
;;;; Date Started:  Apr 2002
;;;;
;;;; $Id: pool.lisp,v 1.1 2002/09/30 10:19:23 kevin Exp $
;;;;
;;;; This file, part of CLSQL, is Copyright (c) 2002 by Kevin M. Rosenberg
;;;;
;;;; CLSQL users are granted the rights to distribute and use this software
;;;; as governed by the terms of the Lisp Lesser GNU Public License
;;;; (http://opensource.franz.com/preamble.html), also known as the LLGPL.
;;;; *************************************************************************

(declaim (optimize (debug 3) (speed 3) (safety 1) (compilation-speed 0)))
(in-package :clsql-sys)

(defvar *db-pool* (make-hash-table :test #'equal))

(defclass conn-pool ()
  ((connection-spec :accessor connection-spec :initarg :connection-spec)
   (database-type :accessor database-type :initarg :database-type)
   (free-connections :accessor free-connections
		     :initform (make-array 5 :fill-pointer 0 :adjustable t))
   (all-connections :accessor all-connections
		    :initform (make-array 5 :fill-pointer 0 :adjustable t))))

(defun acquire-from-conn-pool (pool)
  (if (zerop (length (free-connections pool)))
    (let ((conn (connect (connection-spec pool)
			 :database-type (database-type pool) :if-exists :new)))
      (vector-push-extend conn (all-connections pool))
      (setf (conn-pool conn) pool)
      conn)
    (vector-pop (free-connections pool))))

(defun release-to-conn-pool (conn)
  (vector-push-extend conn (free-connections (conn-pool conn))))

(defun clear-conn-pool (pool)
  (loop for conn across (all-connections pool)
	do (setf (conn-pool conn) nil)
	   (disconnect :database conn))
  (setf (fill-pointer (free-connections pool)) 0)
  (setf (fill-pointer (all-connections pool)) 0))

(defun find-or-create-connection-pool (connection-spec database-type)
  "Find connection pool in hash table, creates a new connection pool if not found"
  (let* ((key (list connection-spec database-type))
	 (conn-pool (gethash key *db-pool*)))
    (unless conn-pool
      (setq conn-pool (make-instance 'conn-pool
				     :connection-spec connection-spec
				     :database-type database-type))
      (setf (gethash key *db-pool*) conn-pool))
    conn-pool))

(defun acquire-from-pool (connection-spec database-type &optional pool)
  (unless (typep pool 'conn-pool)
    (setf pool (find-or-create-connection-pool connection-spec database-type)))
  (acquire-from-conn-pool pool))

(defun release-to-pool (database)
  (release-to-conn-pool database))

(defun disconnect-pooled (&optional clear)
  "Disconnects all connections in the pool"
  (maphash
   #'(lambda (key conn-pool)
       (declare (ignore key))
       (clear-conn-pool conn-pool))
   *db-pool*)
  (when clear (clrhash *db-pool*))
  t)
