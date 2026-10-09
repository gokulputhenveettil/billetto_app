# Billetto App

Billetto App is a Rails application that imports public Billetto events, displays
upcoming and past events, and lets signed-in users upvote or downvote events.
Event imports and vote history use separate background/event-sourcing
components: Sidekiq runs scheduled imports and cleanup, while Rails Event Store
records votes and projects vote counts onto each event.

## Requirements

- Ruby 3.4.11 (see `.ruby-version`)
- PostgreSQL
- Redis (required for Sidekiq; Action Cable also uses it)
- Billetto API credentials (`BILLETTO_API_KEYPAIR`) to import events
- Clerk application keys (`CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY`) for
  authentication and voting

## API credentials and what they do

### Billetto API keypair

Request API access and an API keypair from Billetto through your Billetto
account representative or Billetto developer/API support. The API keypair is
not the same as a Clerk key.

Set the keypair as `BILLETTO_API_KEYPAIR`. The importer passes it in the
`Api-Keypair` request header when calling Billetto's public events endpoint:
`https://billetto.dk/api/v3/public/events`. The importer requests up to 100
events per page, follows the API's pagination links, and inserts or updates
records by Billetto event ID. It stores the raw response data as well as the
fields used by the UI.

The keypair is needed for manual imports and the scheduled import job. Without
it, the importer raises an error instead of making an unauthenticated request.

### Clerk keys

Create a Clerk application at [Clerk Dashboard](https://dashboard.clerk.com/),
then copy its keys from the application's **API Keys** settings:

- `CLERK_PUBLISHABLE_KEY` (`pk_test_...` or `pk_live_...`) is embedded in the
  page to initialize Clerk's browser SDK and render the sign-in/sign-up
  controls.
- `CLERK_SECRET_KEY` (`sk_test_...` or `sk_live_...`) configures the Clerk
  server-side Clerk integration. The Rails controller uses Clerk's
  authentication helper to identify the signed-in user. An authenticated
  Clerk user is required to vote.

Use test keys for local development and production keys only for the deployed
application's Clerk domain/origins. Do not expose or commit the secret key.

### Secret handling

Create a local `.env` file for development or deployment and keep it out of
version control. This repository ignores `.env*` files. Never put real keys in
README examples, source code, Docker images, or committed environment files.
For deployments, inject secrets through the hosting platform's secret manager
or environment configuration.

## Local development

1. Install Ruby 3.4.11, PostgreSQL, and Redis. Make sure PostgreSQL is running;
   start Redis if you intend to run Sidekiq.
2. Install dependencies:

   ```sh
   bundle install
   ```

3. Create `.env` in the repository root:

   ```dotenv
   BILLETTO_API_KEYPAIR=<Billetto API keypair>
   CLERK_PUBLISHABLE_KEY=<Clerk publishable key>
   CLERK_SECRET_KEY=<Clerk secret key>
   REDIS_URL=redis://localhost:6379/0
   ```

   Database settings for development are in `config/database.yml`; by default,
   Rails connects to the local PostgreSQL database `billetto_app_development`.
   If your PostgreSQL setup requires a username, password, or host, configure
   those settings for your local environment.
4. Prepare the database and start the web app:

   ```sh
   bin/rails db:prepare
   bin/rails server
   ```

   Open <http://localhost:3000>. The `/up` endpoint reports application health.
5. To run scheduled/background work locally, start a separate worker:

   ```sh
   bundle exec sidekiq -C config/sidekiq.yml
   ```

   Sidekiq must be able to connect to the same Redis and PostgreSQL instances as
   the web process.

## Import events manually

Run the import task after setting `BILLETTO_API_KEYPAIR`:

```sh
bin/rails billetto:import_events
```

The task prints the number of imported records and exits with a failure status
if the import fails. The importer can also be run through the Sidekiq job.

## Technical overview

### Events and imports

- `GET /` and `GET /events` show events ordered by start time. Past events
  remain visible but are visually marked as past.
- `GET /events/:id` shows an event's details.
- `POST /events/:event_id/votes` records a vote for an event.
- Billetto event data is stored in PostgreSQL in the `events` table. A unique
  index on `billetto_id` supports idempotent imports.
- The importer fetches paginated event data, validates required fields, and
  upserts the event fields and `last_synced_at`.

### Authentication and votes

Clerk handles browser sign-in and server-side session verification. The vote
endpoint requires an authenticated user and accepts `type=upvote` or
`type=downvote`; any other type is rejected.

Votes are represented by `EventUpvoted` and `EventDownvoted` domain events in
Rails Event Store. Each vote is published to the event stream
(`Event$<event-id>`) and linked to the user's audit stream
(`User$<clerk-user-id>`). `VoteCounterProjector` increments the corresponding
`upvotes_count` or `downvotes_count` column on the event record.

### Background jobs and schedules

The Sidekiq schedule is in `config/sidekiq.yml` and uses the Rails
`Asia/Kolkata` timezone:

| Job | Schedule | Behavior |
| --- | --- | --- |
| `Billetto::ImportEventsJob` | Daily at 12:00 | Imports and upserts Billetto events |
| `Billetto::DeleteOldEventsJob` | Daily at 02:00 | Deletes events whose `starts_at` is more than 30 days in the past |

The schedules only run while a Sidekiq process is running with
`config/sidekiq.yml`.

## Run with Docker

The production Dockerfile builds the Rails app and assets using the Ruby
version in `.ruby-version`.

1. Install Docker. Provide a PostgreSQL server and a Redis server reachable
   from the containers. The production database configuration uses the
   `billetto_app` role and the `billetto_app_production`,
   `billetto_app_production_cache`, and `billetto_app_production_cable`
   databases. The role must be able to access all three databases.
2. Create a local `.env` file with the deployment secrets and connection URLs:

   ```dotenv
   RAILS_MASTER_KEY=<Rails credentials master key>
   BILLETTO_APP_DATABASE_PASSWORD=<database role password>
   DATABASE_URL=postgresql://billetto_app:<url-encoded-password>@host.docker.internal:5432/billetto_app_production
   REDIS_URL=redis://host.docker.internal:6379/0
   BILLETTO_API_KEYPAIR=<Billetto API keypair>
   CLERK_PUBLISHABLE_KEY=<Clerk production publishable key>
   CLERK_SECRET_KEY=<Clerk production secret key>
   ```

   Obtain the Billetto and Clerk keys as described above. Set
   `RAILS_MASTER_KEY` to the key for the encrypted Rails credentials used by
   the deployment; do not use a placeholder value. URL-encode any special
   characters in the database password included in `DATABASE_URL`.
   `host.docker.internal` is appropriate when PostgreSQL and Redis run on the
   Docker host. Otherwise, use the database and Redis hostnames reachable from
   the containers.
3. Build the image and start the web container:

   ```sh
   docker build -t billetto_app .
   docker run -d --name billetto_app --env-file .env -p 3000:80 \
     --mount source=billetto_storage,target=/rails/storage billetto_app
   ```

   The entrypoint runs `bin/rails db:prepare` before starting the web server.
   Open <http://localhost:3000>.
4. Start Sidekiq after the web container has prepared the database:

   ```sh
   docker run -d --name billetto_sidekiq --env-file .env billetto_app \
     bundle exec sidekiq -C config/sidekiq.yml
   ```

5. Inspect logs or stop the containers:

   ```sh
   docker logs -f billetto_app
   docker logs -f billetto_sidekiq
   docker stop billetto_app
   docker stop billetto_sidekiq
   ```

The named `billetto_storage` volume keeps Active Storage files between
container replacements. For production deployments, consider cloud object
storage.

## Tests

Run the test suite with:

```sh
bin/rails test
```
