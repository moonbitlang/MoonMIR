#!/usr/bin/env racket
#lang racket

;; List of tests to run
(define tests '(simple_ret simple_add many_args if while while2 order_args for struct))

;; Executes a command and captures its standard output by redirecting to a temporary file.
(define (run-and-get-output cmd)
  (let ([tmp-file (make-temporary-file "racket-output~a.txt")])
    ;; Redirect stdout to the temp file. We also redirect stderr to stdout to capture it.
    (system (format "sh -c '~a' > ~a 2>&1" cmd tmp-file))
    (let ([output (file->string tmp-file)])
      (delete-file tmp-file)
      (string-trim output))))

;; Runs a single test case.
;; Returns #t on success and #f on failure.
(define (run-test test-name)
  (let ([file (symbol->string test-name)])
    (dynamic-wind
      (lambda () (void)) ; Before thunk
      (lambda () ; Main thunk: Run the test
        (printf "Testing ~a.c\n" file)

        ;; --- mbtcc path ---
        (displayln (format "  ~a" (format "Compiling with mbtcc: moon run mbtcc -- --file ctest/~a.c -o ~a.s" file file)))
        (system (format "moon run mbtcc -- --file ctest/~a.c -o ~a.s" file file))
        (displayln (format "  ~a" (format "Assembling with riscv64-unknown-elf-gcc: riscv64-unknown-elf-gcc -o ~a ~a.s runtime.c" file file)))
        (system (format "riscv64-unknown-elf-gcc -o ~a ~a.s runtime.c" file file))

        (let* (;; GCC step removed as requested.
               ;; Note: This will likely cause the subsequent 'spike' command to fail as the executable is not being built.
               [mbtcc-result (run-and-get-output (format "spike pk ~a" file))]

               ;; --- clang path ---
               [_ (displayln (format "  ~a" (format "Compiling with clang: clang ctest/~a.c runtime.c -o ~a" file file)))]
               [_ (system (format "clang ctest/~a.c runtime.c -o ~a" file file))]
               [clang-result (run-and-get-output (format "./~a" file))])

          ;; --- Comparison ---
          (if (equal? mbtcc-result clang-result)
              (begin
                (printf "~a.c Test Result: Passed\n" file)
                #t) ; Success
              (begin
                (printf "mbtcc result: ~s\n" mbtcc-result)
                (printf "clang result: ~s\n" clang-result)
                (printf "~a.c Test Result: Failed\n" file)
                #f)))) ; Failure
      (lambda () ; After thunk: Clean up generated files
        (printf "  Cleaning up generated files...\n")
        (let ([s-file (format "~a.s" file)])
          (when (file-exists? s-file) (delete-file s-file)))
        (when (file-exists? file) (delete-file file))
        (printf "\n")))))

;; --- Main Logic ---
(define (main)
  (let ([test-all? (member "--testall" (vector->list (current-command-line-arguments)))])
    (if test-all?
        ;; If --testall, run all tests and ignore return values
        (for-each run-test tests)
        ;; Otherwise, stop on the first failure
        (for/and ([test (in-list tests)])
          (run-test test)))))

(main)
