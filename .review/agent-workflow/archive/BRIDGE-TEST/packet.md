# BRIDGE-TEST — lane.sh self-test (read-only)

```yaml
id: BRIDGE-TEST
title: Count server module files, change nothing
status: ready
role: scout
model: deepseek-v4-pro
objective: Count the .luau files directly under src/server/Modules and report the number.
read_scope:
  - src/server/Modules (list files only)
write_scope: []
invariants:
  - No file may be modified, created, or deleted.
acceptance:
  - Final reply uses the standard result format.
  - SUMMARY contains the file count.
  - CHANGED is "none".
forbidden:
  - Any file modification
  - git commands
```
