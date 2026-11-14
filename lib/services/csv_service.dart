import '../models/product.dart';

/// Import / export produk dari / ke CSV dengan format persis
/// template-produk.csv:
/// nama,sku,barcode,kategori,satuan,harga_beli,harga_jual,harga_grosir,stok,stok_minimum
///
/// Catatan MVP: import dilakukan dengan menempel teks CSV (paste) atau
/// memuat file template dari assets. Pemilih file native (file_picker)
/// sengaja tidak dipakai untuk menjaga dependensi tetap minimal —
/// TODO: tambah file_picker bila mau pilih file .csv langsung dari HP.
class CsvService {
  static const List<String> header = <String>[
    'nama',
    'sku',
    'barcode',
    'kategori',
    'satuan',
    'harga_beli',
    'harga_jual',
    'harga_grosir',
    'stok',
    'stok_minimum',
  ];

  /// Pecah satu baris CSV (mendukung field berpetik "...").
  static List<String> splitLine(String line) {
    final List<String> out = <String>[];
    final StringBuffer cur = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final String ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        out.add(cur.toString());
        cur.clear();
      } else {
        cur.write(ch);
      }
    }
    out.add(cur.toString());
    return out.map((String s) => s.trim()).toList();
  }

  /// Parse teks CSV menjadi daftar produk.
  /// Mengembalikan (produk, daftar error per baris).
  static ({List<Product> products, List<String> errors}) parse(String text) {
    final List<Product> products = <Product>[];
    final List<String> errors = <String>[];
    final List<String> lines = text
        .split(RegExp(r'\r?\n'))
        .where((String l) =>
            l.trim().isNotEmpty && !l.trim().startsWith('#'))
        .toList();
    if (lines.isEmpty) {
      errors.add('File CSV kosong.');
      return (products: products, errors: errors);
    }
    final List<String> head =
        splitLine(lines.first).map((String s) => s.toLowerCase()).toList();
    if (head.isEmpty || head.first != 'nama') {
      errors.add(
          'Header tidak dikenali. Baris pertama harus: ${header.join(',')}');
      return (products: products, errors: errors);
    }
    int idx(String name) => head.indexOf(name);

    for (int i = 1; i < lines.length; i++) {
      final List<String> cols = splitLine(lines[i]);
      String get(int j) => j >= 0 && j < cols.length ? cols[j] : '';
      final String name = get(idx('nama'));
      if (name.isEmpty) {
        errors.add('Baris ${i + 1}: nama kosong, dilewati.');
        continue;
      }
      final int? buy = int.tryParse(get(idx('harga_beli')));
      final int? sell = int.tryParse(get(idx('harga_jual')));
      final int? stock = int.tryParse(get(idx('stok')));
      if (buy == null || sell == null || stock == null) {
        errors.add(
            'Baris ${i + 1} ($name): harga_beli / harga_jual / stok harus angka.');
        continue;
      }
      products.add(Product(
        name: name,
        sku: get(idx('sku')),
        barcode: get(idx('barcode')),
        categoryName: get(idx('kategori')),
        unit: get(idx('satuan')).isEmpty ? 'pcs' : get(idx('satuan')),
        priceBuy: buy,
        priceSell: sell,
        priceWholesale: int.tryParse(get(idx('harga_grosir'))),
        stock: stock,
        stockMinimum: int.tryParse(get(idx('stok_minimum'))) ?? 0,
      ));
    }
    return (products: products, errors: errors);
  }

  static String _escape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Bangun teks CSV dari daftar produk.
  static String build(List<Product> products) {
    final StringBuffer b = StringBuffer();
    b.writeln(header.join(','));
    for (final Product p in products) {
      b.writeln(<String>[
        _escape(p.name),
        _escape(p.sku),
        _escape(p.barcode),
        _escape(p.categoryName),
        _escape(p.unit),
        p.priceBuy.toString(),
        p.priceSell.toString(),
        p.priceWholesale?.toString() ?? '',
        p.stock.toString(),
        p.stockMinimum.toString(),
      ].join(','));
    }
    return b.toString();
  }
}
