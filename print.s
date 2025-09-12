.global main

main:
  li a0, 44
  call print_int
  call newline
  li a0, 0
  li a7, 93
  ecall
