import { Surreal } from 'surrealdb';

let db;
export async function connectDatabase() {
  const url = import.meta.env.VITE_SURREAL_URL;
  if (!url) return false;
  try {
    db = new Surreal();
    await db.connect(url, {
      namespace: import.meta.env.VITE_SURREAL_NAMESPACE || 'stocksense',
      database: import.meta.env.VITE_SURREAL_DATABASE || 'inventory',
      auth: import.meta.env.VITE_SURREAL_USERNAME
        ? { username: import.meta.env.VITE_SURREAL_USERNAME, password: import.meta.env.VITE_SURREAL_PASSWORD || '' }
        : undefined,
  });
    return true;
  } catch (error) {
    console.info('SurrealDB is unavailable; using local demo data.', error.message);
    db = undefined;
    return false;
  }
}

export function getDatabase() { return db; }

export async function loadInventory() {
  if (!db) return null;
  const [products, balances, moves] = await Promise.all([
    db.query('SELECT id, sku, name, category, uom FROM product WHERE is_active = true'),
    db.query('SELECT product, location, qty_on_hand FROM stock_balance'),
    db.query('SELECT id, move_at, product, qty, move_type, source_location, destination_location, reference FROM stock_move ORDER BY move_at DESC LIMIT 8'),
  ]);
  const productRows = products[0] || [];
  const balanceRows = balances[0] || [];
  const moveRows = moves[0] || [];
  return {
    products: productRows.map((product) => {
      const productBalances = balanceRows.filter((balance) => balance.product?.id === product.id?.id || balance.product === product.id);
      const primary = productBalances[0];
      return {
      id: product.id, name: product.name, sku: product.sku, category: product.category?.id || 'Uncategorized',
      location: primary?.location?.id || 'Unassigned', quantity: productBalances.reduce((sum, balance) => sum + Number(balance.qty_on_hand || 0), 0),
      minimum: 20, unit: product.uom?.id || 'units', color: 'steel', symbol: '▥',
      };
    }),
    moves: moveRows.map((move) => ({
      id: move.id, type: move.move_type?.id || 'Adjustment', product: move.product?.id || 'Product',
      sku: '', quantity: Number(move.qty || 0), location: move.source_location?.id || move.destination_location?.id || 'Location',
      reference: move.reference?.id || 'Stock movement', time: new Date(move.move_at).toLocaleString(), status: 'Done',
    })),
  };
}

export async function persistProduct(product) {
  if (!db) return;
  console.info('Product persistence needs category and unit record IDs from the configured workspace.');
}

export async function persistMovement(operation, product) {
  if (!db) return;
  console.info('Stock movement persistence requires configured product, location, move type, reference type, and user records.');
}
