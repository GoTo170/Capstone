import 'package:flutter/material.dart';
import 'login_screen.dart';

class CuentaCreadaCuidadorScreen extends StatelessWidget {
  const CuentaCreadaCuidadorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.hourglass_top, size: 48, color: Colors.orange),
                ),
                const SizedBox(height: 20),
                const Text('Tu cuenta fue creada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                  'Como cuidador, tu perfil debe ser validado antes de poder usar Mamoru. '
                  'Revisaremos tu profesión y el documento que enviaste, y te llegará un correo '
                  'con el resultado (aprobado o rechazado).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: const [
                      Icon(Icons.mark_email_unread_outlined, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Revisa tu bandeja de entrada (y spam) en los próximos días.', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3FAE85),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Entendido, ir a iniciar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
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