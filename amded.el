;;; amded.el --- Interface to music tagging application amded  -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Valeriy Litkovskyy

;; Author: Valeriy Litkovskyy <vlr.ltkvsk@protonmail.com>
;; URL: https://github.com/xFA25E/amded
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: multimedia

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
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

;; This package allows music files to be easily tagged in a convenient widget
;; buffer using amded program.

;;;; Installation

;;;;; Package manager

;; If you've installed it with your package manager, you're done.  `amded' is
;; autoloaded, so you can call it right away.

;;;;; Manual

;; Put this file in your load-path, and put the following in your init file:

;; (require 'amded)

;;;; Usage

;; Open Dired buffer, put cursor on music files (or mark them) and run `amded'.
;; A new buffer with widgets should pop-up.

;; For now, only Dired and Mpc modes are supported, but amded can be easily
;; extended using `amded-files-functions'.  Just provide a function which
;; returns a list of absolute file-names and amded will take care of the rest.

;;;; Tips

;; + The user is encouraged to customize `amded-editable-tags'.  Amded can set a
;;   lot of tags, but, almost certainly, you don't care about most of them.

;;;;; Bulk editing

;; + `amded-set' sets the same value for a tag in every widget.

;; + `amded-set-incremental-number' takes a numeric tag
;;   (`amded-editable-numeric-tags') and a number to start from.  It sets the
;;   tag value in every widget incrementing it.  Used for setting track numbers.

;; + `amded-set-from-template' to set tags from `amded-template-regexp'.  Tag
;;   values are taken from numeric groups of regexp.  You can customize it, of
;;   course.  See its docstring.  If you need to support other tags in template,
;;   you can customize `amded-template-regexp-groups'.

;;;; Credits

;; This package would not have been possible without the excellent amded[1]
;; program and, of course, taglib[2].

;;  [1] https://github.com/ft/amded
;;  [2] https://taglib.org

;;; Code:

;;;; Requirements

(require 'cus-edit)
(require 'map)
(require 'subr-x)

;;;; Customization

(defgroup amded nil
  "Settings for `amded'."
  :link '(url-link "https://github.com/xFA25E/amded")
  :group 'multimedia
  :group 'applications)

(defcustom amded-buffer-name "*Amded*"
  "Amded buffer name."
  :type 'string
  :group 'amded)

(defcustom amded-program (executable-find "amded")
  "Amded executable."
  :type 'string
  :group 'amded)

(defcustom amded-editable-numeric-tags (list "track-number" "year")
  "Editable audio tags that must be numeric.
See `amded-editable-tags'."
  :type '(repeat string)
  :group 'amded
  :set (lambda (symbol value)
         (set symbol value)
         (when (and (boundp 'amded-editable-tags)
                    (fboundp 'amded--define-widget))
           (amded--define-widget))))

(defcustom amded-editable-tags (process-lines amded-program "-s" "tags")
  "Editable audio tags.
Run \"`amded-program' -s tags\" to see supported tags."
  :type '(repeat string)
  :group 'amded
  :set (lambda (symbol value)
         (set symbol value)
         (when (fboundp 'amded--define-widget)
           (amded--define-widget))))

(defcustom amded-files-functions
  '((dired-mode . dired-get-marked-files)
    (mpc-mode . amded-mpc-selected-files))
  "File-name returning functions.
Has a form of ((MAJOR-MODE . FUNCTION)...).  Each FUNCTION should
return a list of absolute filenames."
  :type '(alist (cons symbol function))
  :group 'amded)

(defcustom amded-template-regexp-groups
  '(("genre" . 1)
    ("artist" . 2)
    ("year" . 3)
    ("album" . 4)
    ("track-number" . 5)
    ("track-title" . 6))
  "Template regexp groups associated with tags.
See `amded-template-regexp'."
  :type '(alist :key-type (string :tag "Tag")
                :value-type (integer :tag "Regexp group"))
  :group 'amded)

(defcustom amded-template-regexp
  (rx-let ((sep (or " - " "/"))
           (ext (seq "." (+ (not ".")) eos))
           (text
            (seq
             ;; start with not space or slash
             (not (in " /"))
             ;; end with any number of
             (* (or
                 ;; not space or slash
                 (not (in " /"))
                 (seq
                  ;; or one or more spaces followed by
                  (+ " ")
                  (or
                   ;; not space, slash or dash
                   (not (in " /-"))
                   (seq
                    ;; or a dash followed by
                    "-"
                    ;; one or more not space or slash
                    (+ (not (in " /"))))))))))
           (tag-num (n) (group-n n (+? num)))
           (tag-text (n) (group-n n text)))
    (rx "/home/" (+ (not "/")) "/Music/"
        (tag-text 1) "/"
        (opt (tag-text 2) sep)
        (opt (opt (tag-num 3) " - ")
             (tag-text 4) sep
             (opt (tag-num 5) " - "))
        (tag-text 6) ext))
  "A regexp used it `amded-set-from-template'.
It is matched against full file name and various parts are taken
from explicit regexp groups from `amded-template-regexp-groups'.

See definition for an example."
  :type 'regexp
  :group 'amded)

;;;; Variables

(defvar-local amded--widgets nil
  "Buffer-local variable containing amded widgets in a buffer.")

;;;;; Keymaps

(easy-mmode-defmap amded-mode-map
  '(("s" . amded-set)
    ("n" . amded-set-incremental-number)
    ("T" . amded-set-from-template)
    ("\C-x\C-s" . amded-save)
    ("q" . quit-window))
  "Amded mode map."
  :inherit widget-keymap)

;;;; Commands

(define-derived-mode amded-mode fundamental-mode "Amded"
  "Major mode to edit audio tags data."
  :group 'amded
  :interactive nil
  (with-silent-modifications (erase-buffer) (remove-overlays)))

;;;###autoload
(defun amded (&rest files)
  "Edit audio FILES tags."
  (interactive (amded-files))
  (let* ((files-tags (apply #'amded-read files))
         (files (map-keys files-tags)))
    (with-current-buffer (get-buffer-create amded-buffer-name)
      (amded-mode)
      (pcase-dolist (`(,file . ,tags) files-tags)
        (push (widget-create 'amded :tag file :file file :value tags)
              amded--widgets)
        (widget-insert "\n")
        (widget-create 'push-button :notify #'amded--save-button-push
                       :files (list file) "Save")
        (widget-insert " ")
        (widget-create 'push-button :notify #'amded--save-button-push
                       :files files "Save all")
        (widget-insert "\n\n"))
      (setq-local amded--widgets (nreverse amded--widgets))
      (widget-setup)
      (set-buffer-modified-p nil)
      (goto-char (point-min))
      (pop-to-buffer (current-buffer)))))

(defun amded-save (&optional predicate)
  "Save all tags of `amded--widgets' that match PREDICATE.
If PREDICATE is omitted or nil, save all."
  (interactive nil amded-mode)
  (let ((predicate (or predicate #'always))
        (files-tags nil))
    (seq-doseq (widget amded--widgets)
      (when (funcall predicate widget)
        (push (cons (widget-get widget :file) (widget-value widget)) files-tags)))
    (apply #'amded-write files-tags)
    (set-buffer-modified-p nil)))

(defun amded-set (tag value)
  "Set VALUE to TAG in all widgets in a buffer."
  (interactive
   (let* ((widget (amded--nearest-field-widget))
          (defaults (widget-value (widget-get widget :parent)))
          (default-tag (car defaults))
          (tag-prompt (format-prompt "Tag" default-tag))
          (tag (completing-read tag-prompt amded-editable-tags nil t nil nil
                                default-tag))
          (default-value (when (string= default-tag tag) (cdr defaults)))
          (value-prompt (format-prompt "Value" default-value))
          (read-function (if (not (amded-numeric-tag-p tag))
                             (lambda ()
                               (read-string value-prompt nil nil default-value))
                           (lambda () (read-number "Value: " default-value)))))
     (list tag (funcall read-function)))
   amded-mode)

  (when (and (amded-numeric-tag-p tag) (not (integerp value)))
    (error "Tag \"%s\" value must be an integer, got %S" tag value))

  (save-excursion
    (seq-doseq (widget amded--widgets)
      (seq-doseq (child (widget-get widget :children))
        (seq-let (tag-widget value-widget) (widget-get child :children)
          (when (string= tag (widget-value tag-widget))
            (widget-value-set value-widget value)))))))

(defun amded-set-incremental-number (tag start)
  "Set numbers incrementally to TAG in widgets.
START should be a number from which to begin counting."
  (interactive
   (let ((tag (completing-read "Tag: " amded-editable-numeric-tags nil t)))
     (list tag (read-number "Start: ")))
   amded-mode)

  (unless (and (amded-numeric-tag-p tag) (integerp start))
    (error "Tag \"%s\" value must be an integer, got %S" tag start))

  (cl-decf start)
  (save-excursion
    (seq-doseq (widget amded--widgets)
      (seq-doseq (child (widget-get widget :children))
        (seq-let (tag-widget value-widget) (widget-get child :children)
          (when (string= tag (widget-value tag-widget))
            (widget-value-set value-widget (cl-incf start))))))))

(defun amded-set-from-template ()
  "Set tag values from `amded-template-regexp'."
  (interactive nil amded-mode)
  (save-excursion
    (seq-doseq (widget amded--widgets)
      (let ((file (widget-get widget :file)))
        (save-match-data
          (string-match amded-template-regexp file)
          (seq-doseq (child (widget-get widget :children))
            (seq-let (tag-widget value-widget) (widget-get child :children)
              (let ((tag (widget-value tag-widget)))
                (when-let ((group (assoc tag amded-template-regexp-groups))
                           (value (match-string (cdr group) file)))
                  (widget-value-set value-widget (if (amded-numeric-tag-p tag)
                                                     (string-to-number value)
                                                   value)))))))))))

;;;; Functions

;;;;; Public

(defun amded-files ()
  "List audio files suitable for `major-mode'.
See `amded-files-functions'"
  (cl-flet (( suitable-function-p ((mode . function))
              (when (derived-mode-p mode)
                function)))
    (if-let ((function (seq-some #'suitable-function-p amded-files-functions)))
        (funcall function)
      (error "No suitable function defined, see `%s'" 'amded-files-functions))))

(defun amded-read (&rest files)
  "List FILES tags.
Get an alist in the following form: ((FILE (TAG . VALUE)...)...)"
  (with-temp-buffer
    (apply #'call-process amded-program nil '(t nil) nil
           "-o" "json-dont-use-base64" "-j" files)
    (goto-char (point-min))
    (map-apply
     (lambda (file tags)
       (let ((editable-tags nil))
         (seq-doseq (tag amded-editable-tags)
           (let ((value (map-elt tags tag (if (amded-numeric-tag-p tag) 0 ""))))
             (push (cons tag value) editable-tags)))
         (cons file (nreverse editable-tags))))
     (json-parse-buffer))))

(defun amded-write (&rest files-tags)
  "Set audio tags for files.
FILES-TAGS is an alist like the one returned by `amded-read'."
  (with-temp-buffer
    (map-do
     (lambda (file tags)
       (let ((args (list file)))
         (pcase-dolist (`(,tag . ,value) tags)
           (when (integerp value)
             (setq value (number-to-string value)))
           (push (concat tag "=" value) args)
           (push "-t" args))
         (apply #'call-process amded-program nil t nil args)))
     files-tags)
    (let ((buffer-string (buffer-string)))
      (if (string-empty-p buffer-string)
          (message "Tags updated")
        (message "%s" buffer-string)))))

(defun amded-numeric-tag-p (tag)
  "Check whether TAG is a numeric audio tag."
  (member tag amded-editable-numeric-tags))

(defvar mpc-mpd-music-directory)
(declare-function mpc-songs-selection "mpc")
(defun amded-mpc-selected-files ()
  "Get selected files in mpc."
  (mapcar (lambda (f) (expand-file-name (car f) mpc-mpd-music-directory))
          (mpc-songs-selection)))

;;;;; Private

(defun amded--define-widget ()
  "Define amded widget.
Widget definition depends on `amded-editable-tags' and
`amded-editable-numeric-tags'."
  (define-widget 'amded 'group
    "Tags widget."
    :tag "%Failed to set tag%"
    :format "%t:\n%v"
    :greedy t
    :args (seq-map
           (lambda (tag)
             (let ((tag-tag (custom-unlispify-tag-name (make-symbol tag)))
                   (type (if (amded-numeric-tag-p tag) 'integer 'text)))
               `(cons :format "%v"
                      (const :format "" :value ,tag)
                      (,type :tag ,tag-tag))))
           amded-editable-tags)))

(defun amded--save-button-push (button-widget &rest _)
  "Set tags data associated with BUTTON-WIDGET."
  (let ((files (widget-get button-widget :files)))
    (amded-save (lambda (widget) (member (widget-get widget :file) files)))))

(defun amded--nearest-field-widget ()
  "Find nearest field widget."
  (or (widget-field-at (point))
      (save-excursion
        (let ((pt (point)))
          (widget-forward 1)
          (when (< pt (point))
            (widget-field-at (point)))))
      (save-excursion
        (widget-backward 1)
        (widget-field-at (point)))
      (save-excursion
        (widget-backward 2)
        (widget-field-at (point)))
      (save-excursion
        (widget-backward 3)
        (widget-field-at (point)))))

(defun amded--completion-predicate (_fn buffer)
  "Check `amded' command can run in the current BUFFER."
  (apply #'provided-mode-derived-p
         (buffer-local-value 'major-mode buffer)
         (mapcar #'car amded-files-functions)))

;;;; Footer

;; Put completion predicate only when the package is loaded, since amded command
;; is autoloaded and requires more dependencies.
(function-put 'amded 'completion-predicate #'amded--completion-predicate)

(amded--define-widget)

(provide 'amded)

;;; amded.el ends here
