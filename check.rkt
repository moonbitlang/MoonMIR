#!/usr/bin/env racket
#lang racket

(require racket/system)
(require racket/port)
(require racket/string)

;; Helper function to run a command and capture its output
(define (run-command-capture cmd)
  (let ([output-port (open-output-string)])
    (parameterize ([current-output-port output-port]
                   [current-error-port output-port])
      (let ([success (system cmd)])
        (if success
            (get-output-string output-port)
            (error (format "Command failed: ~a\nOutput: ~a" 
                          cmd 
                          (get-output-string output-port))))))))

;; Helper function to run a command without capturing output (for compilation steps)
(define (run-command cmd)
  (unless (system cmd)
    (error (format "Command failed: ~a" cmd))))

;; Main function to check a file
(define (check-file file)
  (printf "Testing ~a.c...\n" file)
  
  ;; Step 1: Compile with mbtcc to assembly
  (printf "  Compiling with mbtcc to assembly...\n")
  (run-command (format "moon run mbtcc -- --file ~a.c -o ~a.s" file file))
  
  ;; Step 2: Compile assembly with riscv64-unknown-elf-gcc
  (printf "  Compiling assembly with riscv64-unknown-elf-gcc...\n")
  (run-command (format "riscv64-unknown-elf-gcc -o ~a ~a.s runtime.c" file file))
  
  ;; Step 3: Run with spike and capture output
  (printf "  Running with spike...\n")
  (define spike-output 
    (string-trim (run-command-capture (format "spike pk ~a" file))))
  
  ;; Step 4: Compile with clang
  (printf "  Compiling with clang...\n")
  (run-command (format "clang ~a.c runtime.c -o ~a" file file))
  
  ;; Step 5: Run clang-compiled version and capture output
  (printf "  Running clang-compiled version...\n")
  (define clang-output 
    (string-trim (run-command-capture (format "./~a" file))))
  
  ;; Step 6: Compare outputs
  (cond
    [(equal? spike-output clang-output)
     (printf "~a.c Test Result: Passed\n" file)]
    [else
     ;; Outputs don't match, compile with LLVM IR
     (printf "  Outputs differ, testing with LLVM IR...\n")
     
     ;; Compile to LLVM IR
     (printf "  Compiling with mbtcc to LLVM IR...\n")
     (run-command (format "moon run mbtcc -- --file ~a.c -o ~a.ll -emit-llvm" file file))
     
     ;; Compile LLVM IR with clang
     (printf "  Compiling LLVM IR with clang...\n")
     (run-command (format "clang ~a.ll runtime.c -o ~a" file file))
     
     ;; Run LLVM IR version and capture output
     (printf "  Running LLVM IR version...\n")
     (define llvm-output 
       (string-trim (run-command-capture (format "./~a" file))))
     
     ;; Compare LLVM output with clang output
     (if (equal? llvm-output clang-output)
         (printf "~a.c Test Result: Failed, Problem happened in MoonMIR\n" file)
         (printf "~a.c Test Result: Failed, Problem happened in mbtcc\n" file))])
     ; delete .s, .ll, and executable files
     (run-command (format "rm -f ~a.s ~a.ll ~a" file file file)))

;; Main entry point
(define (main)
  (let ([args (current-command-line-arguments)])
    (cond
      [(= (vector-length args) 0)
       (fprintf (current-error-port) "Usage: racket check.rkt <file>\n")
       (fprintf (current-error-port) "  where <file> is the base filename without .c extension\n")
       (exit 1)]
      [else
       (let ([file (vector-ref args 0)])
         (with-handlers ([exn:fail? 
                          (λ (e) 
                            (fprintf (current-error-port) "Error: ~a\n" (exn-message e))
                            (exit 1))])
           (check-file file)))])))

;; Run main
(main)
