import { useEffect, useMemo, useState } from 'react';
import {
  Activity, ArrowDownLeft, ArrowLeftRight, ArrowRight, ArrowUpRight, Bell, Boxes,
  Check, ChevronDown, CircleHelp, Clock3, Command, Download, LayoutDashboard,
  ListFilter, MapPin, Menu, MoreHorizontal, Package, Plus, Search, Settings,
  SlidersHorizontal, Sparkles, Truck, Warehouse, X,
} from 'lucide-react';
import { inventory, saveInventory } from './data.js';

const money = (value) => new Intl.NumberFormat('en-US').format(value);
const iconByType = { Receipt: ArrowDownLeft, Delivery: ArrowUpRight, Transfer: ArrowLeftRight, Adjustment: SlidersHorizontal };

export default function App() {
  const [products, setProducts] = useState(inventory.products);
  const [moves, setMoves] = useState(inventory.moves);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('All products');
  const [modal, setModal] = useState('');
  const [toast, setToast] = useState('');
  const [connected, setConnected] = useState(false);
  const [database, setDatabase] = useState(null);
  const [showRestockAlert, setShowRestockAlert] = useState(true);
  const totalUnits = products.reduce((sum, product) => sum + product.quantity, 0);
  const lowStock = products.filter((product) => product.quantity <= product.minimum).length;
  const visibleProducts = useMemo(() => products.filter((product) => {
    const matchesQuery = `${product.name} ${product.sku} ${product.category}`.toLowerCase().includes(query.toLowerCase());
    return matchesQuery && (filter === 'All products' || (filter === 'Low stock' ? product.quantity <= product.minimum : product.category === filter));
  }), [products, query, filter]);

  useEffect(() => {
    let active = true;
    import('./db.js').then(async (module) => {
      const ok = await module.connectDatabase();
      if (!active) return;
      setConnected(ok); setDatabase(module.getDatabase());
      if (ok) {
        try { const remote = await module.loadInventory(); if (active && remote?.products.length) { setProducts(remote.products); setMoves(remote.moves); } }
        catch (error) { console.error('Could not load SurrealDB inventory.', error); }
      }
    });
    return () => { active = false; };
  }, []);

  function notify(message) {
    setToast(message);
    window.setTimeout(() => setToast(''), 2800);
  }

  function recordOperation(operation) {
    const product = products.find((item) => item.id === operation.productId);
    const qty = Number(operation.quantity);
    if (!product || !Number.isFinite(qty) || qty <= 0) return notify('Enter a valid product quantity.');
    if (operation.type === 'Delivery' && qty > product.quantity) return notify('There is not enough stock for this delivery.');
    let updated = products.map((item) => ({ ...item }));
    const selected = updated.find((item) => item.id === product.id);
    if (operation.type === 'Receipt') selected.quantity += qty;
    if (operation.type === 'Delivery') selected.quantity -= qty;
    if (operation.type === 'Adjustment') selected.quantity = qty;
    if (operation.type === 'Transfer') {
      selected.location = operation.toLocation || selected.location;
      selected.warehouse = operation.toLocation === 'Warehouse 2' ? 'Warehouse 2' : 'Main Warehouse';
    }
    const move = {
      id: `MV-${Date.now().toString().slice(-6)}`, type: operation.type, product: product.name,
      sku: product.sku, quantity: qty, location: operation.type === 'Transfer' ? (operation.toLocation || product.location) : (operation.location || product.location),
      toLocation: operation.toLocation || '', reference: operation.reference || `${operation.type.toUpperCase()}-${Date.now().toString().slice(-4)}`,
      time: 'Just now', status: 'Done',
    };
    const nextMoves = [move, ...moves].slice(0, 8);
    setProducts(updated); setMoves(nextMoves); saveInventory({ products: updated, moves: nextMoves });
    if (database) import('./db.js').then(({ persistMovement }) => persistMovement(operation, product)).catch((error) => console.error('Could not save stock movement.', error));
    setModal(''); notify(`${operation.type} recorded for ${product.name}.`);
  }

  function addProduct(product) {
    const nextProducts = [{ ...product, id: `p-${Date.now()}` }, ...products];
    setProducts(nextProducts); saveInventory({ products: nextProducts, moves }); setModal(''); notify('Product added to inventory.');
    if (database) import('./db.js').then(({ persistProduct }) => persistProduct(product)).catch((error) => console.error('Could not save product.', error));
  }

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><div className="brand-mark"><Boxes size={19} strokeWidth={2.3} /></div><span>stocksense</span><span className="brand-dot">.</span></div>
      <div className="workspace"><div className="workspace-icon"><Warehouse size={17} /></div><div><strong>Northstar Goods</strong><span>Workspace</span></div><ChevronDown size={15} className="workspace-chevron" /></div>
      <div className="nav-label">WORKSPACE</div>
      <nav className="nav-list">
        <button className="nav-item active"><LayoutDashboard size={17} />Dashboard</button>
        <button className="nav-item" onClick={() => document.getElementById('products')?.scrollIntoView({ behavior: 'smooth' })}><Package size={17} />Products<span className="nav-count">{products.length}</span></button>
        <button className="nav-item" onClick={() => setModal('operation')}><ArrowLeftRight size={17} />Operations</button>
        <button className="nav-item" onClick={() => setFilter('All products')}><Activity size={17} />Move history</button>
      </nav>
      <div className="nav-label nav-label-spaced">MANAGE</div>
      <nav className="nav-list">
        <button className="nav-item" onClick={() => setModal('product')}><Plus size={17} />Add product</button>
        <button className="nav-item"><Warehouse size={17} />Warehouses</button>
        <button className="nav-item"><Settings size={17} />Settings</button>
      </nav>
      <div className="sidebar-bottom"><button className="nav-item"><CircleHelp size={17} />Help center</button>
        <div className="profile"><div className="avatar">JD</div><div className="profile-info"><strong>Jordan Davis</strong><span>Inventory manager</span></div><MoreHorizontal size={17} /></div>
      </div>
    </aside>

    <main className="main-content">
      <header className="topbar"><div className="breadcrumb"><span>Workspace</span><span className="crumb-divider">/</span><strong>Dashboard</strong></div><div className="topbar-right">
        <div className={`connection ${connected ? 'is-connected' : ''}`}><span />{connected ? 'Database connected' : 'Demo mode'}</div>
        <button className="icon-button" aria-label="Notifications"><Bell size={18} /><i /></button><div className="topbar-avatar">JD</div>
      </div></header>
      <div className="page-wrap">
        <div className="page-heading"><div><div className="eyebrow"><Sparkles size={13} /> MONDAY, SEPTEMBER 23, 2024</div><h1>Good morning, Jordan <span>✳</span></h1><p>Here’s what’s happening across your inventory today.</p></div>
          <div className="heading-actions"><button className="button button-secondary" onClick={() => notify('Report export is ready in the full app.')}><Download size={15} />Export report</button><button className="button button-primary" onClick={() => setModal('operation')}><Plus size={17} />New operation</button></div>
        </div>
        <section className="stats-grid">
          <StatCard label="Total units in stock" value={money(totalUnits)} change="Across all locations" icon={Boxes} tone="blue" />
          <StatCard label="Low stock items" value={String(lowStock).padStart(2, '0')} change={lowStock ? `${lowStock} need a restock` : 'All levels looking good'} icon={Activity} tone="amber" warning={lowStock > 0} />
          <StatCard label="Pending receipts" value="04" change="2 arriving today" icon={ArrowDownLeft} tone="green" />
          <StatCard label="Pending deliveries" value="07" change="3 scheduled today" icon={Truck} tone="violet" />
        </section>

        <section className="content-grid">
          <div className="panel product-panel" id="products">
            <div className="panel-heading"><div><h2>Inventory overview</h2><p>Keep track of your products and stock levels.</p></div><button className="button button-small button-secondary" onClick={() => setModal('product')}><Plus size={15} />Add product</button></div>
            <div className="table-toolbar"><div className="search-box"><Search size={16} /><input placeholder="Search products or SKU..." value={query} onChange={(event) => setQuery(event.target.value)} /><kbd>⌘ K</kbd></div><select aria-label="Filter products" value={filter} onChange={(event) => setFilter(event.target.value)}><option>All products</option><option>Low stock</option>{[...new Set(products.map((product) => product.category))].map((category) => <option key={category}>{category}</option>)}</select><button className="filter-button"><ListFilter size={15} />Filter</button></div>
            <div className="table-scroll"><table><thead><tr><th>PRODUCT</th><th>SKU</th><th>CATEGORY</th><th>LOCATION</th><th>IN STOCK</th><th>STATUS</th><th></th></tr></thead><tbody>{visibleProducts.map((product) => <tr key={product.id}>
              <td><div className="product-cell"><div className={`product-thumb ${product.color}`}>{product.symbol}</div><strong>{product.name}</strong></div></td><td className="muted-cell">{product.sku}</td><td><span className="category-pill">{product.category}</span></td><td><span className="location-cell"><MapPin size={13} />{product.location}</span></td><td><strong>{money(product.quantity)}</strong><span className="uom"> {product.unit}</span></td><td><StockStatus product={product} /></td><td><button className="row-more" aria-label={`More actions for ${product.name}`}><MoreHorizontal size={17} /></button></td>
            </tr>)}</tbody></table>{visibleProducts.length === 0 && <div className="empty-state">No products match your search.</div>}</div>
            <div className="table-footer"><span>Showing <strong>{visibleProducts.length}</strong> of <strong>{products.length}</strong> products</span><button className="text-button" onClick={() => setFilter('All products')}>View all products <ArrowRight size={14} /></button></div>
          </div>

          <div className="side-panels">
            <div className="panel activity-panel"><div className="panel-heading compact"><div><h2>Recent activity</h2><p>Latest stock movements</p></div><button className="row-more"><MoreHorizontal size={17} /></button></div>
              <div className="activity-list">{moves.slice(0, 5).map((move) => { const MoveIcon = iconByType[move.type] || Activity; return <div className="activity-item" key={move.id}><div className={`activity-icon ${move.type.toLowerCase()}`}><MoveIcon size={15} /></div><div className="activity-copy"><div><strong>{move.type}</strong><span className="activity-time">{move.time}</span></div><p>{move.product} <span>· {move.reference}</span></p><div className="activity-qty"><span className={move.type === 'Delivery' ? 'qty-negative' : move.type === 'Receipt' ? 'qty-positive' : ''}>{move.type === 'Delivery' ? '−' : move.type === 'Receipt' ? '+' : '↔'}{money(move.quantity)} {products.find((p) => p.name === move.product)?.unit || 'units'}</span><span>· {move.location}</span></div></div></div>; })}</div>
              <button className="activity-footer" onClick={() => notify('You’re viewing the latest movements.')}>View all activity <ArrowRight size={14} /></button>
            </div>
            {showRestockAlert && <div className="restock-card"><div className="restock-icon"><Bell size={17} /></div><div className="restock-copy"><strong>Stock needs attention</strong><p>{lowStock} products are at or below their minimum level.</p><button onClick={() => setFilter('Low stock')}>Review low stock <ArrowRight size={14} /></button></div><button className="restock-close" aria-label="Dismiss stock alert" onClick={() => setShowRestockAlert(false)}><X size={15} /></button></div>}
          </div>
        </section>
        <section className="quick-actions"><div><span className="quick-kicker">QUICK ACTIONS</span><strong>What would you like to do?</strong></div><div className="quick-action-buttons"><QuickAction icon={ArrowDownLeft} label="Receive stock" tone="green" onClick={() => setModal('Receipt')} /><QuickAction icon={ArrowUpRight} label="Deliver order" tone="orange" onClick={() => setModal('Delivery')} /><QuickAction icon={ArrowLeftRight} label="Transfer stock" tone="blue" onClick={() => setModal('Transfer')} /><QuickAction icon={SlidersHorizontal} label="Adjust inventory" tone="purple" onClick={() => setModal('Adjustment')} /></div></section>
        <footer className="page-footer"><span>StockSense <span className="footer-dot">●</span> Inventory made clear.</span><span><span className="footer-live"><i />All systems operational</span><span className="footer-separator">·</span>Last synced just now</span></footer>
      </div>
    </main>
    {modal && <OperationModal type={modal} products={products} onClose={() => setModal('')} onSubmit={modal === 'product' ? addProduct : recordOperation} />}
    {toast && <div className="toast"><Check size={16} />{toast}</div>}
  </div>;
}

function StatCard({ label, value, change, icon: Icon, tone, warning }) { return <div className="stat-card"><div className="stat-top"><span>{label}</span><div className={`stat-icon ${tone}`}><Icon size={17} /></div></div><div className="stat-value">{value}</div><div className={`stat-change ${warning ? 'warning' : ''}`}><span className="change-indicator">{warning ? '!' : '↗'}</span>{change}</div></div>; }
function StockStatus({ product }) { const status = product.quantity === 0 ? 'Out of stock' : product.quantity <= product.minimum ? 'Low stock' : 'In stock'; return <span className={`status-pill ${status.toLowerCase().replaceAll(' ', '-')}`}><i />{status}</span>; }
function QuickAction({ icon: Icon, label, tone, onClick }) { return <button className="quick-action" onClick={onClick}><span className={`quick-icon ${tone}`}><Icon size={16} /></span>{label}<ArrowRight size={14} className="quick-arrow" /></button>; }

function OperationModal({ type, products, onClose, onSubmit }) {
  const isProduct = type === 'product';
  const [form, setForm] = useState({ type: type === 'operation' ? 'Receipt' : type, productId: products[0]?.id || '', quantity: '', location: products[0]?.location || 'Main Warehouse', toLocation: 'Production Floor', reference: '' });
  const update = (key) => (event) => setForm((current) => ({ ...current, [key]: event.target.value }));
  const submit = (event) => { event.preventDefault(); onSubmit(form); };
  return <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}><form className="modal" onSubmit={submit}>
    <div className="modal-heading"><div><span className="modal-icon"><Package size={17} /></span><div><h2>{isProduct ? 'Add a product' : `New ${form.type.toLowerCase()}`}</h2><p>{isProduct ? 'Add a product to your inventory catalog.' : 'Record a stock movement in your ledger.'}</p></div></div><button type="button" className="icon-button" onClick={onClose}><X size={18} /></button></div>
    {isProduct ? <>
      <label>Product name<input required placeholder="e.g. Steel Rods" value={form.name || ''} onChange={update('name')} /></label>
      <div className="form-row"><label>SKU / code<input required placeholder="STL-001" value={form.sku || ''} onChange={update('sku')} /></label><label>Category<select value={form.category || 'Materials'} onChange={update('category')}><option>Materials</option><option>Components</option><option>Finished goods</option><option>Packaging</option></select></label></div>
      <div className="form-row"><label>Initial stock<input type="number" min="0" step="any" value={form.quantity || ''} onChange={update('quantity')} placeholder="0" /></label><label>Unit<select value={form.unit || 'units'} onChange={update('unit')}><option>units</option><option>kg</option><option>litres</option><option>metres</option></select></label></div>
      <label>Location<select value={form.location || 'Main Warehouse'} onChange={update('location')}><option>Main Warehouse</option><option>Production Floor</option><option>Warehouse 2</option><option>Rack A</option></select></label>
      <input type="hidden" value={form.minimum || '20'} onChange={update('minimum')} />
    </> : <>
      <div className="form-row"><label>Operation type<select value={form.type} onChange={update('type')}><option>Receipt</option><option>Delivery</option><option>Transfer</option><option>Adjustment</option></select></label><label>Product<select value={form.productId} onChange={update('productId')}>{products.map((product) => <option value={product.id} key={product.id}>{product.name} · {product.sku}</option>)}</select></label></div>
      <div className="form-row"><label>{form.type === 'Adjustment' ? 'Counted quantity' : 'Quantity'}<input type="number" min="0.01" step="any" required placeholder="Enter quantity" value={form.quantity} onChange={update('quantity')} /></label><label>Reference<input placeholder="Optional reference" value={form.reference} onChange={update('reference')} /></label></div>
      <div className="form-row"><label>{form.type === 'Delivery' ? 'Source location' : 'Location'}<select value={form.location} onChange={update('location')}><option>Main Warehouse</option><option>Production Floor</option><option>Warehouse 2</option><option>Rack A</option></select></label>{form.type === 'Transfer' && <label>Destination<select value={form.toLocation} onChange={update('toLocation')}><option>Production Floor</option><option>Main Warehouse</option><option>Warehouse 2</option><option>Rack A</option></select></label>}</div>
      {form.type === 'Transfer' && <p className="modal-hint"><ArrowLeftRight size={14} />Stock stays in the company total; its location changes.</p>}
      {form.type === 'Adjustment' && <p className="modal-hint"><Clock3 size={14} />This prototype records the count for the ledger. Variance posting is a follow-up workflow.</p>}
    </>}
    <div className="modal-actions"><button type="button" className="button button-secondary" onClick={onClose}>Cancel</button><button type="submit" className="button button-primary">{isProduct ? 'Add product' : 'Record movement'}<ArrowRight size={15} /></button></div>
  </form></div>;
}
