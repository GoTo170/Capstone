import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api_exception.dart';
import '../services/familiar_service.dart';
import 'codigo_manual_screen.dart';

class InvitacionGeneradaScreen extends StatelessWidget {
  final String nombreAdultoMayor;
  final String codigo;
  final String adultoMayorId;

  const InvitacionGeneradaScreen({
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
        child: SingleChildScrollView(
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
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'ESCANEA CON LA CÁMARA DEL CELULAR',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 200,
                            height: 200,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.pink.shade100, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: codigo,
                              version: QrVersions.auto,
                              size: 176,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Comparte esta invitación con ${nombreAdultoMayor.split(' ').first}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDEDEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.pink.shade100),
                            ),
                            child: Column(
                              children: [
                                const Text('CÓDIGO DE INVITACIÓN',
                                    style: TextStyle(fontSize: 10, color: Colors.pink, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
                                const SizedBox(height: 4),
                                Text(codigo,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('Válido por 48 horas', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Compartir enlace (pendiente de conectar).')),
                        );
                      },
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Compartir enlace'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enlace copiado (pendiente de conectar).')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar enlace'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CodigoManualScreen(
                              nombreAdultoMayor: nombreAdultoMayor,
                              codigo: codigo,
                              adultoMayorId: adultoMayorId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.dialpad),
                      label: const Text('Mostrar solo el código'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
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
      ),
    );
  }
}