# Why syl4 for text-to-SQL

The use case: ask a question about your database in plain language and get
the right answer back. Every "AI for data" tool demos this; the failure mode
they share is that the model **guesses** — at what you meant, at which join
is right, at what "active customer" means — and a wrong guess looks exactly
like a right one until someone audits it.

syl4 takes a different route: your question is compiled into a **typed,
formally verified program**, and the SQL that runs is derived from that
program — provably what you asked for, the same byte-for-byte on every
re-run. The four capabilities below are where that difference becomes
something you can see and use on day one.

## syl4ish — confirm the question before anything runs

Your natural-language question is first formalized into a precise, typed
definition. **syl4ish** renders that formal definition back as plain
language — a proof-checked reading of what will actually be computed, not a
paraphrase of your prompt — so you confirm the interpretation before a
single query executes.

- Nothing is resolved silently. If the reading is wrong — or if it settled
  an ambiguity in your question differently than you meant — you say so in
  plain words and the formalization is revised. The accepted reading is
  carried forward for next time.
- What you approve is what runs: the rendering is derived from the same
  formal definition the program is compiled from.

See [known-issues.md](./known-issues.md) for what's still on the roadmap
here (a grounded clarifying question, rather than a reading to correct).

## Caching — define once, answer fast forever

The formalize–plan–verify pipeline is a **one-time cost per definition**,
not a per-question tax. Once a question has been defined, it serves from the
plan cache:

- Repeat and templated questions ("that report, for March") reuse the
  cached plan at interactive latency — no model in the loop on the serving
  path.
- The cached artifact is the verified program itself, so a cache hit is
  byte-for-byte the same program every time: identical SQL, identical
  semantics, this quarter and next.
- Cost follows the same curve as latency — the LLM is paid for when a
  definition is created, not every time it's asked.

## Custom definitions — teach syl4 your vocabulary

Every organization has terms the schema doesn't spell out: _active
customer_, _net revenue_, _churned this quarter_. With syl4 you submit the
definition **in your own words** ("here is what we mean by an active
customer") and it becomes a first-class, reviewed concept:

- An agent drafts the formal definition, searching existing concepts first —
  a duplicate comes back as "did you mean …" rather than a second,
  conflicting version.
- Submission gates check the draft compiles, collides with nothing, and is
  findable in retrieval, and an independent plain-English reading is
  produced for you to judge.
- Your judgment of that reading is the first gate, not the last one.
  Accepting it files the definition as a candidate for review; it serves
  nothing until a reviewer approves it and it's promoted into the
  deployment's vocabulary. You can check where a submission stands at any
  point (pending, approved, promoted, or rejected with the reason).
- Once promoted, the definition is used deployment-wide: everyone asking
  about active customers gets _your_ active customers, in every question
  that follows.

How to submit one, and how to track it through review, is in
[using.md](./using.md#teach-syl4-a-definition).

## Optional SQL review — the exact SQL, on demand

Before a prepared run executes, you can pull the **exact SQL statements it
will run** — extracted from the program itself, not reconstructed or
summarized. Nothing is executed to produce the listing.

- DBAs and data governance get a review gate with real content: the
  statement they read is the statement that runs.
- It's optional by design — the SQL is derived from a verified program, so
  review is a step you can insert where your process wants one, not a
  correctness requirement. Teams that want eyes on every statement pull the
  listing before executing; teams that don't lose no guarantee by skipping
  it. How to ask for it is in
  [using.md](./using.md#review-the-sql-before-a-run-executes).

## The takeaway

Generic text-to-SQL asks you to trust a guess. syl4 gives you a confirmed
interpretation (syl4ish), a verified program that never drifts (caching),
your own business vocabulary as reviewed, shared definitions, and the exact
SQL on demand when someone wants to look.

The read path above is what ships today. See
[known-issues.md](./known-issues.md) for what's next — including the same
guarantees applied to the write side. Questions about any of this? Ask the
person who invited you to syl4.
