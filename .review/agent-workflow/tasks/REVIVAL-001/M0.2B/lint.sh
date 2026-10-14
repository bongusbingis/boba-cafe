#!/bin/bash
# usage: lint.sh <root> ; runs selene + stylua on the file list relative to root
SEL=/Users/jackcrowell/.rokit/tool-storage/kampfkarren/selene/0.31.0/selene
STY=/Users/jackcrowell/.rokit/tool-storage/johnnymorganz/stylua/2.5.2/stylua
S=/private/tmp/claude-501/-Users-jackcrowell-Desktop-boba-cafe/7e617087-b76e-40c7-8dfe-603339237eff/scratchpad
ROOT=$1
cd /Users/jackcrowell/Desktop/boba-cafe
while read -r f; do
  [ -f "$ROOT/$f" ] || { echo "== $f (absent)"; continue; }
  sel=$($SEL --display-style quiet "$ROOT/$f" 2>&1 | grep -E "error|warning" | sed -E 's/^[^:]+:[0-9]+:[0-9]+: //' | sort | uniq -c | tr '\n' ';')
  sty=$($STY --check "$ROOT/$f" 2>&1 | grep -cE "\|[-+]" )
  echo "== $f | stylua diff lines: $sty | selene: $sel"
done < $S/files.txt
