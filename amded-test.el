;;; amded-test.el --- Tests for amded                -*- lexical-binding: t; -*-

;; Copyright (C) 2023  Valeriy Litkovskyy

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Tests for amded

;;; Code:

(require 'amded)

(ert-deftest amded-test-template-regexp ()
  (pcase-dolist
      (`(,file . ,parts)
       '(;; title
         ("/home/user/Music/metal/Test Title.mp3"
          "metal" nil nil nil nil "Test Title")
         ;; artist title
         ("/home/user/Music/metal/Test Artist - Test Title.mp3"
          "metal" "Test Artist" nil nil nil "Test Title")
         ("/home/user/Music/metal/Test Artist/Test Title.mp3"
          "metal" "Test Artist" nil nil nil "Test Title")
         ;; artist album title
         ("/home/user/Music/metal/Test Artist - Test Album - Test Title.mp3"
          "metal" "Test Artist" nil "Test Album" nil "Test Title")
         ("/home/user/Music/metal/Test Artist - Test Album/Test Title.mp3"
          "metal" "Test Artist" nil "Test Album" nil "Test Title")
         ("/home/user/Music/metal/Test Artist/Test Album - Test Title.mp3"
          "metal" "Test Artist" nil "Test Album" nil "Test Title")
         ("/home/user/Music/metal/Test Artist/Test Album/Test Title.mp3"
          "metal" "Test Artist" nil "Test Album" nil "Test Title")
         ;; artist album track title
         ("/home/user/Music/metal/Test Artist - Test Album - 5 - Test Title.mp3"
          "metal" "Test Artist" nil "Test Album" "5" "Test Title")
         ("/home/user/Music/metal/Test Artist - Test Album/5 - Test Title.mp3"
          "metal" "Test Artist" nil "Test Album" "5" "Test Title")
         ("/home/user/Music/metal/Test Artist/Test Album - 5 - Test Title.mp3"
          "metal" "Test Artist" nil "Test Album" "5" "Test Title")
         ("/home/user/Music/metal/Test Artist/Test Album/5 - Test Title.mp3"
          "metal" "Test Artist" nil "Test Album" "5" "Test Title")
         ;; artist year album title
         ("/home/user/Music/metal/Test Artist - 2001 - Test Album - Test Title.mp3"
          "metal" "Test Artist" "2001" "Test Album" nil "Test Title")
         ("/home/user/Music/metal/Test Artist - 2001 - Test Album/Test Title.mp3"
          "metal" "Test Artist" "2001" "Test Album" nil "Test Title")
         ("/home/user/Music/metal/Test Artist/2001 - Test Album - Test Title.mp3"
          "metal" "Test Artist" "2001" "Test Album" nil "Test Title")
         ("/home/user/Music/metal/Test Artist/2001 - Test Album/Test Title.mp3"
          "metal" "Test Artist" "2001" "Test Album" nil "Test Title")
         ;; artist year album track title
         ("/home/user/Music/metal/Test Artist - 2001 - Test Album - 5 - Test Title.mp3"
          "metal" "Test Artist" "2001" "Test Album" "5" "Test Title")
         ("/home/user/Music/metal/Test Artist - 2001 - Test Album/5 - Test Title.mp3"
          "metal" "Test Artist" "2001" "Test Album" "5" "Test Title")
         ("/home/user/Music/metal/Test Artist/2001 - Test Album - 5 - Test Title.mp3"
          "metal" "Test Artist" "2001" "Test Album" "5" "Test Title")
         ("/home/user/Music/metal/Test Artist/2001 - Test Album/5 - Test Title.mp3"
          "metal" "Test Artist" "2001" "Test Album" "5" "Test Title")))
    (save-match-data
      (string-match amded-template-regexp file)
      (cl-loop for part in parts
               for i from 1
               do (should (equal part (match-string i file)))))))

(provide 'amded-test)
;;; amded-test.el ends here
