# The agent team

Three specialists. Each one starts **cold** — it inherits none of the main conversation,
only its own instructions plus `CLAUDE.md`. So give each a task with enough context to
stand alone.

| Agent | Owns | Can edit? |
| --- | --- | --- |
| `developer` | Behaviour. Features, fixes, refactors, wiring. All of `src/`. | yes |
| `designer` | Feel and look. `data/` tables, `GameConfig`, the client UI controllers. | yes |
| `reviewer` | Judgement. Runs the gate, hunts bugs, reports findings. | **no — read-only** |

The reviewer is read-only on purpose: the thing that finds problems should not also be the
thing that decides they are fixed. It reports; the developer applies.

## The loop

```
        designer  ──┐
                    ├──>  reviewer  ──>  findings  ──>  developer  ──>  Studio (you)
        developer ──┘                                        │
                                                             └── re-review if it was a real fix
```

A normal feature: **designer** decides the numbers and the screen → **developer** builds it
→ **reviewer** audits it → **developer** fixes what came back → **you** press Play.

Small bug fix: **developer** → **reviewer**. Pure tuning: **designer** → **reviewer**.

## Invoking them

Ask in plain language — "have the developer add X", "get the reviewer to audit the skill
tree", "ask the designer to rebalance stages 1–5". Or name the agent type directly when
spawning. Give the whole task, not a fragment; they cannot ask you a quick follow-up
mid-run, and a vague brief is where cold-start agents waste their effort.

Run **one at a time** when they touch the same files — two agents editing `src/` in
parallel will clobber each other. Independent tasks (designer on `data/`, reviewer
auditing a different module) are fine to run together.

## What they can reach for

All three can invoke **skills** and can **search the web**. The web access matters more
than it looks: nobody here can run the game, so when an agent is unsure how a Roblox API
actually behaves it is expected to check `create.roblox.com/docs` rather than guess.

- `developer` → `simplify`, `security-review`
- `reviewer` → `security-review`, `code-review` (as a supplement to its own hunt)
- `designer` → `design` (mock a screen up before building it), `dataviz` (balance curves)

The `run` skill does not apply to this project and every agent is told so explicitly.

## The hard limit — read this

**Nothing in this repo can run the game.** There is no Roblox runtime locally, no test
suite, no way to render a ScreenGui. `scripts/check.sh` proves the code *parses,
typechecks, lints and assembles* — that is all it proves.

So "reviewer says it passes" ≠ "it works". Every agent is instructed to end with a
**"Needs checking in Studio"** list. That list is the real test plan, and you are the
test runner. Treat those items as work, not as a formality.
