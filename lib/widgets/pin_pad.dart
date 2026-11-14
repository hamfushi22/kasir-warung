import 'package:flutter/material.dart';

/// Papan tombol angka untuk login PIN.
class PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  Widget _key(BuildContext context, String label,
      {VoidCallback? onTap, IconData? icon}) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: icon != null
              ? Icon(icon, size: 26)
              : Text(
                  label,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: <Widget>[
        _key(context, '1', onTap: () => onDigit('1')),
        _key(context, '2', onTap: () => onDigit('2')),
        _key(context, '3', onTap: () => onDigit('3')),
        _key(context, '4', onTap: () => onDigit('4')),
        _key(context, '5', onTap: () => onDigit('5')),
        _key(context, '6', onTap: () => onDigit('6')),
        _key(context, '7', onTap: () => onDigit('7')),
        _key(context, '8', onTap: () => onDigit('8')),
        _key(context, '9', onTap: () => onDigit('9')),
        _key(context, 'C', onTap: onClear),
        _key(context, '0', onTap: () => onDigit('0')),
        _key(context, '',
            onTap: onBackspace, icon: Icons.backspace_outlined),
      ],
    );
  }
}
