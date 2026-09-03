# Backlog — what we did, and why

The project's memory. Everything that was decided, why it was decided, and
what it cost or earned. Written so that someone (or some session) arriving
cold can get the whole story without reading five years of git log.

**Read in this order:**

| File | What it answers |
|---|---|
| [`01-project.md`](01-project.md) | What Coloro is, what we are trying to do, and every account/ID you will need |
| [`02-decision-log.md`](02-decision-log.md) | **The main file.** Every significant decision in order, with the reasoning and the outcome |
| [`03-metrics.md`](03-metrics.md) | The numbers over time, so trends are visible instead of buried in dated files |

## How this differs from the other docs — do not duplicate them

The repo already has four kinds of writing and they have different jobs.
Keeping them separate is what stops all of them from rotting:

| Where | Job | Tense |
|---|---|---|
| **`backlog/`** | History and reasoning. Append-only. | Past |
| **`HANDOFF.md`** | Current state and what to do next. Rewritten constantly. | Present |
| **`chat_history/`** | Raw per-session records, in full detail. | Past |
| **`marketing/MARKETING_PLAN.md`** | The operating plan and its gates. | Future |
| **`docs/`, `aso/README.md`** | Rules that constrain the code and the store listing. | Timeless |

`backlog/` is the *index and reasoning layer* over `chat_history/`. Session
records stay where they are — HANDOFF, the memory file and several commit
messages point at them by path, and moving them would break those references
for no gain. The decision log links to them where the full detail lives.

## Keeping it up to date

**After any session that decides something, add a dated entry to
`02-decision-log.md`.** One entry per decision, not per session. An entry is
worth writing if a future reader would otherwise ask "why is it like this?"

Three rules that keep this file honest:

1. **Record the reasoning, not just the change.** "Ads now start at level 1"
   is a changelog. "Ads now start at level 1 because the level-4 gate meant
   92% of paid installs never saw one" is a decision log. Only the second
   stops someone reverting it next month.
2. **Record what was decided *against*, and why.** The rejected options are
   usually the ones that get re-proposed.
3. **Record mistakes as plainly as wins.** Two of the most useful entries in
   here are a form that quietly said "collects no data" for two weeks and a
   restart gate that could never have been met. Neither would be findable if
   the log only recorded successes.

Numbers go in `03-metrics.md` at the same time, so a later reading can be
compared against an earlier one instead of re-derived.
