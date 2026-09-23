# accountabot

An accountant agent that works for a licensed CPA. The agent does the work, and the CPA is
asked only for decisions that need their judgement or licence.

## Autonomy tiers (`Accountabot.Policy`)

| Tier | Rule | Routed to |
|---|---|---|
| `:auto` | kind ∈ allowlist ∧ amount < materiality ∧ confidence ≥ floor ∧ reversible | weekly digest (the CPA can reverse) |
| `:propose` | any other action | dashboard + digest |
| `:reserved` | the action needs the licence: accept engagement, sign-off, filing, tax positions, advice | dashboard + SMS |

Nothing is auto-applied unless its kind is on the allowlist. `Policy.classify/2` is total and has no side effects.

## Core

- `Ledger`: an immutable double-entry ledger in integer cents. Invariants: every entry balances,
  the signed trial balance sums to 0, and A = L + E + (R − X).
- `Workflow`: stages and gates as data for `monthly_close`, `tax_return` and `onboarding`.
- `Engagement`: an event-sourced decider (`decide/2`, `evolve/2`, `replay/1`). A stage can be left
  only when no item is open and every gate kind has a CPA-approved item in that stage.
  Events record the policy config and the assigned tier, so replaying them doesn't depend on later policy changes.
- `Inbox`: shows what needs the CPA, for each channel.

## Onboarding → adaptive agent and UI

The CPA answers a short questionnaire (`Onboarding.questions/0`, defined as data, with conditional
questions). `Profile.from_answers/1` derives everything else from the answers:

| Question | Drives |
|---|---|
| Where do you review? (`web`/`mobile`/`email`/`sms`) | the channels notifications go through |
| What do you need to see? | `card_sections`: the sections an item card shows |
| How often? (`realtime`/`daily`/`weekly`) | whether proposals notify immediately or go in the digest, and the digest schedule |
| Interrupt for reserved items? (asked only if relevant) | whether licence-only items notify immediately |
| How much autonomy? (`cautious`/`balanced`/`hands_off`) | `Policy` materiality and confidence thresholds |

Answers are an event stream per CPA (`Cpas`), so revising an answer changes behaviour and keeps an audit
trail. Invariants:
- Reserved work always reaches a chosen surface.
- No route uses a surface the CPA didn't choose.
- Autonomy is monotone: anything cautious auto-applies, balanced does too, and so on up to hands_off.

`Inbox` exposes `queue/1`, `alerts/2`, `digest/2` and `card/2` as view models, so any UI renders
from the same profile.

## Web (`AccountabotWeb`, Phoenix LiveView)

No JS toolchain: the LiveView client is served straight from the deps.

- `/onboarding/:cpa`: one question at a time with progress, conditional questions, and validation of
  every value against the options (no atoms created from form input). It ends with `Profile.describe/1`, a plain-language
  account of how the agent will work, and every answer can be changed.
- `/review/:cpa`: grouped by who must act: *only you can decide*, *waiting for your approval*, *done on my own
  (reverse anything)*. Cards show exactly the evidence sections the CPA chose. Approve, reject and reverse are
  recorded as `{:cpa, id}`, and screens update live over PubSub as the agent raises work.
  A CPA who hasn't finished onboarding is sent to onboarding.

```sh
mix phx.server          # dev: in-memory store, demo engagements for CPA "demo" → http://localhost:4000
```

> ⚠ The CPA id in the URL is **not authentication**. Add sign-in before exposing these routes beyond localhost.

## Persistence

- `EventStore`: append-only streams with optimistic concurrency
  (`append` succeeds ⇔ the stream is at the expected version). Two adapters, `Postgres` and `Memory`,
  both pass the same contract test, including racing writers.
- `Engagement.Codec`: turns events into JSON rows. It decodes against a closed vocabulary,
  so reading from the database never creates atoms.
- `Aggregate`: runs any `Decider` against a stream. Load = replay(read). Execute = decide + append at
  the version loaded from, and after a conflict the command is decided again against fresh state. `Engagements` and `Cpas`
  are thin wrappers around it.
- `Books`: a ledger per client. `Ledger.validate/2` runs before any write. The schema
  independently enforces balanced entries (a deferred constraint trigger) and append-only
  `events`/`journal_*` rows (no UPDATE, DELETE or TRUNCATE).
- `Migrations`: versioned statements kept as data. `mix accountabot.migrate` applies them in one
  transaction under an advisory lock.

The connection is configured through the standard `PGHOST`, `PGUSER`, `PGPASSWORD` and `PGDATABASE` variables.

## Tests

Requires Elixir ≥ 1.17.

```sh
createdb accountabot_test   # optional: without Postgres, the :postgres tests are skipped with a warning
mix test
```

Invariants are checked over 500 seeded random cases each. Four mutations were used to check the tests: breaking
the gate check, dropping the version check, silencing interrupts and inverting the autonomy thresholds each
make a property fail.

## Roadmap

1. ~~Persistence~~ ✓
2. Runtime: one process per engagement (`Registry` + `DynamicSupervisor`), and Oban for scheduled stages.
3. Link items to the ledger: approved or applied `journal_entry` items post to `Ledger`; reversals post
   contra entries.
4. Adapters (one behaviour each, with fakes in tests): bank feeds, document intake (Gmail/Drive), QBO import.
5. Classifier: an LLM proposes `{kind, amount, confidence, evidence}`, and `Policy` decides the tier.
6. ~~CPA review surface~~ ✓ (web). Next: authentication, then SMS/push/email delivery of `Inbox.alerts/2` and `Inbox.digest/2`.
