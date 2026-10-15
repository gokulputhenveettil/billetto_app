# Voting system design

## Overview

The voting subsystem accepts an authenticated user's upvote or downvote for an
event. It keeps the user's current vote in a relational table, records each
accepted vote action in Rails Event Store, and maintains event vote totals for
fast reads.

The design separates responsibilities:

- **Request layer:** authenticates, validates request parameters, and dispatches
  a command.
- **Command layer:** wraps command execution with a transaction, instrumentation,
  and event causality metadata.
- **Domain service:** changes current vote state and publishes a domain fact.
- **Event store:** retains the immutable voting history in event and user
  streams.
- **Projection:** reconciles the denormalized vote counts from current vote
  records and can rebuild current state from event history.

## Goals and invariants

1. Only authenticated users can vote.
2. A vote type is either `upvote` or `downvote`.
3. Each user has at most one current vote for an event.
4. A user can change their vote; the current row is updated, not duplicated.
5. Every accepted vote action is recorded as an event, including changes and
   repeated submissions.
6. Event counts represent current votes, not the number of historical vote
   events.
7. Re-delivering an event or replaying the stream does not double-count votes.
8. Event facts retain stable class names and stream names for event-history
   compatibility.

## Components

| Component | Responsibility |
| --- | --- |
| `VotesController` | Authentication, request validation, and command dispatch |
| `Voting::CastVote` | Immutable command carrying event, user, vote type, and message identity |
| `Voting::CommandBus` | Transaction, command instrumentation, and causality metadata |
| `Voting::Service` | Locked current-vote update and event publication |
| `Voting::Fact` | Shared strict schema validation and event/user stream naming |
| `EventUpvoted`, `EventDownvoted` | Immutable vote facts |
| `Vote` | Current vote record |
| `VoteCounterProjector` | Idempotent totals and event-stream rebuild |
| `ApplicationSubscriptions` | Aggregates domain subscriptions for Rails Event Store |

## Data model

### Current state: `votes`

Each row represents one user's current vote on one event:

- `event_id` references the event row.
- `user_id` is the authenticated Clerk user identifier.
- `vote_type` is constrained to `upvote` or `downvote`.
- `(event_id, user_id)` has a unique database index.

The unique index is the final concurrency-safe guarantee against duplicate
current votes. The service also locks the parent event while applying changes,
so operations on one event are serialized.

### Read model: event vote totals

`events.upvotes_count` and `events.downvotes_count` are denormalized counters.
They are recalculated from the current `votes` records when a vote fact is
handled. They are not derived by summing historical events, since old facts
remain in the audit stream after a user changes their vote.

### History: Rails Event Store

`EventUpvoted` and `EventDownvoted` retain each voting action. Their data
includes:

- `event_id`
- `user_id`
- `previous_vote_type` (`nil`, `upvote`, or `downvote`)
- `voted_at`

Each fact defines two stream names:

- `Event$<event-id>` is the primary event stream.
- `User$<user-id>` is the linked user audit stream.

The top-level event classes are intentionally retained to avoid breaking
deserialization of previously stored events.

## Vote request flow

1. The controller requires authentication, finds the event, and accepts only
   `upvote` or `downvote`.
2. It creates `Voting::CastVote` and sends it to the configured command bus.
3. `Voting::CommandBus` starts a database transaction and instruments command
   execution. `RubyEventStore::CorrelatedCommands` establishes or propagates
   correlation and causation metadata.
4. `Voting::Service` locks the event row, reads the previous vote, and inserts
   or updates the `Vote` row.
5. The service creates a schema-validated fact and publishes it to the event
   stream, then links it to the user stream.
6. Rails Event Store dispatches the fact to `VoteCounterProjector`.
7. The projector locks the event row, counts current vote records by type, and
   replaces the denormalized totals.

## Consistency and failure behavior

The command bus transaction encloses both the current vote update and Rails
Event Store publication. A failure during command execution rolls back the
database changes. Projector updates are derived from current state, so repeated
or stale deliveries converge on the same totals.

Event stream linking occurs after the primary publish. It is performed inside
the same command transaction, so a failure while linking also rolls back the
vote update and event publication when using the configured relational event
repository.

The event row lock serializes vote changes and projection count updates for an
event. The database unique index independently guards the one-vote invariant.

## Rebuilding state

Use this task to seed or repair current vote rows and totals from historical
event streams:

```sh
bin/rails votes:rebuild
```

For each event, `VoteCounterProjector#rebuild!` locks the event, reads its
`Event$<event-id>` stream in order, and remembers the latest upvote or downvote
for each user. It replaces that event's current vote records and recalculates
the counters. Repeating the rebuild produces the same current state.

## Design trade-offs

- **Relational current state plus event history:** current vote lookups and
  counts are efficient, while immutable facts preserve an audit trail.
- **Synchronous projection:** vote totals are reconciled during event
  dispatch, keeping behavior simple and immediately consistent for the current
  deployment. A future asynchronous projection would need explicit delivery
  monitoring and retry handling.
- **Per-event locking:** this prevents races for one event while allowing
  unrelated events to be updated independently.
- **Full stream rebuild:** this is simple and deterministic for the current
  event volume. If histories grow substantially, rebuilding can be batched or
  checkpointed.

## Main implementation files

- `app/controllers/votes_controller.rb`
- `app/domain/voting/cast_vote.rb`
- `app/domain/voting/command_bus.rb`
- `app/domain/voting/service.rb`
- `app/domain/voting/fact.rb`
- `app/events/event_upvoted.rb`
- `app/events/event_downvoted.rb`
- `app/models/vote.rb`
- `app/subscribers/vote_counter_projector.rb`
- `lib/application_subscriptions.rb`
- `config/initializers/command_bus.rb`
- `config/initializers/rails_event_store.rb`
- `lib/tasks/votes.rake`
