# Voting architecture

## Purpose

This document records the original voting design gaps, the architecture now in
place, and how to rebuild vote state.

## Design gaps addressed

| Original gap | Change |
| --- | --- |
| Votes existed as Rails Event Store events without a current-vote record or a database uniqueness guarantee. | The `votes` table stores each user's current vote. A unique index on `(event_id, user_id)` and a database check constraint enforce one valid vote per user per event. |
| The voting workflow was not consistently command-driven and mixed request handling with event publication. | `VotesController` dispatches `Voting::CastVote`. `Voting::Service` owns vote persistence and Rails Event Store publication. |
| Command dispatch did not explicitly provide transaction handling, instrumentation, or causation/correlation metadata. | `Voting::CommandBus` wraps dispatch in a database transaction, instruments command execution, and uses Rails Event Store's `CorrelatedCommands` to propagate metadata. |
| Domain events did not declare an enforced data schema or their destination streams. | `EventUpvoted` and `EventDownvoted` inherit from `Voting::Fact`, declare `SCHEMA`, validate data through `.strict`, and define event and user stream names. Their top-level class names remain unchanged to preserve compatibility with events already stored in Rails Event Store. |
| Subscriber registration was hard-coded in the Event Store initializer. | `VoteCounterProjector.subscriptions` is exposed through `Voting.subscriptions` and collected by `ApplicationSubscriptions.handlers`. |
| Projection updates could drift on vote changes or duplicate event delivery. | The projector recalculates event totals from current vote rows under an event lock. Duplicate and stale event delivery therefore reconciles to the same counts. |
| Existing event history could not repopulate the new current-vote table. | `VoteCounterProjector#rebuild!` replays an event's stream and reconstructs each user's latest vote. The `votes:rebuild` task applies this to every event. |

## Runtime flow

1. `VotesController` authenticates the user, loads the event, validates the
   requested vote type, and dispatches `Voting::CastVote`.
2. `Voting::CommandBus` wraps the command in a transaction and notification,
   and establishes Rails Event Store correlation and causation metadata.
3. The command bus invokes `Voting::Service`, which locks the event, creates or
   updates the user's current `Vote`, and publishes the corresponding fact.
4. Each fact is published to its event stream and linked to its user audit
   stream, as declared by `stream_names`.
5. Rails Event Store dispatches the fact to `VoteCounterProjector`, which
   reconciles `upvotes_count` and `downvotes_count` from current vote rows.

## Rebuilding current vote state

Run the rebuild task after deployment when existing event history must be
backfilled into `votes`, or to repair the current-vote state and counters:

```sh
bin/rails votes:rebuild
```

The task processes each event separately. For a given event, the projector
locks its event row, reads `Event$<event-id>`, keeps the latest upvote or
downvote for each user, replaces that event's current vote rows, and recalculates
its counters. Re-running the task produces the same state.

## Key implementation locations

- `app/domain/voting/cast_vote.rb` — command
- `app/domain/voting/command_bus.rb` — transaction, instrumentation, and
  causality boundary
- `app/domain/voting/service.rb` — vote state changes and fact publication
- `app/domain/voting/fact.rb` — shared strict fact schema validation and stream
  naming
- `app/events/event_upvoted.rb` and `app/events/event_downvoted.rb` — vote facts
- `lib/application_subscriptions.rb` and
  `config/initializers/rails_event_store.rb` — subscription registration
- `app/subscribers/vote_counter_projector.rb` — count projection and rebuild
- `lib/tasks/votes.rake` — full state rebuild task

## Verification

The voting architecture was verified with the full Rails test suite
(26 tests, 114 assertions), RuboCop, `bin/rails zeitwerk:check`, and task
registration via `bin/rails votes:rebuild --dry-run`.
