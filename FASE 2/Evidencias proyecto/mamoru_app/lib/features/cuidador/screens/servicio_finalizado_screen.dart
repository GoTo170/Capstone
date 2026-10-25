import 'package:flutter/material.dart';
import '../models/servicio_activo.dart';
import '../widgets/cuidador_bottom_nav.dart';

class ServicioFinalizadoScreen extends StatelessWidget {
  final ServicioActivo servicio;

  const ServicioFinalizadoScreen({super.key, required this.servicio});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.celebration, size: 48, color: Colors.green),
                ),
                const SizedBox(height: 20),
                const Text('Servicio finalizado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 14),
                    children: [
                      const TextSpan(text: 'El servicio con '),
                      TextSpan(text: servicio.nombreAdultoMayor, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' ha terminado.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'La familia de ${servicio.familiarResponsable} podrá valorar tu trabajo. El historial se conserva pero '
                  'ya no puedes registrar nuevas actividades u observaciones en este servicio.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CuidadorBottomNav.pantallaServicios(),
                      ),
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Ver mis servicios', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}