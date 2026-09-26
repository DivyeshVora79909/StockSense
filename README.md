# StockSense

A small inventory app with a SurrealDB backend and a static frontend. The numbered files in `backend/migrations/` are the database installation source.

## Run locally

Requires Node.js 22+. From the project root:

```sh
npm run dev
```

On first run, the script creates a private `.env` with a generated database password. Add your `BREVO_API_KEY` there to enable email signup and password reset, then run the command again. The sender is fixed to `divy.r.vora14@gmail.com`; that address must be authorized in Brevo.

The command installs SurrealDB 3.2 locally if needed, starts a persistent database in `.data/`, installs the migrations on an empty database, updates the email credential, and prints the app URL (normally **http://127.0.0.1:5173**). Later runs reuse the same database. Stop with Ctrl+C.

## Database files

`npm run db:bundle` joins the numbered migration files into `backend/stocksense-install.surql`. `npm run db:validate` checks that bundle. `npm run db:install` starts the database and imports it when needed, without serving the frontend. The generated bundle begins with `OPTION IMPORT;`, which [SurrealDB requires for imports](https://surrealdb.com/docs/reference/cli/surrealdb-cli/commands/import).

The frontend uses `frontend/runtime.json` for its database address and loads its UI libraries from CDNs. No frontend build step is needed.
