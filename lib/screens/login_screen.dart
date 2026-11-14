import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../widgets/pin_pad.dart';

/// Login dengan PIN (4 digit).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _tryLogin() async {
    if (_pin.length < 4 || _busy) return;
    setState(() => _busy = true);
    final bool ok =
        await context.read<AuthProvider>().login(_pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() {
        _error = 'PIN salah, coba lagi.';
        _pin = '';
      });
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    // PIN 6 digit langsung dicoba; PIN 4–5 digit lewat tombol Masuk.
    if (_pin.length == 6) {
      _tryLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String storeName =
        context.watch<CatalogProvider>().settings.storeName;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 32),
              const Icon(Icons.storefront, size: 64, color: Colors.teal),
              const SizedBox(height: 12),
              Text(
                storeName,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text('Masukkan PIN (4–6 digit) untuk masuk',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(6, (int i) {
                  final bool filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? Colors.teal : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: 300,
                child: PinPad(
                  onDigit: _onDigit,
                  onBackspace: () {
                    if (_pin.isNotEmpty) {
                      setState(() => _pin = _pin.substring(0, _pin.length - 1));
                    }
                  },
                  onClear: () => setState(() => _pin = ''),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: FilledButton(
                  onPressed: _pin.length >= 4 && !_busy ? _tryLogin : null,
                  child: const Text('Masuk'),
                ),
              ),
              const SizedBox(height: 12),
              if (_busy) const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text(
                'Demo — Owner: 1234, Kasir: 1111\nGanti PIN di Pengaturan setelah instalasi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
