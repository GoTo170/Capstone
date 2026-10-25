import 'package:flutter/material.dart';

class PasswordRequirementsGrid extends StatelessWidget {
  final Map<String, bool> requisitos;

  const PasswordRequirementsGrid({super.key, required this.requisitos});

  @override
  Widget build(BuildContext context) {
    final todosCumplidos = requisitos.values.every((v) => v);

    if (todosCumplidos) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green),
            SizedBox(width: 6),
            Text('Contraseña completa', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REQUISITOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5)),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final anchoItem = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 6,
              children: requisitos.entries.map((r) {
                return SizedBox(
                  width: anchoItem,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.value ? Icons.check : Icons.close, size: 14, color: r.value ? Colors.green : Colors.red),
                      const SizedBox(width: 4),
                      Expanded(child: Text(r.key, style: TextStyle(fontSize: 12, color: r.value ? Colors.green[700] : Colors.red[700]))),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}