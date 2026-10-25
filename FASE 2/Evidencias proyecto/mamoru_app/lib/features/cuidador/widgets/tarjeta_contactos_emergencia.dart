import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
 
import '../models/solicitud_servicio.dart';
 
/// Contactos de emergencia del adulto mayor, con un botón para copiar cada
/// teléfono. Solo hay contactos mientras el servicio está vigente.
class TarjetaContactosEmergencia extends StatelessWidget {
  final List<ContactoEmergenciaServicio> contactos;
 
  const TarjetaContactosEmergencia({super.key, required this.contactos});
 
  Future<void> _copiar(BuildContext context, String telefono) async {
    final mensajero = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: telefono));
    mensajero.showSnackBar(const SnackBar(content: Text('Teléfono copiado'), duration: Duration(seconds: 2)));
  }
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contactos de emergencia', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (contactos.isEmpty)
            const Text(
              'Los contactos de emergencia se muestran solo mientras el servicio está en curso.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          for (final c in contactos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFFDE3E3),
                    child: Icon(Icons.emergency_outlined, size: 16, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.parentesco == null ? c.nombre : '${c.nombre} (${c.parentesco})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SelectableText(c.telefono, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar teléfono',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copiar(context, c.telefono),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}