#!/bin/bash

# Default to not testing all
TESTALL=false
if [[ "$1" == "--testall" ]]; then
  TESTALL=true
fi

# Test list
tests=(simple_ret simple_add if many_args while while2)

# Flag to track if any test has failed
any_failed=false

for file in "${tests[@]}"; do
  echo "Testing ${file}.c"

  # mbtcc path
  if ! moon run mbtcc -- --file "ctest/${file}.c" -o "${file}.s"; then
    echo "mbtcc compilation failed for ${file}.c"
    if ! $TESTALL; then
      exit 1
    fi
    any_failed=true
    continue
  fi

  if ! riscv64-unknown-elf-gcc -o "${file}" "${file}.s" runtime.c; then
    echo "riscv64-unknown-elf-gcc compilation failed for ${file}"
    if ! $TESTALL; then
      exit 1
    fi
    any_failed=true
    continue
  fi

  mbtcc_result=$(spike pk "${file}")
  mbtcc_exit_code=$?

  # clang path
  if ! clang "ctest/${file}.c" runtime.c -o "${file}_clang"; then
    echo "clang compilation failed for ${file}.c"
    if ! $TESTALL; then
      exit 1
    fi
    any_failed=true
    continue
  fi

  clang_result=$(./"${file}_clang")
  clang_exit_code=$?

  # Comapare results
  if [ "$mbtcc_result" == "$clang_result" ] && [ $mbtcc_exit_code -eq $clang_exit_code ]; then
    echo "${file}.c Test Result: Passed"
  else
    echo "mbtcc result: ${mbtcc_result}"
    echo "clang result: ${clang_result}"
    echo "${file}.c Test Result: Failed"
    any_failed=true
    if ! $TESTALL; then
      exit 1
    fi
  fi
done

# Final cleanup only happens if the loop completes
echo "All tests finished. Cleaning up..."
for file in "${tests[@]}"; do
  rm -f "${file}.s" "${file}" "${file}_clang"
done

if $any_failed; then
  echo "Some tests failed."
  exit 1
else
  echo "All tests passed."
  exit 0
fi
