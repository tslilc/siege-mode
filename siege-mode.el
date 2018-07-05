;;; Package --- Surround region with smart delimeters interactively
;; Time-stamp: <2018-07-05 21:19:22 (tslil)>

;; Copyright (c) 2018 tslil clingman

;; Author: tslil clingman <tslil@posteo.de>
;; Version: 1.0
;; Package-Requires: ((emacs "24.4"))
;; Keywords: region wrap

;;; License:

;; siege-mode is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 3, or (at your option) any later version.
;;
;; siege-mode is distributed in the hope that it will be useful, but WITHOUT ANY
;; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
;; A PARTICULAR PURPOSE. See the GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License along with
;; siege-mode. If not, see http://www.gnu.org/licenses.

;;; Commentary:

;; Lay siege to the region from all sides!
;; 
;; When the region is active, all input is redirected to the minibuffer and
;; treated as a delimeter for the region. By default the input is used as the
;; left delimeter from which the right one is derived using
;; `siege-left-to-right-regexs'. This may be reversed by default
;; (`siege-default-left') or during usage via "C-c r" in the minibuffer. If
;; regexes are not desired they may be disabled via "C-c a" in the minibuffer
;; or by default (`siege-default-apply-regexs').
;;
;; All changes are dynamically displayed in the buffer (see
;; `siege-preview-face') and may be committed by "SPC" or "Ret" in the
;; minibuffer.

;;; Code:
(require 'subr-x)

(defcustom siege-left-to-right-regexs '( ("(" . ")")
                                         ("\\[" . "]")
                                         ("{" . "}")
                                         ("<" . ">")
                                         ("`" . "'")
                                         ("``" . "''")
                                         ("left" . "right")
                                         ("langle" . "rangle")
                                         ("begin" . "end") )
  "List of pairs (REGEX . REPLACE) used to generate the RIGHT delimeter from \
the LEFT one. The list is traversed in order and every substitution is applied."
  :group 'siege-mode
  :type '(repeat (cons string string)))

(defcustom siege-right-to-left-regexs '( (")" . "(")
                                         ("\\]" . "[")
                                         ("}" . "{")
                                         (">" . "<")
                                         ("'" . "`")
                                         ("''" . "``")
                                         ("right" . "left")
                                         ("rangle" . "langle")
                                         ("end" . "begin") )
  "List of pairs (REGEX . REPLACE) used to generate the LEFT delimeter from \
the RIGHT one. The list is traversed in order and every substitution is applied."
  :group 'siege-mode
  :type '(repeat (cons string string)))

(defcustom siege-default-left t
  "Whether siege mode should default to deriving the right delimeter \
from the input."
  :group 'siege-mode
  :type 'bool)

(defcustom siege-default-apply-regexs t
  "Whether siege mode should default to deriving the matching delimeter \
from the input using the regexs given in `siege-right-to-left-regexs' \
and `siege-left-to-right-regexs'."
  :group 'siege-mode
  :type 'bool)


(defface siege-preview-face '((t :inherit (warning)))
  "Face in which to render delimeter previews for Siege mode."
  :group 'siege-mode)

(defvar siege--overlay nil)
(defvar siege--selected-window nil)
(defvar siege--apply-regexs t)
(defvar siege--is-left t)
(defvar siege--hist '())

(defun siege--toggle-end ()
  "Swap the side for which the input is considered a delimeter and \
from which the matching delimeter is derived, for \
the currently running instance. See also `siege-default-left'."
  (interactive)
  (setq siege--is-left (not siege--is-left))
  (minibuffer-message "Currently entering %s delimeter."
                      (if siege--is-left "LEFT" "RIGHT")))

(defun siege--toggle-regex ()
  "Toggle the use of regexs in deriving a matching delimeter for \
the currently running instance. See also `siege-default-apply-regexs'."
  (interactive)
  (setq siege--apply-regexs (not siege--apply-regexs))
  (minibuffer-message "%s regexs on input."
                      (if siege--apply-regexs "APPLYING" "NOT applying")))

(defun siege--matching-pair (input)
  "Generate a matching delimeter from INPUT using \
`siege-left-to-right-regexs' and `siege-right-to-left-regexs' \
according to \
`siege-default-left' and `siege-default-apply-regexs'"
  (if siege--apply-regexs
      (let ((pairs (if siege--is-left siege-left-to-right-regexs
                     siege-right-to-left-regexs))
            (output input))
        (cl-dolist (expr pairs)
          (setq output
                (replace-regexp-in-string (car expr) (cdr expr) output)))
        (if siege--is-left (cons input output)
          (cons output input)))
    (cons input input)))

(defun siege--preview-input ()
  "Render the siege delimeters in the buffer using overlays."
  (let ((inp (minibuffer-contents)))
    (if (string-blank-p inp)
        (siege--preview-end)
      (with-selected-window siege--selected-window
        (let ((beg (region-beginning))
              (end (region-end)))
          (if (overlayp siege--overlay)
              (move-overlay siege--overlay beg end)
            (setq siege--overlay (make-overlay beg end))
            (overlay-put siege--overlay 'sieging t))
          (let ((pair (siege--matching-pair inp)))
            (overlay-put siege--overlay 'before-string
                         (propertize (car pair)
                                     'face 'siege-preview-face))
            (overlay-put siege--overlay 'after-string
                         (propertize (cdr pair)
                                     'face 'siege-preview-face))))))))

(defun siege--preview-end ()
  "Gracefully remove the siege preview overlay."
  (with-selected-window siege--selected-window
    (remove-overlays (buffer-end -1) (buffer-end 1) 'sieging t)))

(defvar siege-minibuffer-map
  (let ((map minibuffer-local-ns-map))
    (define-key map (kbd "C-c r") 'siege--toggle-end)
    (define-key map (kbd "C-c a") 'siege--toggle-regex)
    map))

(defun siege--interactive (initial)
  "Use to enter the interactive delimeter building for region.

INITIAL is the string present in the minibuffer, which is not necessarily\
the default value."
  (barf-if-buffer-read-only)
  (setq siege--selected-window (selected-window)
        siege--is-left siege-default-left
        siege--apply-regexs siege-default-apply-regexs)
  (exchange-point-and-mark)
  (let* ((start (region-beginning))
         (end (region-end))
         (default (or (car siege--hist) ""))
         (result (minibuffer-with-setup-hook
                     (lambda ()
                       (add-hook 'post-command-hook #'siege--preview-input nil t)
                       (add-hook 'minibuffer-exit-hook #'siege--preview-end nil t)
                       (siege--preview-input))
                   (read-from-minibuffer (format "Enter delimeter (default %s): " default)
                                         initial siege-minibuffer-map
                                         nil 'siege--hist default)))
         (pair (siege--matching-pair result)))
    (siege--preview-end)
    (goto-char start)
    (insert (car pair))
    (goto-char (+ end (length (cdr pair))))
    (insert (cdr pair))))

(defun siege--self-insert (arg)
  "This function replaces `self-insert-command'.

When the region is active, all input is redirected to the minibuffer \
and treated as a delimeter for the region. By default the input \
is used as the left delimeter from which the right one is \
derived using `siege-left-to-right-regexs'. See also \
`siege-default-left' and `siege-right-to-left-regexs'. ARG is \
ignored.

If the region is not active then ARG is passed on to `self-insert-command'."
  (interactive "p")
  (if (and (region-active-p) (characterp last-command-event))
      (siege--interactive (char-to-string last-command-event))
    (self-insert-command arg)))

(defvar siege-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap self-insert-command] 'siege--self-insert)
    map))

(define-minor-mode siege-mode
  "Siege minor mode."
  nil
  " siege" siege-mode-map
  :global true)

(provide 'siege-mode)
;;; siege-mode.el ends here
