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

## Tests

```sh
mix test
```

Invariants are checked over 500 seeded random cases each, with no extra dependencies. Mutating the gate
check makes the engagement property fail.

## Roadmap

1. Persistence: a Postgres event store (append-only, optimistic concurrency on stream version) and ledger tables.
2. Runtime: one process per engagement (`Registry` + `DynamicSupervisor`), and Oban for scheduled stages.
3. Link items to the ledger: approved or applied `journal_entry` items post to `Ledger`; reversals post
   contra entries.
4. Adapters (one behaviour each, with fakes in tests): bank feeds, document intake (Gmail/Drive), QBO import.
5. Classifier: an LLM proposes `{kind, amount, confidence, evidence}`, and `Policy` decides the tier.
6. Channels: the `accountabot_dashboard` review pane, Twilio SMS approvals and the weekly digest email.
