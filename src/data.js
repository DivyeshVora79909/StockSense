const starter = {
  products: [
    { id: 'steel-rods', name: 'Steel Rods', sku: 'STL-001', category: 'Materials', location: 'Main Warehouse', quantity: 1250, minimum: 200, unit: 'kg', color: 'steel', symbol: '▥' },
    { id: 'oak-panels', name: 'Oak Panels', sku: 'WD-014', category: 'Materials', location: 'Warehouse 2', quantity: 84, minimum: 100, unit: 'pcs', color: 'oak', symbol: '▤' },
    { id: 'chair-frame', name: 'Chair Frames', sku: 'FR-203', category: 'Components', location: 'Production Floor', quantity: 342, minimum: 80, unit: 'pcs', color: 'frame', symbol: '⌑' },
    { id: 'brass-hinges', name: 'Brass Hinges', sku: 'HW-008', category: 'Components', location: 'Rack A', quantity: 18, minimum: 50, unit: 'pcs', color: 'brass', symbol: '⌁' },
    { id: 'shipping-boxes', name: 'Shipping Boxes', sku: 'PK-031', category: 'Packaging', location: 'Main Warehouse', quantity: 620, minimum: 150, unit: 'pcs', color: 'box', symbol: '▧' },
    { id: 'walnut-finish', name: 'Walnut Finish', sku: 'FN-107', category: 'Materials', location: 'Warehouse 2', quantity: 96, minimum: 40, unit: 'litres', color: 'walnut', symbol: '◒' },
  ],
  moves: [
    { id: 'm1', type: 'Receipt', product: 'Steel Rods', sku: 'STL-001', quantity: 250, location: 'Main Warehouse', reference: 'PO-2024-084', time: '12 min ago', status: 'Done' },
    { id: 'm2', type: 'Delivery', product: 'Chair Frames', sku: 'FR-203', quantity: 24, location: 'Production Floor', reference: 'SO-2024-219', time: '48 min ago', status: 'Done' },
    { id: 'm3', type: 'Transfer', product: 'Oak Panels', sku: 'WD-014', quantity: 30, location: 'Warehouse 2', toLocation: 'Production Floor', reference: 'TR-2024-031', time: '2 hrs ago', status: 'Done' },
    { id: 'm4', type: 'Adjustment', product: 'Brass Hinges', sku: 'HW-008', quantity: 2, location: 'Rack A', reference: 'ADJ-2024-012', time: 'Yesterday', status: 'Done' },
    { id: 'm5', type: 'Receipt', product: 'Shipping Boxes', sku: 'PK-031', quantity: 100, location: 'Main Warehouse', reference: 'PO-2024-080', time: 'Yesterday', status: 'Done' },
  ],
};

export const inventory = (() => {
  try { return JSON.parse(localStorage.getItem('stocksense-inventory')) || starter; }
  catch { return starter; }
})();

export function saveInventory(value) {
  try { localStorage.setItem('stocksense-inventory', JSON.stringify(value)); } catch { /* Browser storage is optional. */ }
}
