# Packet format (DEC-016)

A packet is a complete task that an agent can execute by following its explicit steps, with no open design decisions. Prime writes the packet before dispatching. The dispatch prompt is only: "Execute `.review/agent-workflow/tasks/REVIVAL-001/packets/<ID>.md` following `RUNBOOK.md`."

Copy this template:

```markdown
# <ID>: <outcome in a few words>
Model: haiku | sonnet   Studio: no | yes   Depends on: <IDs, or none>   Size: S | M | L

## Goal
One or two sentences on what the player or the team gets.

## Read (only these)
- path:lines - why

## Write scope
- exact paths (new files are marked "new")

## Steps
1. Concrete step, naming the file, function or instance to change and what to change it to.
2. ...

## Done when
- Observable checks. Each one is a yes/no.

## Checks to run
- the gate command (RUNBOOK step 3), plus any lune or Studio steps

## STOP-AND-ASK
- Any decision that has not been made yet, as an exact question. "none" if none.

## Evidence
`tasks/REVIVAL-001/<ID>/evidence.md` (RUNBOOK step 5)
```

Rules:
- Cite the decision behind each design choice (DEC-0xx, or design.md §x). Never write "decide", "choose", or "as appropriate".
- Keep each packet to what one agent can do in about 60 tool calls. Split it if larger.
- Name every file to read. Agents read line ranges, not whole folders.
