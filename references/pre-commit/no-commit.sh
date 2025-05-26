#!/bin/bash

pattern="! NO COMMIT !"
pattern_found=false

for file in "$@"; do
  if [[ -f "$file" ]] && rg -q "$pattern" "$file"; then
    echo "✖ Commit rejected: You did not want to commit \`$file\`"
    pattern_found=true
  fi
done

if [[ "$pattern_found" == "true" ]]; then
    exit 1
fi

exit 0
