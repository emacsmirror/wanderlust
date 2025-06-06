;;; rfc2368.el --- support for rfc2368  -*- lexical-binding: t -*-

;; Author: Sen Nagata <sen@eccosys.com>
;; Keywords: mail

;; Copyright (C) 1998, 2000 Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; notes:
;;
;;   -repeat after me: "the colon is not part of the header name..."
;;   -if w3 becomes part of emacs, then it may make sense to have this
;;    file depend on w3 -- the maintainer of w3 says merging w/ Emacs
;;    is planned!
;;
;; historical note:
;;
;;   this is intended as a replacement for mailto.el
;;
;; acknowledgements:
;;
;;   the functions that deal w/ unhexifying in this file were basically
;; taken from w3 -- i hope to replace them w/ something else soon OR
;; perhaps if w3 becomes a part of emacs soon, use the functions from w3.

;;; History:
;;
;; 0.3:
;;
;;  added the constant rfc2368-version
;;  implemented first potential fix for a bug in rfc2368-mailto-regexp
;;  implemented first potential fix for a bug in rfc2368-parse-mailto
;;  (both bugs reported by Kenichi OKADA)
;;
;; 0.2:
;;
;;  started to use checkdoc
;;
;; 0.1:
;;
;;  initial implementation

;;; Code:

;; only an approximation?
;; see rfc 1738
(defconst rfc2368-mailto-regexp
  "^\\(mailto:\\)\\([^?]+\\)*\\(\\?\\(.*\\)\\)*"
  "Regular expression to match and aid in parsing a mailto url.")

;; describes 'mailto:'
(defconst rfc2368-mailto-scheme-index 1
  "Describes the \\='mailto:\\=' portion of the url.")
;; i'm going to call this part the 'prequery'
(defconst rfc2368-mailto-prequery-index 2
  "Describes the portion of the url between \\='mailto:\\=' and '?'.")
;; i'm going to call this part the 'query'
(defconst rfc2368-mailto-query-index 4
  "Describes the portion of the url after \\='?\\='.")

(defun rfc2368-unhexify-string (string)
  "Unhexify STRING -- e.g. \\='hello%20there\\=' -> \\='hello there\\='."
  (let ((start 0)
	(buf))
    (while (string-match "+\\|%\\(0D%0A\\|\\([0-9a-fA-F][0-9a-fA-F]\\)\\)"
			 string start)
      (push (substring string start (match-beginning 0)) buf)
      (push (cond
	     ((match-beginning 2)
	      (vector (string-to-number (match-string 2 string) 16)))
	     ((match-beginning 1) "\n")
	     (t " "))
	    buf)
      (setq start (match-end 0)))
    (apply 'concat (nreverse (cons (substring string start) buf)))))

(defun rfc2368-parse-mailto-url (mailto-url)
  "Parse MAILTO-URL, and return an alist of header-name, header-value pairs.
MAILTO-URL should be a RFC 2368 (mailto) compliant url.  A cons cell w/ a
key of \\='Body\\=' is a special case and is considered a header for this purpose.
The returned alist is intended for use w/ the `compose-mail' interface.
Note: make sure MAILTO-URL has been \\='unhtmlized\\=' (e.g. &amp; -> &), before
calling this function."
  (let ((case-fold-search t)
	prequery query headers-alist)
    ;; Remove newline
    (setq mailto-url
	  (with-temp-buffer
	    (insert mailto-url)
	    (goto-char (point-min))
	    (while (re-search-forward "\n" nil t)
	      (replace-match ""))
	    (buffer-string)))
    (if (string-match rfc2368-mailto-regexp mailto-url)
	(progn

	  (setq prequery
		(match-string rfc2368-mailto-prequery-index mailto-url))

	  (setq query
		(match-string rfc2368-mailto-query-index mailto-url))

	  ;; build alist of header name-value pairs
	  (if (not (null query))
	      (setq headers-alist
		    (mapcar
		     (lambda (x)
		       (let* ((temp-list (split-string x "="))
			      (header-name (car temp-list))
			      (header-value (cadr temp-list)))
			 ;; return ("Header-Name" . "header-value")
			 (cons
			  (capitalize (rfc2368-unhexify-string header-name))
			  (rfc2368-unhexify-string header-value))))
		     (split-string query "&"))))

	  ;; deal w/ multiple 'To' recipients
	  (if prequery
	      (progn
		(setq prequery (rfc2368-unhexify-string prequery))
		(if (assoc "To" headers-alist)
		    (let* ((our-cons-cell
			    (assoc "To" headers-alist))
			   (our-cdr
			    (cdr our-cons-cell)))
		      (setcdr our-cons-cell (concat prequery ", " our-cdr)))
		  (setq headers-alist
			(cons (cons "To" prequery) headers-alist)))))

	  headers-alist)

      (error "Failed to match a mailto: url"))
    ))

(provide 'rfc2368)

;;; rfc2368.el ends here
