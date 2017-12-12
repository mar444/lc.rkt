#lang racket

(require test-engine/racket-tests)
(require "token.rkt")
(require "lexer.rkt")
(require "parser.rkt")

(define (reduce ast)
  (cond ((application? ast)
         (let ((lhs (application-lhs ast))
               (rhs (application-rhs ast)))
           (cond ((abstraction? lhs)
                  (subst (abstraction-body lhs) (abstraction-param lhs) rhs))
                 ((application? lhs)
                  (make-application (reduce lhs) rhs))
                 ((application? rhs)
                  (make-application lhs (reduce rhs)))
                 (else ast))))
        ((abstraction? ast)
         (make-abstraction (abstraction-param ast) (reduce (abstraction-body ast))))
        (else ast)))


(define (subst e v e1)
  (cond ((identifier? e)
         (if (equal? (identifier-value e) (identifier-value v)) e1 e))
        ((application? e)
         (make-application (subst (application-lhs e) v e1)
                           (subst (application-rhs e) v e1)))
        ((abstraction? e)
         (let ((param (abstraction-param e))
               (body (abstraction-body e))
               (fve (map identifier-value (freevars e)))
               (fve1 (map identifier-value (freevars e1))))
           (cond ((equal? (identifier-value param) (identifier-value v)) e)
                 ((not (member (identifier-value param) fve1))
                  (make-abstraction param (subst body v e1)))
                 (else
                  (letrec ((gen-new-param
                            (lambda (old-param)
                              (let ((new-param (symbol->string (gensym (identifier-value old-param)))))
                                (if (member new-param (list-union fve fve1))
                                    (gen-new-param param)
                                    (let ((tempe (subst body old-param (make-identifier new-param))))
                                      (make-abstraction (make-identifier new-param) (subst tempe v e1))))))))
                    (gen-new-param param)))))) 
        (else e)))


(define (freevars e)
  (cond ((identifier? e) (list e))
        ((application? e)
         (list-union (freevars (application-lhs e)) (freevars (application-rhs e))))
        ((abstraction? e)
         (remove (abstraction-param e) (freevars (abstraction-body e))))
        (else e)))


(define (print-reduce-result str)
  (let ((result (reduce (parse (lexer str)))))
    (print (ast-node->string result))))

(define (ast-node->string node)
  (cond ((identifier? node)
         (string-append (identifier-value node)))
        ((abstraction? node)
         (string-append "(λ" (identifier-value (abstraction-param node)) "." (ast-node->string (abstraction-body node)) ")"))
        ((application? node)
         (string-append "(" (ast-node->string (application-lhs node))  " " (ast-node->string (application-rhs node)) ")"))
        (else node)))


(define (reduce-str exp)
  (reduce (parse (lexer exp))))

         
(define (ans exp)
  (ast-node->string
   (if (string? exp)
       (reduce-str exp)
       exp)))


;; helper functions
(define (list-union l1 l2)
  (remove-duplicates (append l1 l2)))

;; tests


(check-expect (ans "x") (ans (make-identifier "x")))
(check-expect (ans "\\x.x") (ans (make-abstraction (make-identifier "x") (make-identifier "x"))))
(check-expect (ans "(\\x.x) y") (ans (make-identifier "y")))


(test)