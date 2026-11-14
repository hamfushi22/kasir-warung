import 'package:flutter/material.dart';

import '../services/money.dart';

/// Satu batang grafik.
class BarData {
  final String label;
  final int value;
  const BarData({required this.label, required this.value});
}

/// Grafik batang sederhana (tanpa dependensi chart) untuk penjualan 7 hari.
class SimpleBarChart extends StatelessWidget {
  final List<BarData> data;
  final Color color;

  const SimpleBarChart({
    super.key,
    required this.data,
    this.color = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Belum ada data')),
      );
    }
    int maxValue = 0;
    for (final BarData d in data) {
      if (d.value > maxValue) maxValue = d.value;
    }
    if (maxValue <= 0) maxValue = 1;
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((BarData d) {
          final double ratio = d.value / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                    d.value > 0 ? _short(d.value) : '',
                    style: const TextStyle(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 100 * ratio + 4,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(d.label, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _short(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}rb';
    return v.toString();
  }
}

/// Kartu angka ringkas di dashboard / laporan.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Format rupiah singkat untuk grafik (dipakai di beberapa tempat).
String shortRp(int v) {
  if (v >= 1000000) return 'Rp${(v / 1000000).toStringAsFixed(1)}jt';
  if (v >= 1000) return 'Rp${(v / 1000).toStringAsFixed(0)}rb';
  return rp(v);
}
