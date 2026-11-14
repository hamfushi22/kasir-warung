import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/checkout_service.dart';
import '../services/money.dart';
import '../widgets/empty_state.dart';
import '../widgets/receipt_dialog.dart';

/// Layar kasir: cari produk, grid favorit, keranjang, checkout.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  int? _categoryId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> all) {
    final String q = _query.trim().toLowerCase();
    return all.where((Product p) {
      if (_categoryId != null && p.categoryId != _categoryId) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q);
    }).toList();
  }

  void _addProduct(Product p) {
    final CartProvider cart = context.read<CartProvider>();
    if (!p.isService && p.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.name} stok habis')),
      );
      return;
    }
    final int inCart = cart.items
        .where((CartItem i) => i.product.id == p.id)
        .fold<int>(0, (int s, CartItem i) => s + i.qty);
    if (!p.isService && inCart >= p.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.name} stok tinggal ${p.stock}')),
      );
      return;
    }
    cart.addProduct(p);
  }

  Future<void> _submitSearch(String value) async {
    final String v = value.trim();
    if (v.isEmpty) return;
    final Product? byBarcode =
        await DatabaseHelper.instance.getProductByBarcode(v);
    if (byBarcode != null) {
      _addProduct(byBarcode);
      _searchCtrl.clear();
      setState(() => _query = '');
      return;
    }
    setState(() => _query = v);
  }

  Future<void> _editCartItem(int index) async {
    final CartProvider cart = context.read<CartProvider>();
    final CartItem current = cart.items[index];
    final CartItem? updated = await showDialog<CartItem>(
      context: context,
      builder: (_) => _CartItemDialog(item: current),
    );
    if (updated != null) {
      cart.updateItem(index, updated);
    }
  }

  Future<void> _showTxnDiscount() async {
    final CartProvider cart = context.read<CartProvider>();
    final ({int value, String type})? result =
        await showDialog<({int value, String type})>(
      context: context,
      builder: (BuildContext ctx) {
        final TextEditingController ctrl = TextEditingController(
            text: cart.txnDiscount > 0 ? cart.txnDiscount.toString() : '');
        String type = cart.txnDiscountType;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Diskon Transaksi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nilai diskon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('Rupiah (Rp)'),
                        selected: type == 'rp',
                        onSelected: (_) => setState(() => type = 'rp'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Persen (%)'),
                        selected: type == 'pct',
                        onSelected: (_) => setState(() => type = 'pct'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop((value: 0, type: 'rp')),
                  child: const Text('Hapus'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(
                      (value: parseRupiah(ctrl.text), type: type)),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      cart.setTransactionDiscount(result.value, result.type);
    }
  }

  Future<void> _parkSale() async {
    final CartProvider cart = context.read<CartProvider>();
    final AuthProvider auth = context.read<AuthProvider>();
    if (cart.isEmpty) return;
    try {
      final String invoiceNo = await cart.holdSale(
        userId: auth.userId,
        userName: auth.userName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaksi $invoiceNo diparkir')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memarkir: $e')),
      );
    }
  }

  Future<void> _showHeldSales() async {
    final List<Sale> held = await DatabaseHelper.instance.getHeldSales();
    if (!mounted) return;
    if (held.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada transaksi yang diparkir')),
      );
      return;
    }
    final Sale? picked = await showDialog<Sale>(
      context: context,
      builder: (BuildContext ctx) {
        return SimpleDialog(
          title: const Text('Transaksi Diparkir'),
          children: held.map((Sale s) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(s),
              child: ListTile(
                title: Text(s.invoiceNo),
                subtitle: Text(formatDateTime(s.createdAt)),
                trailing: Text(rp(s.grandTotal)),
              ),
            );
          }).toList(),
        );
      },
    );
    if (picked == null || picked.id == null) return;
    final CartProvider cart = context.read<CartProvider>();
    if (cart.items.isNotEmpty) {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Ganti keranjang?'),
          content: const Text(
              'Keranjang saat ini akan diganti dengan transaksi yang diparkir.'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Lanjutkan')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await cart.loadHeldSale(picked.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Transaksi ${picked.invoiceNo} dimuat di kasir')),
    );
  }

  Future<void> _doCheckout() async {
    final CartProvider cart = context.read<CartProvider>();
    final AuthProvider auth = context.read<AuthProvider>();
    final CatalogProvider catalog = context.read<CatalogProvider>();
    if (cart.isEmpty) return;
    final CartTotals totals = computeTotals(
      cart.items,
      txnDiscount: cart.txnDiscount,
      txnDiscountType: cart.txnDiscountType,
      taxEnabled: catalog.settings.taxEnabled,
      taxRate: catalog.settings.taxRate,
    );
    final _CheckoutChoice? choice = await showDialog<_CheckoutChoice>(
      context: context,
      builder: (_) => _CheckoutDialog(grandTotal: totals.grandTotal),
    );
    if (choice == null) return;
    try {
      final CheckoutResult result = await cart.checkout(
        payments: choice.payments,
        isCredit: choice.isCredit,
        customerName: choice.customerName,
        userId: auth.userId,
        userName: auth.userName,
        taxEnabled: catalog.settings.taxEnabled,
        taxRate: catalog.settings.taxRate,
      );
      await context.read<CatalogProvider>().refreshProducts();
      if (!mounted) return;
      final DatabaseHelper db = DatabaseHelper.instance;
      final Sale? sale = await db.getSaleById(result.saleId);
      if (sale == null) return;
      final List<SaleItem> items = await db.getSaleItems(result.saleId);
      final List<Payment> payments =
          await db.getSalePayments(result.saleId);
      await showReceiptDialog(
        context,
        settings: catalog.settings,
        sale: sale,
        items: items,
        payments: payments,
        change: result.change,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal checkout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final CatalogProvider catalog = context.watch<CatalogProvider>();
    final CartProvider cart = context.watch<CartProvider>();
    final List<Product> products = _filtered(catalog.products);
    final CartTotals totals = computeTotals(
      cart.items,
      txnDiscount: cart.txnDiscount,
      txnDiscountType: cart.txnDiscountType,
      taxEnabled: catalog.settings.taxEnabled,
      taxRate: catalog.settings.taxRate,
    );

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari nama / SKU / barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (String v) => setState(() => _query = v),
                  onSubmitted: _submitSearch,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Transaksi diparkir',
                icon: const Icon(Icons.pause_circle_outline),
                onPressed: _showHeldSales,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Semua'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
              ),
              ...catalog.categories.map((Category c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
                );
              }),
            ],
          ),
        ),
        // Grid produk.
        Expanded(
          flex: 3,
          child: products.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  message: 'Produk tidak ditemukan',
                  hint: 'Coba kata kunci lain atau tambah produk baru.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (BuildContext ctx, int i) {
                    final Product p = products[i];
                    final bool out =
                        !p.isService && p.stock <= 0;
                    return InkWell(
                      onTap: () => _addProduct(p),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: out
                              ? Colors.grey.shade200
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: p.isLowStock
                                ? Colors.orange
                                : Colors.teal.shade100,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              rp(p.priceSell),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              p.isService
                                  ? 'Jasa'
                                  : (out
                                      ? 'Habis'
                                      : 'Stok: ${p.stock} ${p.unit}'),
                              style: TextStyle(
                                fontSize: 11,
                                color: out
                                    ? Colors.red
                                    : (p.isLowStock
                                        ? Colors.orange
                                        : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Keranjang.
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Keranjang (${cart.itemCount} item)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (cart.items.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.discount, size: 18),
                        label: Text(cart.txnDiscount > 0
                            ? 'Diskon: ${cart.txnDiscountType == 'pct' ? '${cart.txnDiscount}%' : rp(cart.txnDiscount)}'
                            : 'Diskon'),
                        onPressed: _showTxnDiscount,
                      ),
                    if (cart.items.isNotEmpty)
                      IconButton(
                        tooltip: 'Kosongkan keranjang',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          cart.clearCart();
                        },
                      ),
                  ],
                ),
              ),
              if (cart.items.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cart.items.length,
                    itemBuilder: (BuildContext ctx, int i) {
                      final CartItem item = cart.items[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          item.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${rp(item.price)} x ${item.qty}'
                          '${item.priceMode == 'grosir' ? ' (grosir)' : ''}'
                          '${item.discountAmount > 0 ? ' • Diskon ${rp(item.discountAmount)}' : ''}'
                          '${item.note.isNotEmpty ? ' • ${item.note}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  cart.setQty(i, item.qty - 1),
                            ),
                            Text('${item.qty}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () =>
                                  cart.setQty(i, item.qty + 1),
                            ),
                            Text(
                              rp(item.lineTotal),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        onTap: () => _editCartItem(i),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text('Subtotal'),
                        Text(rp(totals.subtotal)),
                      ],
                    ),
                    if (totals.transactionDiscount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text('Diskon transaksi'),
                          Text('-${rp(totals.transactionDiscount)}'),
                        ],
                      ),
                    if (totals.tax > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('Pajak (${catalog.settings.taxRate}%)'),
                          Text(rp(totals.tax)),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text('TOTAL',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          rp(totals.grandTotal),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.pause),
                            label: const Text('Parkir'),
                            onPressed:
                                cart.isEmpty ? null : _parkSale,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.payment),
                            label: const Text('Bayar'),
                            onPressed:
                                cart.isEmpty ? null : _doCheckout,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pilihan hasil dialog checkout.
class _CheckoutChoice {
  final List<PaymentInput> payments;
  final bool isCredit;
  final String? customerName;
  final int change;

  _CheckoutChoice({
    required this.payments,
    required this.isCredit,
    this.customerName,
    this.change = 0,
  });
}

/// Dialog pembayaran: tunai / QRIS / transfer / e-wallet,
/// split payment, dan kasbon.
class _CheckoutDialog extends StatefulWidget {
  final int grandTotal;

  const _CheckoutDialog({required this.grandTotal});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  String _method = 'tunai';
  final List<PaymentInput> _payments = <PaymentInput>[];
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  bool _isCredit = false;
  int _change = 0;

  int get _paid => _payments.fold<int>(0, (int s, PaymentInput p) => s + p.amount);
  int get _remaining => widget.grandTotal - _paid;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addPayment() {
    final int amount = parseRupiah(_amountCtrl.text);
    if (amount <= 0 || _remaining <= 0) return;
    int recorded = amount;
    if (_method == 'tunai' && amount > _remaining) {
      recorded = _remaining;
      _change = amount - _remaining;
    }
    setState(() {
      _payments.add(PaymentInput(method: _method, amount: recorded));
      _amountCtrl.text = _remaining - recorded > 0
          ? (_remaining - recorded).toString()
          : '';
    });
  }

  Widget _quickBtn(String label, int amount) {
    return OutlinedButton(
      onPressed: () => setState(() => _amountCtrl.text = amount.toString()),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPay = _isCredit
        ? _nameCtrl.text.trim().isNotEmpty
        : _remaining == 0 && _payments.isNotEmpty;
    return AlertDialog(
      title: Text('Bayar — ${rp(widget.grandTotal)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SwitchListTile(
              title: const Text('Bayar Nanti (Kasbon)'),
              subtitle: const Text('Dicatat sebagai piutang pelanggan'),
              value: _isCredit,
              onChanged: (bool v) => setState(() => _isCredit = v),
            ),
            if (_isCredit) ...<Widget>[
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama pelanggan *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Text(
                'Transaksi dicatat sebagai piutang. Pelanggan bisa melunasi '
                'sebagian atau penuh lewat menu Pelanggan.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else ...<Widget>[
              Wrap(
                spacing: 8,
                children: <String>['tunai', 'qris', 'transfer', 'ewallet']
                    .map((String m) {
                  return ChoiceChip(
                    label: Text(Payment.methodLabel(m)),
                    selected: _method == m,
                    onSelected: (_) => setState(() {
                      _method = m;
                      _amountCtrl.text =
                          _remaining > 0 ? _remaining.toString() : '';
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (_method == 'qris')
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'QRIS statis: tunjukkan QR toko ke pelanggan, lalu '
                    'konfirmasi pembayaran secara manual.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Jumlah (${Payment.methodLabel(_method)})',
                  border: const OutlineInputBorder(),
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 8),
              if (_method == 'tunai')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _quickBtn('Uang Pas', _remaining > 0 ? _remaining : 0),
                    _quickBtn('10rb', 10000),
                    _quickBtn('20rb', 20000),
                    _quickBtn('50rb', 50000),
                    _quickBtn('100rb', 100000),
                  ],
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _addPayment,
                child: const Text('Tambah Pembayaran'),
              ),
              const SizedBox(height: 8),
              ..._payments.asMap().entries.map((MapEntry<int, PaymentInput> e) {
                final int i = e.key;
                final PaymentInput p = e.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(Payment.methodLabel(p.method)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(rp(p.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => setState(() {
                          _payments.removeAt(i);
                          _change = 0;
                        }),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Sisa bayar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(rp(_remaining < 0 ? 0 : _remaining),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (_change > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('Kembalian'),
                    Text(rp(_change),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: canPay
              ? () => Navigator.of(context).pop(_CheckoutChoice(
                    payments: List<PaymentInput>.of(_payments),
                    isCredit: _isCredit,
                    customerName:
                        _isCredit ? _nameCtrl.text.trim() : null,
                    change: _change,
                  ))
              : null,
          child: Text(_isCredit ? 'Simpan Kasbon' : 'Bayar'),
        ),
      ],
    );
  }
}

/// Dialog edit satu baris keranjang: jumlah, harga ecer/grosir,
/// diskon per item, catatan.
class _CartItemDialog extends StatefulWidget {
  final CartItem item;

  const _CartItemDialog({required this.item});

  @override
  State<_CartItemDialog> createState() => _CartItemDialogState();
}

class _CartItemDialogState extends State<_CartItemDialog> {
  late int _qty;
  late String _priceMode;
  late int _discount;
  late String _discountType;
  late TextEditingController _discountCtrl;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _qty = widget.item.qty;
    _priceMode = widget.item.priceMode;
    _discount = widget.item.discount;
    _discountType = widget.item.discountType;
    _discountCtrl = TextEditingController(
        text: _discount > 0 ? _discount.toString() : '');
    _noteCtrl = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _price {
    if (_priceMode == 'grosir' &&
        widget.item.product.priceWholesale != null) {
      return widget.item.product.priceWholesale!;
    }
    return widget.item.product.priceSell;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasWholesale = widget.item.product.priceWholesale != null;
    return AlertDialog(
      title: Text(widget.item.product.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('Jumlah:'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                ),
                Text('$_qty',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _qty++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Harga:'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: Text('Ecer ${rp(widget.item.product.priceSell)}'),
                  selected: _priceMode == 'ecer',
                  onSelected: (_) => setState(() => _priceMode = 'ecer'),
                ),
                ChoiceChip(
                  label: Text(hasWholesale
                      ? 'Grosir ${rp(widget.item.product.priceWholesale!)}'
                      : 'Grosir (tidak ada)'),
                  selected: _priceMode == 'grosir',
                  onSelected: hasWholesale
                      ? (_) => setState(() => _priceMode = 'grosir')
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Diskon item (kosongkan bila tidak ada)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Rupiah (Rp)'),
                  selected: _discountType == 'rp',
                  onSelected: (_) => setState(() => _discountType = 'rp'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Persen (%)'),
                  selected: _discountType == 'pct',
                  onSelected: (_) => setState(() => _discountType = 'pct'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final CartItem updated = widget.item.copy();
            updated.qty = _qty;
            updated.priceMode = _priceMode;
            updated.price = _price;
            updated.discount = parseRupiah(_discountCtrl.text);
            updated.discountType = _discountType;
            updated.note = _noteCtrl.text.trim();
            Navigator.of(context).pop(updated);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
