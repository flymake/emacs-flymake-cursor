;;; flymake-cursor.el --- displays flymake error msg in minibuffer after delay
;;
;; Author     : ??
;; origin     : http://paste.lisp.org/display/60617,1/raw
;; Maintainer : Dino Chiesa <dpchiesa@hotmail.com>
;; Created    : May 2011
;; Modified   : May 2011
;; Version    : 0.1.1
;; Keywords   : languages mode flymake
;; X-URL      : http://www.emacswiki.org/emacs/flymake-cursor.el
;; Last-saved : <2011-May-09 16:35:59>
;;
;; -------------------------------------------------------
;;
;; License: None.  This code is in the Public Domain.
;;
;;
;; Additional functionality that makes flymake error messages appear
;; in the minibuffer when point is on a line containing a flymake
;; error. This saves having to mouse over the error, which is a
;; keyboard user's annoyance.
;;
;; -------------------------------------------------------
;;
;; This flymake-cursor module displays the flymake error in the
;; minibuffer, after a short delay.  It is based on code I found roaming
;; around on the net, unsigned and unattributed. I suppose it's public
;; domain, because, while there is a "License" listed in it, there
;; is no license holder, no one to own the license.
;;
;; This version is modified slightly from that code. The post-command fn
;; defined in this code does not display the message directly. Instead
;; it sets a timer, and when the timer fires, the timer event function
;; displays the message.
;;
;; The reason to do this: the error message is displayed only if the
;; user doesn't do anything, for about one second. This way, if the user
;; scrolls through a buffer and there are myriad errors, the minibuffer
;; is not constantly being updated.
;;
;; If the user moves away from the line with the flymake error message
;; before the timer expires, then no error is displayed in the minibuffer.
;;
;; I've also updated the names of the defuns. They all start with flyc now.
;;
;; To use this, include this line in your .emacs:
;;
;;    ;; enhancements for displaying flymake errors
;;    (require 'flymake-cursor)
;;
;; You can, of course, put that in an eval-after-load clause.
;;

(require 'flymake)

(defcustom flymake-cursor-error-display-delay 0.9
  "Delay in seconds to wait before displaying flymake errors for the current line."
  :group 'flymake-cursor
  :type 'number)

(defvar flymake-cursor-error-at-point nil
  "Error at point, after last command")

(defvar flymake-cursor-error-display-timer nil
  "A timer; when it fires, it displays the stored error message.")

(defun flymake-cursor-maybe-fixup-message (error)
  "pyflake is flakey if it has compile problems, this adjusts the
message to display, so there is one ;)"
  (cond ((not (or (eq major-mode 'Python) (eq major-mode 'python-mode) t)))
        ((null (flymake-ler-file error))
         ;; normal message do your thing
         (flymake-ler-text error))
        (t ;; could not compile error
         (format "compile error, problem on line %s" (flymake-ler-line error)))))


(defun flymake-cursor-show-stored-error-now ()
  "Displays the stored error in the minibuffer."
  (interactive)
  (when flymake-cursor-error-at-point
    (setq flymake-cursor-error-display-timer nil)
    ;;  Don't trash the minibuffer while they're being asked a question.
    (if (or (active-minibuffer-window)
            (and (current-message)
                 (string-match "(y or n)" (current-message))))
      (flymake-cursor-show-fly-error-at-point-pretty-soon)
      (message "%s" (flymake-cursor-maybe-fixup-message flymake-cursor-error-at-point))
      )
    )
  )


(defun flymake-cursor-get-error-at-point ()
  "Gets the first flymake error on the line at point."
  (let ((line-no (line-number-at-pos))
        flymake-cursor-error)
    (dolist (elem flymake-err-info)
      (if (eq (car elem) line-no)
          (setq flymake-cursor-error (car (second elem)))))
    flymake-cursor-error))


(defun flymake-cursor-show-fly-error-at-point-now ()
  "If the cursor is sitting on a flymake error, display
the error message in the minibuffer."
  (interactive)
  (when flymake-cursor-error-display-timer
    (cancel-timer flymake-cursor-error-display-timer)
    (setq flymake-cursor-error-display-timer nil))
  (let ((error-at-point (flymake-cursor-get-error-at-point)))
    (when error-at-point
      (setq flymake-cursor-error-at-point error-at-point)
      (flymake-cursor-show-stored-error-now))))



(defun flymake-cursor-show-fly-error-at-point-pretty-soon ()
  "If the cursor is sitting on a flymake error, grab the error,
and set a timer for \"pretty soon\". When the timer fires, the error
message will be displayed in the minibuffer.

The interval before the timer fires can be customized in the variable
`flymake-cursor-error-display-delay'.

This allows a post-command-hook to NOT cause the minibuffer to be
updated 10,000 times as a user scrolls through a buffer
quickly. Only when the user pauses on a line for more than a
second, does the flymake error message (if any) get displayed."
  (when flymake-cursor-error-display-timer
      (cancel-timer flymake-cursor-error-display-timer))

  (let ((error-at-point (flymake-cursor-get-error-at-point)))
    (if error-at-point
      (setq flymake-cursor-error-at-point error-at-point
            flymake-cursor-error-display-timer
              (run-at-time (concat (number-to-string flymake-cursor-error-display-delay) " sec") nil 'flymake-cursor-show-stored-error-now))
      (setq flymake-cursor-error-at-point nil
            flymake-cursor-error-display-timer nil))))



(eval-after-load "flymake"
  '(progn

     (defadvice flymake-goto-next-error (after flymake-cursor-display-message-1 activate compile)
       "Display the error in the mini-buffer rather than having to mouse over it"
       (flymake-cursor-show-fly-error-at-point-now))

     (defadvice flymake-goto-prev-error (after flymake-cursor-display-message-2 activate compile)
       "Display the error in the mini-buffer rather than having to mouse over it"
       (flymake-cursor-show-fly-error-at-point-now))

     (defadvice flymake-mode (before flymake-cursor-post-command-fn activate compile)
       "Add functionality to the post command hook so that if the
cursor is sitting on a flymake error the error information is
displayed in the minibuffer (rather than having to mouse over
it)"
       (set (make-local-variable 'post-command-hook)
            (cons 'flymake-cursor-show-fly-error-at-point-pretty-soon post-command-hook)))))


(provide 'flymake-cursor)
