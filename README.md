# StockSense

A small inventory management prototype for products, warehouses, receipts, deliveries, transfers, adjustments, and stock movement history.

## Run it

```sh
npm install
npm run dev
```

The app opens in demo mode with sample inventory and saves prototype changes in browser local storage.

## SurrealDB connection

Set these Vite environment variables in `.env.local` to connect the JS SDK:

```env
VITE_SURREAL_URL=ws://localhost:8000/rpc
VITE_SURREAL_NAMESPACE=stocksense
VITE_SURREAL_DATABASE=inventory
VITE_SURREAL_USERNAME=root
VITE_SURREAL_PASSWORD=root
```

Start a local SurrealDB server and apply `migrations/000001` through `000006` in order. The connection indicator will show whether a server is reachable, and the app can read normalized products, balances, and recent moves. The local demo remains the default when no URL is configured.

> This is a UI prototype, not a production inventory service. The sample screens include illustrative pending-document counts; operations currently update local demo state. Creating and validating normalized stock operations needs server-side transactions and record IDs, which should be implemented before production use.
