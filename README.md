# Billetto App

## Run with Docker

The production Dockerfile builds the Rails app and its assets into an image. It
uses the Ruby version from `.ruby-version`.

1. Make sure Docker is installed and a PostgreSQL server is reachable from the
   container. The production database configuration uses the `billetto_app`
   role and the `billetto_app_production`, `billetto_app_production_cache`,
   and `billetto_app_production_cable` databases. A Redis server must also be
   reachable by both the web and Sidekiq containers.
2. Create a local `.env` file (it is excluded from the Docker build context) with
   the Rails master key and database connection settings:

   ```dotenv
   RAILS_MASTER_KEY=<contents of config/master.key>
   BILLETTO_APP_DATABASE_PASSWORD=<database role password>
   BILLETTO_API_KEYPAIR=<Billetto API keypair>
   DATABASE_URL=postgresql://billetto_app:<url-encoded-password>@host.docker.internal:5432/billetto_app_production
   REDIS_URL=redis://host.docker.internal:6379/0
   ```

   If PostgreSQL is not running on the host machine, replace
   `host.docker.internal` with the database hostname reachable from Docker.
   Ensure the role can access all three production databases.
3. Build and start the container:

   ```powershell
   docker build -t billetto_app .
   docker run -d --name billetto_app --env-file .env -p 3000:80 --mount source=billetto_storage,target=/rails/storage billetto_app
   ```

   On startup, the container entrypoint runs `bin/rails db:prepare` before
   starting the web server. Open <http://localhost:3000>.
4. Start the Sidekiq worker after the web container has prepared the database:

   ```powershell
   docker run -d --name billetto_sidekiq --env-file .env billetto_app bundle exec sidekiq -C config/sidekiq.yml
   ```

   Sidekiq imports Billetto events every day at 12:00 Europe/Copenhagen time.
5. View logs or stop the containers:

   ```powershell
   docker logs -f billetto_app
   docker logs -f billetto_sidekiq
   docker stop billetto_app
   docker stop billetto_sidekiq
   ```

The named `billetto_storage` volume keeps local Active Storage uploads between
container replacements. For production deployments, consider using cloud
object storage instead.
