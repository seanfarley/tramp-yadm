;;; tramp-yadm.el --- TRAMP integration for yadm dotfiles -*- lexical-binding: t -*-

;; Copyright (C) 2022 Sean Farley

;; Author: Sean Farley
;; URL: https://github.com/seanfarley/tramp-yadm
;; Version: 0.1
;; Created: 2022-01-13
;; Package-Requires: ((emacs "26.1") (magit "3.0") (projectile "2.0"))
;; Keywords: extensions dotfiles tramp yadm

;;; License

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package wraps the yadm command-line program to provide integration via
;; TRAMP.

;;; Code:
(require 'cl-lib)
(require 'magit)
(require 'projectile)
(require 'tramp-sh)

(defconst tramp-yadm-method "yadm"
  "When this method name is used, forward all calls to yadm logic.")

;; copied from `tramp-sh' but changed the bare minimum
(defvar tramp-yadm-file-name-handler-alist
  (cl-copy-list tramp-sh-file-name-handler-alist))

;;;###autoload
(defun tramp-yadm-file-name-p (filename)
  "Check if it's a FILENAME for yadm."
  (and (tramp-tramp-file-p filename)
       (string= (tramp-file-name-method
                 (tramp-dissect-file-name filename))
                tramp-yadm-method)))

;;;###autoload
(defun tramp-yadm-file-name-handler (operation &rest args)
  "Invoke the yadm handler for OPERATION and ARGS.
First arg specifies the OPERATION, second arg is a list of
arguments to pass to the OPERATION."
  (if-let ((fn (assoc operation tramp-yadm-file-name-handler-alist)))
      (save-match-data (apply (cdr fn) args))
    (tramp-run-real-handler operation args)))

;;;###autoload
(defun tramp-yadm-handle-expand-file-name (name &optional dir)
  "Like `tramp-sh-handle-expand-file-name' for yadm file NAME.

Since yadm has a non-default GIT_DIR, we need to map it back to .git."
  (if (and (> (length dir) 0)
           (string= name ".git")
           (string= (getenv "HOME") (tramp-file-name-localname
                                     (tramp-dissect-file-name
                                      (directory-file-name
                                       (expand-file-name dir))))))
      (expand-file-name "/yadm::~/.local/share/yadm/repo.git")
    (tramp-sh-handle-expand-file-name name dir)))

;;;###autoload
(defun tramp-yadm-handle-expand-file-nam2 (name &optional dir)
  "Like `tramp-sh-handle-expand-file-name' for yadm file NAME.

Since yadm has a non-default GIT_DIR, we need to map it back to .git."
  (if (and (> (length dir) 0)
           (string= name ".git")
           (string= (getenv "HOME") (tramp-file-name-localname
                                     (tramp-dissect-file-name
                                      (directory-file-name
                                       (expand-file-name dir))))))
      (expand-file-name "/yadm::~/.local/share/yadm/repo.git")))

;;;###autoload
(defun tramp-yadm-handle-shell-command (command &optional
                                                output-buffer
                                                error-buffer)
  "Like `shell-command' for yadm.

This only exists to intercept the `projectile-git-command'
COMMAND and remove '-o' from the arguments.

Accepts OUTPUT-BUFFER and ERROR-BUFFER for compatibility with
`shell-command'."
  (let ((command (if (string= command projectile-git-command)
                     "git ls-files -zc --exclude-standard"
                   command)))
    (tramp-handle-shell-command command output-buffer error-buffer)))

;;;###autoload
(defun tramp-yadm-magit-list-files (orig-fn &rest args)
  "Wrap `magit-list-files' ORIG-FN with ARGS.

Only exists to prevent untracked files (recursively lists home
directory) from being listed."
  (unless (and (string-prefix-p "/yadm:" default-directory)
               (member "--other" args))
    (apply orig-fn args)))

(add-to-list 'tramp-methods
             `(,tramp-yadm-method
               (tramp-login-program "yadm")
               (tramp-login-args (("enter")))
               (tramp-remote-shell "/bin/sh")
               (tramp-remote-shell-args ("-c"))))


(add-to-list 'tramp-yadm-file-name-handler-alist
             '(expand-file-name . tramp-yadm-handle-expand-file-name))

(add-to-list 'tramp-yadm-file-name-handler-alist
             '(shell-command . tramp-yadm-handle-shell-command))

(tramp-register-foreign-file-name-handler
 #'tramp-yadm-file-name-p #'tramp-yadm-file-name-handler)

;;;###autoload
(defun tramp-yadm-register ()
  "Initialize and advise `magit'."
  (advice-add #'magit-list-files
              :around
              #'tramp-yadm-magit-list-files))

(provide 'tramp-yadm)
;;; tramp-yadm.el ends here
