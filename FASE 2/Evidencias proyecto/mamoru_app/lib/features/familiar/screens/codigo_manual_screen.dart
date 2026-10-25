import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../services/familiar_service.dart';

class CodigoManualScreen extends StatelessWidget {
  final String nombreAdultoMayor;
  final String codigo;
  final String adultoMayorId;

  const CodigoManualScreen({
    super.key,
    required this.nombreAdultoMayor,
    required this.codigo,
    required this.adultoMayorId,
  });

  /// Revoca el código y vuelve al inicio. El adulto mayor sigue vinculado:
  /// se le puede generar una invitación nueva desde el perfil del familiar.
  Future<void> _cancelar(BuildContext context) async {
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await FamiliarService.cancelarInvitacion(adultoMayorId);

      navegador.popUntil((route) => route.isFirst);
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('Invitación cancelada. Puedes generar una nueva desde tu perfil.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFBD5D8), Color(0xFFFDEDEB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invitación generada', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Para $nombreAdultoMayor', style: const TextStyle(fontSize: 12, color: Colors.pink)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(16)),
                          child: Icon(Icons.dialpad, size: 40, color: Colors.indigo[400]),
                        ),
                        const SizedBox(height: 16),
                        const Text('Código manual', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'Muéstrale este código a ${nombreAdultoMayor.split(' ').first} para que lo ingrese en Mamoru',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Text('CÓDIGO DE INVITACIÓN',
                                  style: TextStyle(fontSize: 10, color: Colors.deepPurple, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
                              const SizedBox(height: 6),
                              Text(codigo, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Válido por 48 horas', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver al código QR'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: () => _cancelar(context),
                      child: const Text('Cancelar invitación', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}