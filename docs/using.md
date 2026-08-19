# Using syl4 day to day

[install.md](./install.md) ends at your first question. This page is
everything after that: the things you can ask for in a Claude Code session
once the `syl4` server is connected. You say what you want in plain
language, and Claude drives syl4 for you.

The terminal-only route (`syl4 -i "<question>"`) runs questions end to end
without Claude Code. The other flows on this page — teaching definitions,
pulling SQL, inspecting runs — are session flows; for those you need the
MCP connection from [install.md](./install.md#step-3--ask-your-first-question).

## Ask a question, judge the reading

Prefix any prompt with `syl4`:

> syl4 how many customers signed up last month?

Before anything runs, syl4 shows you a **syl4ish reading** — a
plain-English rendering of the formal definition your question was compiled
into, not a paraphrase of your prompt. Read it as the contract: what it
says is what will be computed.

- If the reading matches what you meant, accept it and the run proceeds —
  planned, verified, and executed next to your data.
- If it doesn't — or it settled an ambiguity differently than you meant —
  say so in plain words. The formalization is revised and you get a new
  reading to judge. You can go around this loop as many times as it takes.

An accepted question is remembered: ask it again and it comes back from
the plan cache in seconds, byte-for-byte the same program. The match
forgives capitalization and spacing, but not rewording — repeating a
question in the same words (or asking Claude to re-run a previous one
unchanged) is how you get that speed; rephrasing it makes it a new
question.

Two caveats worth knowing: the reading doesn't always render before
execution (treat a missing one as a bug and
[report it](#report-a-problem-with-a-run)), and an ambiguous prompt gets a
picked reading to correct rather than a clarifying question — both are on
the roadmap, see [known-issues.md](./known-issues.md).

## See the formalization without running anything

If you want to see what a question turns into formally — before deciding
whether to run it, or just to check how syl4 understands a term — ask for
that:

> syl4 formalize: revenue per region last quarter

You get the same syl4ish reading and revision loop, and once you accept,
the formal definition and its input/output types — but no execution. The
accepted definition is banked, so running the same question later starts
from what you already approved.

## Teach syl4 a definition

Every organization has terms the schema doesn't spell out — _active
customer_, _net revenue_, _churned this quarter_. Submit yours in your own
words:

> syl4 define an active customer as one with at least one order in the
> last 90 days

What happens next (the `submit_definition` flow):

1. syl4 first checks the vocabulary the deployment already serves. If an
   existing definition covers your meaning, you're shown it and asked
   whether to reuse it rather than filing a near-duplicate.
2. An agent drafts the formal definition and produces an **independent
   plain-English reading** of the draft — a round-trip through the formal
   text, so you're judging what was actually captured, not an echo of what
   you typed. Where the term will appear in future syl4ish readings, you
   also see the exact phrase.
3. You judge the reading: accept it as is, revise the meaning in plain
   words (which redrafts it), or amend just the phrase.
4. Accepting files the definition as a **candidate for review**. It serves
   nothing yet: a reviewer has to approve it and promote it into the
   deployment's vocabulary (some deployments are configured to do this
   automatically).
5. Once promoted, it's deployment-wide — everyone asking about active
   customers gets _your_ active customers, in every question that follows.

You can check on things at any point:

- "what definitions does this deployment know?" (`list_definitions`) —
  the promoted vocabulary: each term's name, a one-line summary of its
  meaning, and the phrase it renders as.
- "where does my submission stand?" (`get_submission_status`) — pending,
  approved, promoted, or rejected with the reviewer's reason.

## Review the SQL before a run executes

For SQL-backed datasources you can pull the **exact SQL statements a
prepared run will execute** — extracted from the verified program itself,
not reconstructed or summarized, and nothing is executed to produce the
listing (`get_run_sql`). If your process wants a review gate, ask for it
up front:

> syl4 run this, but show me the SQL before executing anything

The review is optional by design — the SQL is derived from a verified
program, so skipping the listing loses no guarantee. Expect generated
shape, not hand-written idiom: see
[known-issues.md](./known-issues.md#generated-sql-doesnt-read-like-hand-written-sql).

## Look inside a finished run

Every run leaves a full audit trail you can ask about in plain language:

- **The whole chain** (`get_run_artifacts`) — the prompt, the formal
  definition, the plan, the generated program, the outcome, and which
  stages were served from cache. "Show me the program that ran" or "was
  that a cache hit?" both land here.
- **The outcome and timing** (`get_run_result`) — the run's final status
  and, for executed runs, the execution record: how it exited and how long
  it took. "How long did that run take?" is answered from here.
- **Why a run failed** (`get_run_failure`) — which stage failed, a summary
  of the error, and the log tail.
- **The SQL it ran** (`get_run_sql`) — the same listing as above works
  after execution too.

One question spans several run ids — one per validation round, plus the
execution run — and Claude reports the two that matter: the accepted
round and the execution run. You don't need to bookkeep any of them:
"show me my recent runs" (`list_runs`) lists the history, so a past run
is findable by its prompt.

The execution side lives on your machine, too:
`~/.syl4/executions/<run_id>/` holds the program's output (`result.txt`),
the executor log, and `meta.json` with the exit status and duration.

## Cancel a run

Changed your mind while a run is still in flight — mid-revision-loop, or
right after realizing the question was wrong? Say so:

> actually, stop that run

The run is stopped and settles in a recorded `cancelled` state
(`cancel_run`). Cancelling a run that already finished is a harmless
no-op.

## Report a problem with a run

If a run behaves badly — a wrong reading, a missing syl4ish summary, an
oddly-planned query, a failure you can't explain — tell the person who
invited you to syl4, with the run id. To hand them something concrete, ask
for an export:

> syl4 export that run so I can file an issue

This builds a **sanitized archive of the run's artifacts** (`export_run`)
made for exactly this: sharing what happened without sharing your data.
These reports are how the readings and the planner get better — see
[known-issues.md](./known-issues.md) for what's already known.
