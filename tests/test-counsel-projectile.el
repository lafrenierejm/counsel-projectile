;;; test-counsel-projectile.el --- Tests for counsel-projectile.el -*- lexical-binding: t; -*-

;;; Commentary:

;; Buttercup specs for the pure helper functions in counsel-projectile.el:
;; `counsel-projectile--ignore-glob', `counsel-projectile--action-index',
;; and `counsel-projectile-modify-action'.  These are exercised directly,
;; without requiring a live Projectile project or an active Ivy session.

;;; Code:

(require 'counsel-projectile)

(describe "counsel-projectile--ignore-glob"
  (it "strips a leading slash"
    (expect (counsel-projectile--ignore-glob "/foo") :to-equal "foo"))

  (it "strips a leading **/ "
    (expect (counsel-projectile--ignore-glob "**/foo") :to-equal "foo"))

  (it "strips a trailing slash"
    (expect (counsel-projectile--ignore-glob "foo/") :to-equal "foo"))

  (it "strips both a leading slash and a trailing slash"
    (expect (counsel-projectile--ignore-glob "/foo/") :to-equal "foo"))

  (it "strips both a leading **/ and a trailing slash"
    (expect (counsel-projectile--ignore-glob "**/foo/bar/") :to-equal "foo/bar"))

  (it "leaves an unanchored pattern unchanged"
    (expect (counsel-projectile--ignore-glob "foo") :to-equal "foo")))

(describe "counsel-projectile--action-index"
  (let ((action-list '(1
                        ("o" ignore "Open")
                        ("d" identity "Delete")
                        ("r" always "Rename"))))

    (it "finds an action by its key"
      (expect (counsel-projectile--action-index "o" action-list) :to-equal 1)
      (expect (counsel-projectile--action-index "d" action-list) :to-equal 2)
      (expect (counsel-projectile--action-index "r" action-list) :to-equal 3))

    (it "finds an action by its name"
      (expect (counsel-projectile--action-index "Open" action-list) :to-equal 1)
      (expect (counsel-projectile--action-index "Delete" action-list) :to-equal 2))

    (it "finds an action by its function"
      (expect (counsel-projectile--action-index #'ignore action-list) :to-equal 1)
      (expect (counsel-projectile--action-index #'always action-list) :to-equal 3))

    (it "passes an in-range integer index through unchanged"
      (expect (counsel-projectile--action-index 2 action-list) :to-equal 2))

    (it "errors when the action item is not found"
      (expect (counsel-projectile--action-index "z" action-list) :to-throw 'error)
      (expect (counsel-projectile--action-index "Missing" action-list) :to-throw 'error)
      (expect (counsel-projectile--action-index #'ignore-errors action-list) :to-throw 'error))))

(describe "counsel-projectile-modify-action"
  (defvar counsel-projectile-test--actions)

  (before-each
    (setq counsel-projectile-test--actions
          '(1
            ("o" ignore "Open")
            ("d" identity "Delete")
            ("r" always "Rename"))))

  (it "removes an action by key"
    (counsel-projectile-modify-action 'counsel-projectile-test--actions '((remove "d")))
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("o" ignore "Open")
                        ("r" always "Rename"))))

  (it "adds an action before a target"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((add ("x" ignore-errors "Extra") "r")))
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("o" ignore "Open")
                        ("d" identity "Delete")
                        ("x" ignore-errors "Extra")
                        ("r" always "Rename"))))

  (it "adds an action at the end when no target is given"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((add ("x" ignore-errors "Extra"))))
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("o" ignore "Open")
                        ("d" identity "Delete")
                        ("r" always "Rename")
                        ("x" ignore-errors "Extra"))))

  (it "moves an action to the end when no target is given"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((move "o")))
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("d" identity "Delete")
                        ("r" always "Rename")
                        ("o" ignore "Open"))))

  (it "moves an action before a target"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((move "r" "o")))
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("r" always "Rename")
                        ("o" ignore "Open")
                        ("d" identity "Delete"))))

  (it "sets the key of an action"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((setkey "d" "D")))
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("o" ignore "Open")
                        ("D" identity "Delete")
                        ("r" always "Rename"))))

  (it "sets the function of an action"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((setfun "d" always)))
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("o" ignore "Open")
                        ("d" always "Delete")
                        ("r" always "Rename"))))

  (it "sets the name of an action"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((setname "d" "Trash")))
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("o" ignore "Open")
                        ("d" identity "Trash")
                        ("r" always "Rename"))))

  (it "sets the default action"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((default "r")))
    (expect (car counsel-projectile-test--actions) :to-equal 3))

  (it "applies several modifications in sequence"
    (counsel-projectile-modify-action
     'counsel-projectile-test--actions
     '((remove "d")
       (add ("x" ignore-errors "Extra"))
       (default "x")))
    (expect counsel-projectile-test--actions
            :to-equal '(3
                        ("o" ignore "Open")
                        ("r" always "Rename")
                        ("x" ignore-errors "Extra"))))

  (it "errors and leaves the variable untouched when a modification is invalid"
    (expect (counsel-projectile-modify-action
             'counsel-projectile-test--actions
             '((remove "missing")))
            :to-throw 'error)
    (expect counsel-projectile-test--actions
            :to-equal '(1
                        ("o" ignore "Open")
                        ("d" identity "Delete")
                        ("r" always "Rename"))))

  (it "errors when the action variable does not hold a list"
    (setq counsel-projectile-test--actions #'ignore)
    (expect (counsel-projectile-modify-action
             'counsel-projectile-test--actions
             '((default "o")))
            :to-throw 'error)))

;;; test-counsel-projectile.el ends here
