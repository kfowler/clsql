;;;; -*- Mode: LISP; Syntax: ANSI-Common-Lisp; Base: 10 -*-
;;;; *************************************************************************
;;;; FILE IDENTIFICATION
;;;;
;;;; Name:          clsql-aodbc.asd
;;;; Purpose:       ASDF definition file for CLSQL AODBC backend
;;;; Programmer:    Kevin M. Rosenberg
;;;; Date Started:  Aug 2002
;;;;
;;;; $Id: clsql-aodbc.asd,v 1.6 2002/09/17 17:16:43 kevin Exp $
;;;;
;;;; This file, part of CLSQL, is Copyright (c) 2002 by Kevin M. Rosenberg
;;;;
;;;; CLSQL users are granted the rights to distribute and use this software
;;;; as governed by the terms of the Lisp Lesser GNU Public License
;;;; (http://opensource.franz.com/preamble.html), also known as the LLGPL.
;;;; *************************************************************************

(in-package :asdf)

(defsystem :clsql-aodbc
    :components
    ((:module :clsql-aodbc
	      :components
	      ((:file "aodbc-package")
	       (:file "aodbc-sql" :depends-on ("aodbc-package")))))
    :depends-on (:clsql-base))

(defmethod source-file-type  ((c cl-source-file)
			      (s (eql (find-system 'clsql-aodbc)))) 
   "cl")
