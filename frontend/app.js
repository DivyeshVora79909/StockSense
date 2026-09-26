import { Surreal } from "https://esm.sh/surrealdb@2.0.8";

const state = {
  config: null, db: null, team: null, userName: "", page: "dashboard",
  products: [], categories: [], units: [], warehouses: [], locations: [],
  positions: [], operations: [], history: [],
  operationKind: "receipt", editingOperation: null, filters: { status: "", location: "", category: "", search: "" },
};
const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const idText = value => value == null ? "" : String(value);
const clean = value => value == null ? "" : String(value);
const kindLabel = { receipt: "Receipt", delivery: "Delivery", transfer: "Internal transfer", adjustment: "Adjustment" };
const statuses = ["draft", "waiting", "ready", "done", "canceled"];

function lastResult(response) {
  const last = Array.isArray(response) ? response.at(-1) : response;
  if (last && typeof last === "object" && Object.hasOwn(last, "result")) return last.result;
  return last;
}
async function query(sql, vars = {}) { return lastResult(await state.db.query(sql, vars)); }
async function select(sql, vars = {}) { const value = await query(sql, vars); return Array.isArray(value) ? value : value == null ? [] : [value]; }
function escapeHtml(value) { return String(value ?? "").replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]); }
function amount(value, digits = 2) { return new Intl.NumberFormat(undefined, { maximumFractionDigits: digits }).format(Number(value ?? 0)); }
function toast(message, error = false) {
  const node = $("#toast"); node.textContent = message; node.classList.toggle("error", error); node.classList.remove("hidden");
  clearTimeout(toast.timer); toast.timer = setTimeout(() => node.classList.add("hidden"), 3500);
}
function authMessage(message = "", error = false) {
  const node = error ? $("#auth-error") : $("#auth-notice");
  const other = error ? $("#auth-notice") : $("#auth-error");
  other.classList.add("hidden"); node.textContent = message; node.classList.toggle("hidden", !message);
}
function switchAuth(name) {
  $$(".auth-form").forEach(form => form.classList.add("hidden"));
  $$(".auth-tab").forEach(tab => tab.classList.toggle("active", tab.dataset.authTab === name));
  $(`#${name}-form`)?.classList.remove("hidden"); authMessage();
}
async function loadConfig() {
  const response = await fetch("./runtime.json", { cache: "no-store" });
  if (!response.ok) throw new Error("Could not load frontend/runtime.json");
  state.config = await response.json();
  const saved = JSON.parse(localStorage.getItem("stocksense.config") || "null");
  if (saved) state.config = { ...state.config, ...saved };
}
async function connect() {
  if (!state.db) {
    state.db = new Surreal();
    await state.db.connect(state.config.url);
    await state.db.use({ namespace: state.config.namespace, database: state.config.database });
  }
}
function busy(form, yes) { const button = $("button[type=submit]", form); if (button) { button.disabled = yes; button.classList.toggle("opacity-60", yes); } }

async function onLogin(event) {
  event.preventDefault(); const form = event.currentTarget; busy(form, true); authMessage();
  try {
    await connect(); const data = new FormData(form);
    await state.db.signin({ access: "account_password", variables: { identifier: data.get("identifier"), password: data.get("password") } });
    await showApp();
  } catch (error) { authMessage(error.message || "Login failed. Check your username and password.", true); }
  finally { busy(form, false); }
}
async function onSignup(event) {
  event.preventDefault(); const form = event.currentTarget; busy(form, true); authMessage();
  try {
    await connect(); const data = new FormData(form); const identifier = String(data.get("identifier")).trim().toLowerCase();
    await state.db.signup({ access: "stocksense_signup", variables: {
      identifier, email: data.get("email"), name: data.get("name"), workspace: data.get("workspace"), password: data.get("password"),
    } });
    await state.db.close(); state.db = null;
    localStorage.setItem("stocksense.pending", JSON.stringify({ identifier, email: data.get("email"), name: data.get("name") }));
    $("#verify-form [name=identifier]").value = data.get("email"); switchAuth("verify");
    authMessage("Account created. Check your email for the verification code.");
  } catch (error) { authMessage(error.message || "Account could not be created.", true); }
  finally { busy(form, false); }
}
async function onVerify(event) {
  event.preventDefault(); const form = event.currentTarget; busy(form, true); authMessage();
  try {
    await connect(); const data = new FormData(form);
    await state.db.signin({ access: "account_code", variables: { identifier: data.get("identifier"), code: data.get("code"), password_action: "keep" } });
    localStorage.removeItem("stocksense.pending"); await showApp();
  } catch (error) { authMessage(error.message || "Code verification failed.", true); }
  finally { busy(form, false); }
}
async function onReset(event) {
  event.preventDefault(); const form = event.currentTarget; const data = new FormData(form); busy(form, true); authMessage();
  try {
    await connect();
    if (!data.get("code")) {
      try { await state.db.signin({ access: "stocksense_recovery", variables: { identifier: data.get("identifier") } }); } catch {}
      authMessage("If that email belongs to an account, a reset code has been sent. Check your inbox.");
      $("#reset-form [name=code]").focus(); return;
    }
    await state.db.signin({ access: "account_code", variables: {
      identifier: data.get("identifier"), code: data.get("code"),
      password_action: "set", new_password: data.get("new_password"),
    } });
    await showApp();
  } catch (error) { authMessage(error.message || "Password reset failed.", true); }
  finally { busy(form, false); }
}

async function showApp() {
  localStorage.setItem("stocksense.lastUser", String((await query("RETURN $auth.name;")) || "StockSense user"));
  const context = await query("LET $team = (SELECT name FROM rebase_group WHERE id = $auth.parents[0])[0]; RETURN { team: $auth.parents[0], workspace: $team.name, user: $auth.name };");
  state.team = context?.team; state.userName = String(context?.user || localStorage.getItem("stocksense.lastUser"));
  if (!state.team) throw new Error("Your account has no StockSense workspace. Contact your workspace administrator.");
  $("#workspace-name").textContent = context?.workspace || "Your workspace";
  $("#profile-name").textContent = state.userName;
  $("#auth-view").classList.add("hidden"); $("#app-view").classList.remove("hidden");
  await refresh();
  if (!state.warehouses.length) showSetupHint();
}
function showSetupHint() {
  state.page = "locations"; renderNav(); renderPage();
  toast("Start by adding a warehouse and a storage location.");
}
async function logout() {
  await state.db?.close().catch(() => {}); state.db = null; state.team = null;
  $("#app-view").classList.add("hidden"); $("#auth-view").classList.remove("hidden"); switchAuth("login");
}

async function refresh() {
  $("#sync-state").textContent = "Syncing";
  try {
    const [products, categories, units, warehouses, locations, positions, operations] = await Promise.all([
      select("SELECT * FROM product ORDER BY name;"), select("SELECT * FROM product_category ORDER BY name;"),
      select("SELECT * FROM unit_of_measure ORDER BY name;"), select("SELECT * FROM warehouse ORDER BY name;"),
      select("SELECT * FROM stock_location ORDER BY name;"), select("SELECT * FROM stock_position;"),
      select("SELECT * FROM stock_operation ORDER BY updated_at DESC LIMIT 250;"),
    ]);
    Object.assign(state, { products, categories, units, warehouses, locations, positions, operations });
    renderNav(); renderPage(); $("#sync-state").textContent = "Up to date";
  } catch (error) { $("#sync-state").textContent = "Sync issue"; toast(error.message || "Could not load inventory.", true); }
}
function renderNav() {
  $$(".nav-item[data-page]").forEach(button => button.classList.toggle("active", button.dataset.page === state.page));
  const titles = { dashboard: "Dashboard", products: "Products", receipts: "Receipts", deliveries: "Delivery orders", transfers: "Internal transfers", adjustments: "Inventory adjustments", history: "Move history", locations: "Warehouses & locations" };
  $("#page-title").textContent = titles[state.page] || "Dashboard";
  $("#quick-create").classList.toggle("hidden", state.page === "products" || state.page === "locations" || state.page === "history");
}
const productBalance = product => Number(product.z_stock?.summary?.measures?.quantity?.sum || 0);
const locationBalance = location => Number(location.z_stock?.summary?.measures?.quantity?.sum || 0);
const positionBalance = position => Number(position.z_stock?.summary?.measures?.quantity?.sum || 0);
const productById = id => state.products.find(product => idText(product.id) === idText(id));
const locationById = id => state.locations.find(location => idText(location.id) === idText(id));
const categoryById = id => state.categories.find(category => idText(category.id) === idText(id));
function statusPill(status) { return `<span class="status status-${escapeHtml(status)}">${escapeHtml(status)}</span>`; }
function pageToolbar({ search = true, status = true, location = true, category = false } = {}) {
  return `<div class="toolbar">${search ? `<input class="search" data-filter="search" placeholder="Search by name, SKU or reference" value="${escapeHtml(state.filters.search)}">` : ""}${status ? `<select data-filter="status"><option value="">All statuses</option>${statuses.map(x => `<option value="${x}" ${state.filters.status === x ? "selected" : ""}>${x[0].toUpperCase()}${x.slice(1)}</option>`).join("")}</select>` : ""}${location ? locationFilter() : ""}${category ? `<select data-filter="category"><option value="">All categories</option>${state.categories.map(x => `<option value="${escapeHtml(idText(x.id))}" ${idText(x.id) === state.filters.category ? "selected" : ""}>${escapeHtml(x.name)}</option>`).join("")}</select>` : ""}</div>`;
}
function locationFilter() { return `<select data-filter="location"><option value="">All locations</option>${state.locations.map(x => `<option value="${escapeHtml(idText(x.id))}" ${idText(x.id) === state.filters.location ? "selected" : ""}>${escapeHtml(x.name)}</option>`).join("")}</select>`; }
function filteredProducts() {
  const search = state.filters.search.toLowerCase();
  return state.products.filter(row => (!search || `${row.name} ${row.sku}`.toLowerCase().includes(search))
    && (!state.filters.category || idText(row.category) === state.filters.category));
}
function filteredOperations(kind) {
  const search = state.filters.search.toLowerCase();
  return state.operations.filter(row => row.kind === kind
    && (!state.filters.status || row.status === state.filters.status)
    && (!state.filters.location || [row.location, row.from_location, row.to_location].some(id => idText(id) === state.filters.location))
    && (!search || `${row.reference || ""} ${row.party_name || ""} ${row.lines?.map(line => productById(line.product)?.name || "").join(" ") || ""}`.toLowerCase().includes(search)));
}
function renderDashboard() {
  const inStock = state.products.filter(product => productBalance(product) > 0).length;
  const low = state.products.filter(product => productBalance(product) <= Number(product.reorder_point || 0)).length;
  const countKind = (kind, statusesNeeded = ["draft", "waiting", "ready"]) => state.operations.filter(row => row.kind === kind && statusesNeeded.includes(row.status)).length;
  const scheduled = state.operations.filter(row => row.kind === "transfer" && ["waiting", "ready"].includes(row.status)).length;
  const recent = [...state.operations].slice(0, 7);
  return `<div class="kpi-grid">
    ${kpi("Total products in stock", inStock, "package-check", "Products with available quantity")}
    ${kpi("Low / out of stock", low, "triangle-alert", "At or below reorder point")}
    ${kpi("Pending receipts", countKind("receipt"), "package-plus", "Draft, waiting or ready")}
    ${kpi("Pending deliveries", countKind("delivery"), "truck", "Draft, waiting or ready")}
    ${kpi("Transfers scheduled", scheduled, "arrow-left-right", "Waiting or ready to move")}
  </div>
  <div class="section-head"><h2>Recent operations</h2><span class="small-muted">Latest 7 documents</span></div>
  <div class="table-card">${recent.length ? operationsTable(recent) : empty("No operations yet. Create a receipt to start recording stock.")}</div>
  <div class="section-head"><h2>Stock by location</h2><button class="action-link" data-go="products">View products</button></div>
  <div class="locations-grid">${state.locations.map(location => `<article class="location-card"><h3>${escapeHtml(location.name)}</h3><p>${escapeHtml(location.warehouse?.name || warehouseName(location.warehouse))}</p><div class="mt-4 text-2xl font-semibold">${amount(locationBalance(location), 3)}</div><div class="small-muted">units on hand</div></article>`).join("") || empty("Add a warehouse and location to begin.")}</div>`;
}
function kpi(label, value, icon, note) { return `<article class="kpi-card"><div class="kpi-head"><span>${label}</span><span class="kpi-icon"><i data-lucide="${icon}"></i></span></div><div class="kpi-value">${amount(value, 0)}</div><p class="kpi-note">${note}</p></article>`; }
function renderProducts() {
  const products = filteredProducts();
  const table = `<div class="table-card"><table class="data-table"><thead><tr><th>Product</th><th>SKU</th><th>Category</th><th>Unit</th><th>On hand</th><th>Reorder at</th><th></th></tr></thead><tbody>${products.map(product => {
    const low = productBalance(product) <= Number(product.reorder_point || 0);
    return `<tr><td><strong>${escapeHtml(product.name)}</strong></td><td>${escapeHtml(product.sku)}</td><td>${escapeHtml(categoryById(product.category)?.name || "—")}</td><td>${escapeHtml(product.unit?.name || unitName(product.unit))}</td><td><span class="${low ? "text-amber-700 font-semibold" : "font-medium"}">${amount(productBalance(product), 3)}</span></td><td>${amount(product.reorder_point, 3)}</td><td><button class="action-link" data-edit-product="${escapeHtml(idText(product.id))}">Edit</button> <button class="action-link text-rose-700" data-delete-product="${escapeHtml(idText(product.id))}">Delete</button></td></tr>`;
  }).join("")}</tbody></table>${products.length ? "" : empty("No products match these filters.")}</div>`;
  return `<div class="section-head mt-0"><div><h2>Product catalogue</h2><p class="small-muted mt-1">Stock is calculated from validated operations.</p></div><div class="flex gap-2"><button class="secondary" data-add-category><i data-lucide="tags"></i> Category</button><button class="primary" data-add-product><i data-lucide="plus"></i> Add product</button></div></div>${pageToolbar({ status: false, category: true })}${table}`;
}
function renderOperations(kind) {
  const rows = filteredOperations(kind); const title = kindLabel[kind];
  return `<div class="section-head mt-0"><div><h2>${title} board</h2><p class="small-muted mt-1">Create, stage and validate ${title.toLowerCase()} documents.</p></div><div class="flex items-center gap-2"><button class="secondary" data-toggle-view="table">List</button><button class="secondary" data-toggle-view="kanban">Kanban</button><button class="primary" data-new-operation="${kind}"><i data-lucide="plus"></i> New ${title.toLowerCase()}</button></div></div>${pageToolbar({ category: true })}<div id="operations-board" data-mode="kanban">${kanban(rows)}</div>`;
}
function kanban(rows) {
  const boardStatuses = ["draft", "waiting", "ready", "done"];
  return `<div class="kanban">${boardStatuses.map(status => {
    const items = rows.filter(row => row.status === status);
    return `<section class="kanban-column"><h3>${status[0].toUpperCase()}${status.slice(1)}<span class="small-muted">${items.length}</span></h3>${items.map(row => operationCard(row)).join("")}${items.length ? "" : `<div class="small-muted px-2 py-3">Nothing here</div>`}</section>`;
  }).join("")}</div>`;
}
function operationCard(row) {
  const lines = row.lines?.length || 0; const location = row.kind === "transfer" ? `${locationName(row.from_location)} → ${locationName(row.to_location)}` : locationName(row.location);
  return `<article class="kanban-card"><div class="flex justify-between gap-2"><strong>${escapeHtml(row.reference || kindLabel[row.kind])}</strong>${statusPill(row.status)}</div><p>${escapeHtml(location)} · ${lines} line${lines === 1 ? "" : "s"}</p><p>${escapeHtml(row.party_name || row.effective_at || "")}</p><div class="card-actions">${row.status !== "done" ? `<button class="action-link" data-edit-operation="${escapeHtml(idText(row.id))}">Edit</button>${row.status === "draft" || row.status === "waiting" ? `<button class="action-link" data-status-operation="${escapeHtml(idText(row.id))}" data-status="ready">Mark ready</button>` : ""}${row.status === "ready" ? `<button class="action-link" data-status-operation="${escapeHtml(idText(row.id))}" data-status="done">Validate</button>` : ""}<button class="action-link text-rose-700" data-delete-operation="${escapeHtml(idText(row.id))}">Delete</button>` : "<span class='small-muted'>Posted to stock ledger</span>"}</div></article>`;
}
function operationsTable(rows) {
  return `<table class="data-table"><thead><tr><th>Reference</th><th>Type</th><th>Date</th><th>Location</th><th>Lines</th><th>Status</th><th>Actions</th></tr></thead><tbody>${rows.map(row => `<tr><td><strong>${escapeHtml(row.reference || "—")}</strong></td><td>${escapeHtml(kindLabel[row.kind])}</td><td>${dateText(row.effective_at)}</td><td>${escapeHtml(row.kind === "transfer" ? `${locationName(row.from_location)} → ${locationName(row.to_location)}` : locationName(row.location))}</td><td>${row.lines?.length || 0}</td><td>${statusPill(row.status)}</td><td>${operationActions(row)}</td></tr>`).join("")}</tbody></table>`;
}
function operationActions(row) {
  if (row.status === "done") return `<span class="small-muted">Posted</span>`;
  return `<button class="action-link" data-edit-operation="${escapeHtml(idText(row.id))}">Edit</button> <button class="action-link text-rose-700" data-delete-operation="${escapeHtml(idText(row.id))}">Delete</button> ${row.status === "ready" ? `<button class="action-link" data-status-operation="${escapeHtml(idText(row.id))}" data-status="done">Validate</button>` : `<button class="action-link" data-status-operation="${escapeHtml(idText(row.id))}" data-status="ready">Mark ready</button>`}`;
}
function renderHistory() {
  return `<div class="section-head mt-0"><div><h2>Stock ledger</h2><p class="small-muted mt-1">Every validated receipt, delivery, transfer and count.</p></div></div><div class="toolbar"><select id="history-kind"><option value="">All document types</option><option value="receipt">Receipts</option><option value="delivery">Deliveries</option><option value="transfer">Internal transfers</option><option value="adjustment">Adjustments</option></select><select id="history-location"><option value="">All locations</option>${state.locations.map(x => `<option value="${escapeHtml(idText(x.id))}">${escapeHtml(x.name)}</option>`).join("")}</select><select id="history-product"><option value="">All products</option>${state.products.map(x => `<option value="${escapeHtml(idText(x.id))}">${escapeHtml(x.name)}</option>`).join("")}</select><button class="secondary" id="load-history"><i data-lucide="filter"></i> Apply filters</button></div><div id="history-results" class="table-card">${empty("Load recent stock moves.")}</div>`;
}
function renderLocations() {
  return `<div class="section-head mt-0"><div><h2>Warehouses & locations</h2><p class="small-muted mt-1">Organize physical storage areas and see on-hand totals.</p></div><div class="flex gap-2"><button class="secondary" data-add-warehouse><i data-lucide="plus"></i> Warehouse</button><button class="primary" data-add-location><i data-lucide="plus"></i> Location</button></div></div><div class="locations-grid">${state.locations.map(location => `<article class="location-card"><div class="flex items-start justify-between"><div><h3>${escapeHtml(location.name)}</h3><p>${escapeHtml(warehouseName(location.warehouse))} · ${escapeHtml(location.code)}</p></div><button class="action-link" data-edit-location="${escapeHtml(idText(location.id))}">Edit</button></div><div class="mt-5 text-2xl font-semibold">${amount(locationBalance(location), 3)}</div><div class="small-muted">units on hand</div><p class="mt-4">${location.active ? "Active" : "Inactive"}</p></article>`).join("")}</div>${state.warehouses.length ? `<div class="section-head"><h2>Warehouses</h2></div><div class="table-card"><table class="data-table"><thead><tr><th>Name</th><th>Code</th><th>Locations</th><th>Status</th><th></th></tr></thead><tbody>${state.warehouses.map(row => `<tr><td>${escapeHtml(row.name)}</td><td>${escapeHtml(row.code)}</td><td>${state.locations.filter(x => idText(x.warehouse) === idText(row.id)).length}</td><td>${row.active ? "Active" : "Inactive"}</td><td><button class="action-link" data-edit-warehouse="${escapeHtml(idText(row.id))}">Edit</button></td></tr>`).join("")}</tbody></table></div>` : empty("Create your first warehouse.")}`;
}
function renderPage() {
  const content = $("#page-content");
  if (state.page === "dashboard") content.innerHTML = renderDashboard();
  else if (state.page === "products") content.innerHTML = renderProducts();
  else if (["receipts", "deliveries", "transfers", "adjustments"].includes(state.page)) {
    const kind = ({ receipts: "receipt", deliveries: "delivery", transfers: "transfer", adjustments: "adjustment" })[state.page]; content.innerHTML = renderOperations(kind);
  } else if (state.page === "history") content.innerHTML = renderHistory();
  else content.innerHTML = renderLocations();
  lucide.createIcons();
}
function empty(message) { return `<div class="empty-state">${escapeHtml(message)}</div>`; }
function warehouseName(id) { return state.warehouses.find(row => idText(row.id) === idText(id))?.name || String(id || "—"); }
function locationName(id) { return state.locations.find(row => idText(row.id) === idText(id))?.name || String(id || "—"); }
function unitName(id) { return state.units.find(row => idText(row.id) === idText(id))?.name || String(id || "—"); }
function dateText(value) { if (!value) return "—"; const date = new Date(value); return Number.isNaN(date.valueOf()) ? String(value).slice(0, 16) : date.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }); }

function addLine(line = null) {
  const row = document.createElement("div"); row.className = "line-row";
  const options = state.products.map(product => `<option value="${escapeHtml(idText(product.id))}" ${line && idText(line.product) === idText(product.id) ? "selected" : ""}>${escapeHtml(product.name)} · ${escapeHtml(product.sku)}</option>`).join("");
  const fieldName = state.operationKind === "adjustment" ? "counted_quantity" : "quantity";
  const qty = line?.[fieldName] ?? "";
  row.innerHTML = `<select name="product" required><option value="">Choose a product</option>${options}</select><input name="${fieldName}" type="number" min="${fieldName === "quantity" ? "0.001" : "0"}" step="any" value="${escapeHtml(qty)}" placeholder="${fieldName === "quantity" ? "Quantity" : "Counted quantity"}" required><button type="button" aria-label="Remove line"><i data-lucide="x"></i></button>`;
  $("#operation-lines").append(row); $("button", row).addEventListener("click", () => row.remove()); lucide.createIcons();
}
function syncOperationForm() {
  const kind = $("#operation-form [name=kind]").value; state.operationKind = kind;
  $(".location-field").classList.toggle("hidden", kind === "transfer");
  $(".from-location-field").classList.toggle("hidden", kind !== "transfer");
  $(".to-location-field").classList.toggle("hidden", kind !== "transfer");
  $(".party-field").classList.toggle("hidden", !["receipt", "delivery"].includes(kind));
  $("#quantity-heading").textContent = kind === "adjustment" ? "Counted quantity" : "Quantity";
  const lines = $$(".line-row").map(row => ({ product: $("[name=product]", row).value, quantity: $("[name=quantity]", row)?.value, counted_quantity: $("[name=counted_quantity]", row)?.value }));
  $("#operation-lines").innerHTML = ""; lines.filter(line => line.product).forEach(line => addLine({ product: line.product, [kind === "adjustment" ? "counted_quantity" : "quantity"]: line[kind === "adjustment" ? "counted_quantity" : "quantity"] }));
  if (!$("#operation-lines").children.length) addLine();
}
function setSelectOptions(select, rows, selected = "", first = "Choose…") {
  select.innerHTML = `<option value="">${first}</option>${rows.map(row => `<option value="${escapeHtml(idText(row.id))}" ${idText(row.id) === idText(selected) ? "selected" : ""}>${escapeHtml(row.name)}${row.code ? ` · ${escapeHtml(row.code)}` : ""}</option>`).join("")}`;
}
function openOperation(kind, row = null) {
  if (!state.products.length || !state.locations.length) { toast("Add a product and location first.", true); return; }
  state.operationKind = row?.kind || kind; state.editingOperation = row;
  const form = $("#operation-form"); form.reset(); form.elements.id.value = row ? idText(row.id) : "";
  form.elements.kind.value = state.operationKind; form.elements.reference.value = row?.reference || ""; form.elements.party_name.value = row?.party_name || "";
  form.elements.effective_at.value = row?.effective_at ? new Date(row.effective_at).toISOString().slice(0, 16) : new Date().toISOString().slice(0, 16);
  setSelectOptions(form.elements.location, state.locations, row?.location, "Select location");
  setSelectOptions(form.elements.from_location, state.locations, row?.from_location, "Select source");
  setSelectOptions(form.elements.to_location, state.locations, row?.to_location, "Select destination");
  $("#operation-heading").textContent = `${row ? "Edit" : "New"} ${kindLabel[state.operationKind].toLowerCase()}`;
  $("#operation-lines").innerHTML = ""; (row?.lines?.length ? row.lines : [null]).forEach(line => addLine(line));
  syncOperationVisibility(); $("#operation-error").classList.add("hidden"); $("#operation-dialog").showModal();
}
function syncOperationVisibility() {
  const kind = $("#operation-form [name=kind]").value; state.operationKind = kind;
  $(".location-field").classList.toggle("hidden", kind === "transfer"); $(".from-location-field").classList.toggle("hidden", kind !== "transfer");
  $(".to-location-field").classList.toggle("hidden", kind !== "transfer"); $(".party-field").classList.toggle("hidden", !["receipt", "delivery"].includes(kind));
  $("#quantity-heading").textContent = kind === "adjustment" ? "Counted quantity" : "Quantity";
  for (const row of $$(".line-row")) {
    const input = $("input", row); const want = kind === "adjustment" ? "counted_quantity" : "quantity";
    if (input.name !== want) { const value = input.value; input.name = want; input.min = want === "quantity" ? "0.001" : "0"; input.placeholder = want === "quantity" ? "Quantity" : "Counted quantity"; input.value = value; }
  }
}
async function ensurePosition(productId, locationId) {
  await query(`LET $pid = type::record('product', $product); LET $lid = type::record('stock_location', $location);
    UPSERT type::record('stock_position', [$pid, $lid]) SET owned_by = $team, product = $pid, location = $lid;`,
  { product: idText(productId).replace(/^product:/, ""), location: idText(locationId).replace(/^stock_location:/, ""), team: state.team });
}
async function ensureOperationPositions(data) {
  for (const line of data.lines) {
    const locations = data.kind === "transfer" ? [data.from_location, data.to_location] : [data.location];
    for (const location of locations) await ensurePosition(line.product, location);
  }
}
function formOperationData(form) {
  const data = new FormData(form); const kind = data.get("kind");
  const lines = $$(".line-row", form).map(row => {
    const product = $("[name=product]", row).value; const value = $("input", row).value;
    return kind === "adjustment" ? { line_key: crypto.randomUUID(), product: state.products.find(x => idText(x.id) === product)?.id, counted_quantity: Number(value) }
      : { line_key: crypto.randomUUID(), product: state.products.find(x => idText(x.id) === product)?.id, quantity: Number(value) };
  });
  if (state.editingOperation) {
    state.editingOperation.lines.forEach((oldLine, index) => { if (lines[index]) lines[index].line_key = oldLine.line_key; });
  }
  const locationValue = value => state.locations.find(x => idText(x.id) === value)?.id || null;
  return {
    kind, reference: data.get("reference") || null, party_name: data.get("party_name") || null,
    location: kind === "transfer" ? null : locationValue(data.get("location")),
    from_location: kind === "transfer" ? locationValue(data.get("from_location")) : null,
    to_location: kind === "transfer" ? locationValue(data.get("to_location")) : null,
    effective_at: new Date(data.get("effective_at")).toISOString(), lines,
  };
}
async function saveOperation(event, finalStatus = "draft") {
  event?.preventDefault(); const form = $("#operation-form"); const errorNode = $("#operation-error"); errorNode.classList.add("hidden");
  try {
    const data = formOperationData(form);
    if (!data.lines.length || data.lines.some(line => !line.product || (line.quantity != null ? line.quantity <= 0 : line.counted_quantity < 0))) throw new Error("Add valid product lines before saving.");
    await ensureOperationPositions(data);
    const vars = { team: state.team, ...data, status: finalStatus };
    const old = state.editingOperation;
    if (old) {
      await query(`UPDATE $id SET kind = $kind, reference = $reference, party_name = $party_name,
        location = $location, from_location = $from_location, to_location = $to_location,
        effective_at = type::datetime($effective_at), lines = $lines;`, { id: old.id, ...vars });
      if (finalStatus !== old.status) await query("UPDATE $id SET status = $status;", { id: old.id, status: finalStatus });
    } else {
      await query(`CREATE stock_operation CONTENT {
        owned_by: $team, kind: $kind, status: $status, reference: $reference, party_name: $party_name,
        location: $location, from_location: $from_location, to_location: $to_location,
        effective_at: type::datetime($effective_at), lines: $lines
      };`, vars);
    }
    $("#operation-dialog").close(); state.editingOperation = null; await refresh(); toast(finalStatus === "done" ? "Stock operation validated." : "Operation saved.");
  } catch (error) { errorNode.textContent = error.message; errorNode.classList.remove("hidden"); }
}

function openSimple(title, fields, onSave) {
  const form = $("#simple-form"); form.reset(); $("#simple-heading").textContent = title; $("#simple-fields").innerHTML = fields;
  $("#simple-error").classList.add("hidden"); $("#simple-dialog").showModal();
  form.onsubmit = async event => { event.preventDefault(); const error = $("#simple-error");
    try { await onSave(new FormData(form)); $("#simple-dialog").close(); await refresh(); }
    catch (exception) { error.textContent = exception.message; error.classList.remove("hidden"); }
  };
}
function openProduct(row = null) {
  const fields = `<label class="field">Product name<input name="name" value="${escapeHtml(row?.name || "")}" required></label><label class="field">SKU / code<input name="sku" value="${escapeHtml(row?.sku || "")}" ${row ? "readonly" : ""} required></label>
    <label class="field">Category<select name="category"><option value="">No category</option>${state.categories.map(x => `<option value="${escapeHtml(idText(x.id))}" ${idText(row?.category) === idText(x.id) ? "selected" : ""}>${escapeHtml(x.name)}</option>`).join("")}</select></label>
    <label class="field">Unit<select name="unit" ${row ? "disabled" : ""} required>${state.units.map(x => `<option value="${escapeHtml(idText(x.id))}" ${idText(row?.unit) === idText(x.id) ? "selected" : ""}>${escapeHtml(x.name)} (${escapeHtml(x.code)})</option>`).join("")}</select></label>
    <label class="field">Low-stock alert quantity<input name="reorder_point" type="number" min="0" step="any" value="${escapeHtml(row?.reorder_point || 0)}"></label>
    ${row ? "" : `<label class="field">Initial storage location<select name="initial_location"><option value="">No opening stock</option>${state.locations.map(x => `<option value="${escapeHtml(idText(x.id))}">${escapeHtml(x.name)}</option>`).join("")}</select></label><label class="field">Initial quantity<input name="initial_quantity" type="number" min="0" step="any" value="0"></label>`}`;
  openSimple(row ? "Edit product" : "Add product", fields, async data => {
    const vars = { team: state.team, name: data.get("name"), sku: data.get("sku"), category: state.categories.find(x => idText(x.id) === data.get("category"))?.id || null,
      unit: state.units.find(x => idText(x.id) === data.get("unit"))?.id, reorder: Number(data.get("reorder_point") || 0) };
    if (row) await query("UPDATE $id SET name=$name, category=$category, reorder_point=$reorder;", { id: row.id, ...vars });
    else {
      const created = await select(`CREATE product CONTENT { owned_by:$team, name:$name, sku:$sku, category:$category, unit:$unit, reorder_point:$reorder, active:true } RETURN AFTER;`, vars);
      const product = created[0]; const initial = Number(data.get("initial_quantity") || 0); const location = state.locations.find(x => idText(x.id) === data.get("initial_location"));
      if (initial > 0 && location) {
        await ensurePosition(product.id, location.id);
        const line = { line_key: crypto.randomUUID(), product: product.id, counted_quantity: initial };
        await query(`CREATE stock_operation CONTENT { owned_by:$team, kind:'adjustment', status:'done', reference:'Opening stock', location:$location,
          effective_at:time::now(), lines:$lines };`, { team: state.team, location: location.id, lines: [line] });
      }
    }
  });
}
function openWarehouse(row = null) {
  openSimple(row ? "Edit warehouse" : "Add warehouse", `<label class="field">Warehouse name<input name="name" value="${escapeHtml(row?.name || "")}" required></label><label class="field">Code<input name="code" value="${escapeHtml(row?.code || "")}" required></label>`, async data => {
    if (row) await query("UPDATE $id SET name=$name, code=$code;", { id: row.id, name: data.get("name"), code: data.get("code") });
    else await query("CREATE warehouse CONTENT { owned_by:$team, name:$name, code:$code, active:true };", { team: state.team, name: data.get("name"), code: data.get("code") });
  });
}
function openLocation(row = null) {
  const fields = `<label class="field">Warehouse<select name="warehouse" required>${state.warehouses.map(x => `<option value="${escapeHtml(idText(x.id))}" ${idText(row?.warehouse) === idText(x.id) ? "selected" : ""}>${escapeHtml(x.name)}</option>`).join("")}</select></label><label class="field">Location name<input name="name" value="${escapeHtml(row?.name || "")}" required></label><label class="field">Code<input name="code" value="${escapeHtml(row?.code || "")}" required></label><label class="field">Parent location<select name="parent"><option value="">None</option>${state.locations.filter(x => !row || idText(x.id) !== idText(row.id)).map(x => `<option value="${escapeHtml(idText(x.id))}" ${idText(row?.parent) === idText(x.id) ? "selected" : ""}>${escapeHtml(x.name)}</option>`).join("")}</select></label>`;
  openSimple(row ? "Edit location" : "Add location", fields, async data => {
    const vars = { team: state.team, warehouse: state.warehouses.find(x => idText(x.id) === data.get("warehouse"))?.id, name: data.get("name"), code: data.get("code"), parent: state.locations.find(x => idText(x.id) === data.get("parent"))?.id || null };
    if (row) await query("UPDATE $id SET warehouse=$warehouse, name=$name, code=$code, parent=$parent;", { id: row.id, ...vars });
    else await query("CREATE stock_location CONTENT { owned_by:$team, warehouse:$warehouse, name:$name, code:$code, parent:$parent, active:true };", vars);
  });
}
function openCategory() { openSimple("Add product category", `<label class="field">Category name<input name="name" required></label>`, async data => query("CREATE product_category CONTENT { owned_by:$team, name:$name };", { team: state.team, name: data.get("name") })); }
function openUnit() { openSimple("Add unit of measure", `<label class="field">Name<input name="name" required></label><label class="field">Code<input name="code" required></label>`, async data => query("CREATE unit_of_measure CONTENT { owned_by:$team, name:$name, code:$code };", { team: state.team, name: data.get("name"), code: data.get("code") })); }

async function loadHistory() {
  const kind = $("#history-kind").value || null; const location = $("#history-location").value; const product = $("#history-product").value;
  const vars = {}; const args = [];
  if (kind) { args.push("$kind"); vars.kind = kind; } else args.push("NONE");
  if (location) { args.push("type::record('stock_location',$location)"); vars.location = location.replace(/^stock_location:/, ""); } else args.push("NONE");
  if (product) { args.push("type::record('product',$product)"); vars.product = product.replace(/^product:/, ""); } else args.push("NONE");
  args.push("250");
  const rows = await query(`RETURN fn::stocksense::move_history(${args.join(",")});`, vars);
  $("#history-results").innerHTML = rows?.length ? `<table class="data-table"><thead><tr><th>Date</th><th>Type</th><th>Product</th><th>Location</th><th>Quantity change</th><th>Document</th></tr></thead><tbody>${rows.map(row => `<tr><td>${dateText(row.effective_at)}</td><td>${escapeHtml(kindLabel[row.kind])}</td><td>${escapeHtml(productById(row.product)?.name || row.product)}</td><td>${escapeHtml(locationName(row.location))}</td><td class="${Number(row.quantity_delta) < 0 ? "text-rose-700" : "text-emerald-700"}">${Number(row.quantity_delta) > 0 ? "+" : ""}${amount(row.quantity_delta, 3)}</td><td>${escapeHtml(idText(row.operation))}</td></tr>`).join("")}</tbody></table>` : empty("No stock moves found.");
}

document.addEventListener("click", async event => {
  const target = event.target.closest("button,[data-go]"); if (!target) return;
  try {
    if (target.matches("[data-auth-tab]")) switchAuth(target.dataset.authTab);
    else if (target.dataset.page) { state.page = target.dataset.page; state.filters = { status: "", location: "", category: "", search: "" }; renderNav(); renderPage(); if (state.page === "history") await loadHistory(); }
    else if (target.id === "quick-create") openOperation(({ receipts: "receipt", deliveries: "delivery", transfers: "transfer", adjustments: "adjustment" })[state.page] || "receipt");
    else if (target.matches("[data-new-operation]")) openOperation(target.dataset.newOperation);
    else if (target.matches("[data-edit-operation]")) openOperation("receipt", state.operations.find(x => idText(x.id) === target.dataset.editOperation));
    else if (target.matches("[data-status-operation]")) {
      const row = state.operations.find(x => idText(x.id) === target.dataset.statusOperation); const next = target.dataset.status;
      if (next === "done") { await ensureOperationPositions(row); await query("UPDATE $id SET status='done';", { id: row.id }); }
      else await query("UPDATE $id SET status=$status;", { id: row.id, status: next });
      await refresh(); toast(next === "done" ? "Operation validated; stock ledger updated." : "Operation marked ready.");
    }
    else if (target.matches("[data-delete-operation]")) {
      const row = state.operations.find(x => idText(x.id) === target.dataset.deleteOperation);
      if (confirm("Delete this unvalidated operation?")) { await query("DELETE $id RETURN BEFORE;", { id: row.id }); await refresh(); toast("Operation deleted."); }
    }
    else if (target.matches("[data-add-product]")) openProduct();
    else if (target.matches("[data-edit-product]")) openProduct(productById(target.dataset.editProduct));
    else if (target.matches("[data-delete-product]")) { const row = productById(target.dataset.deleteProduct); if (confirm(`Delete ${row.name}?`)) { await query("DELETE $id RETURN BEFORE;", { id: row.id }); await refresh(); } }
    else if (target.matches("[data-add-category]")) openCategory();
    else if (target.matches("[data-add-warehouse]")) openWarehouse();
    else if (target.matches("[data-edit-warehouse]")) openWarehouse(state.warehouses.find(x => idText(x.id) === target.dataset.editWarehouse));
    else if (target.matches("[data-add-location]")) openLocation();
    else if (target.matches("[data-edit-location]")) openLocation(locationById(target.dataset.editLocation));
    else if (target.matches("[data-toggle-view]")) {
      const board = $("#operations-board"); const kind = ({ receipts: "receipt", deliveries: "delivery", transfers: "transfer", adjustments: "adjustment" })[state.page];
      if (board) { board.dataset.mode = target.dataset.toggleView; board.innerHTML = target.dataset.toggleView === "table" ? `<div class="table-card">${operationsTable(filteredOperations(kind))}</div>` : kanban(filteredOperations(kind)); lucide.createIcons(); }
    }
    else if (target.matches("[data-go]")) { state.page = target.dataset.go; renderNav(); renderPage(); }
    else if (target.matches("[data-close-dialog]")) target.closest("dialog")?.close();
    else if (target.id === "save-draft") await saveOperation(null, "draft");
    else if (target.id === "resend-code") {
      const pending = JSON.parse(localStorage.getItem("stocksense.pending") || "null");
      await connect();
      try { await state.db.signin({ access: "stocksense_recovery", variables: { identifier: pending?.email || $("#verify-form [name=identifier]").value } }); } catch {}
      authMessage("If the code can be resent, it will arrive shortly. Check your inbox.");
    }
    else if (target.id === "load-history") await loadHistory();
    else if (target.id === "logout-button") await logout();
    else if (target.id === "profile-button") toast(`${state.userName} · ${state.team?.name || "StockSense"}`);
  } catch (error) { toast(error.message || "Action failed.", true); }
});

document.addEventListener("input", event => { if (event.target.matches("[data-filter=search]")) { state.filters.search = event.target.value; renderPage(); } });
document.addEventListener("change", event => {
  if (event.target.matches("[data-filter]")) { state.filters[event.target.dataset.filter] = event.target.value; renderPage(); }
  if (event.target.matches("#operation-form [name=kind]")) syncOperationVisibility();
});
$("#login-form").addEventListener("submit", onLogin);
$("#signup-form").addEventListener("submit", onSignup);
$("#verify-form").addEventListener("submit", onVerify);
$("#reset-form").addEventListener("submit", onReset);
$("#operation-form").addEventListener("submit", event => saveOperation(event, state.editingOperation?.status || "draft"));
$("#add-line").addEventListener("click", () => addLine());
$("#operation-form [name=kind]").addEventListener("change", syncOperationVisibility);
$("#simple-dialog [data-close-dialog]").addEventListener("click", event => event.currentTarget.closest("dialog").close());
document.addEventListener("keydown", event => { if (event.key === "Escape") $$("dialog[open]").forEach(dialog => dialog.close()); });

(async function start() {
  try {
    await loadConfig(); lucide.createIcons();
    const pending = JSON.parse(localStorage.getItem("stocksense.pending") || "null");
    if (pending) { $("#verify-form [name=identifier]").value = pending.email || ""; switchAuth("verify"); }
  }
  catch (error) { authMessage(`${error.message}. Check frontend/runtime.json and the SurrealDB connection.`, true); }
})();
