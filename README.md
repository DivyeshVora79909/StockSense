# StockSense

A small inventory app backed by SurrealDB. The database installation is in `backend/migrations/`; the browser app is in `frontend/`. The migration files are numbered in execution order. No application server or npm build is needed to run this copy.

## Requirements

- SurrealDB 3.2.0 CLI/server (the version used to check this schema)
- Python 3 for the local static web server
- Internet access for the frontend CDN libraries and, for email, Brevo

Run these commands from the StockSense repository root. Use a new, empty `stocksense` database for the first installation.

## 1. Start SurrealDB

In terminal 1:

```sh
export SURREAL_USER=root
export SURREAL_PASS='replace-with-your-root-password'
mkdir -p .data
surreal start --bind 127.0.0.1:8000 \
  --allow-net api.brevo.com:443 \
  "surrealkv://$(pwd)/.data"
```

Keep this terminal running. `.data/` is the persistent database directory. The scoped network permission lets the database send verification and password reset mail through Brevo.

## 2. Install the schema

In terminal 2, set the **same** root password, create the namespace/database, combine the numbered files, and import them:

```sh
export SURREAL_USER=root
export SURREAL_PASS='replace-with-your-root-password'

printf '%s\n' 'DEFINE NAMESPACE IF NOT EXISTS stocksense; USE NS stocksense; DEFINE DATABASE IF NOT EXISTS stocksense;' |
  surreal sql --endpoint ws://127.0.0.1:8000 --hide-welcome

{ printf 'OPTION IMPORT;\n'; cat backend/migrations/*.surql; } > backend/stocksense-install.surql
surreal validate backend/stocksense-install.surql
surreal import --endpoint http://127.0.0.1:8000 \
  --namespace stocksense --database stocksense \
  backend/stocksense-install.surql
rm backend/stocksense-install.surql
```

The `OPTION IMPORT` line is required by SurrealDB's import endpoint. The combined file is temporary; the numbered files in `backend/migrations/` are the installation source. Import once into an empty database. [SurrealDB import reference](https://surrealdb.com/docs/reference/cli/surrealdb-cli/commands/import)

## 3. Configure email

Still in terminal 2, open the root SQL console:

```sh
surreal sql --endpoint ws://127.0.0.1:8000 --namespace stocksense --database stocksense
```

Paste this **single-line** statement into the console, replacing the placeholder with your Brevo API key:

```sql
UPSERT rebase_email_delivery_config:stocksense SET api_key = 'YOUR_BREVO_API_KEY', from_email = 'divy.r.vora14@gmail.com', from_name = 'StockSense';
```

Brevo must have `divy.r.vora14@gmail.com` enabled as a sender. This credential record is readable only by a database administrator. Keep the API key out of the frontend and Git. The app sends six-digit codes directly from SurrealDB; codes expire after ten minutes.

## 4. Run the frontend

In terminal 3:

```sh
python3 -m http.server 5173 --bind 127.0.0.1 --directory frontend
```

Open **http://127.0.0.1:5173**. The default `frontend/runtime.json` connects to `ws://127.0.0.1:8000/rpc` and selects `stocksense/stocksense`. If you use a different database address or names, edit that file before serving the app. The frontend loads SurrealDB JS, Tailwind, and Lucide from CDNs.

Create an account, verify the email code, then add a unit, warehouse, location, and product. Receipts add stock; deliveries remove it; transfers move it between locations; adjustments record physical counts. Validated changes appear in Move history.
