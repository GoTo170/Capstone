import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../../shared/services/notificaciones_service.dart';
import '../screens/alertas_screen.dart';
import '../screens/cuidadores_screen.dart';
import '../screens/solicitudes_familiar_screen.dart';

class MenuNavegacionButton extends StatefulWidget {
  /// Ya no se usa: el contador de alertas sin leer se pide al servidor.
  final int alertasSinLeer;

  const MenuNavegacionButton({super.key, this.alertasSinLeer = 0});

  @override
  State<MenuNavegacionButton> createState() => _MenuNavegacionButtonState();
}

class _MenuNavegacionButtonState extends State<MenuNavegacionButton> {
  int _sinLeer = 0;

  @override
  void initState() {
    super.initState();
    _cargarSinLeer();
  }

  Future<void> _cargarSinLeer() async {
    try {
      final lista = await NotificacionesService.listar();
      if (!mounted) return;
      setState(() => _sinLeer = lista.where((n) => !n.leida).length);
    } on ApiException {
      // Sin conexión: el contador se deja como estaba.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: PopupMenuButton<String>(
        onSelected: (opcion) {
          if (opcion == 'cuidadores') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CuidadoresScreen()));
          }
          if (opcion == 'solicitudes') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitudesFamiliarScreen()));
          }
          if (opcion == 'alertas') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertasScreen())).then((_) => _cargarSinLeer());
          }
        },
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.menu, color: Colors.pink),
            ),
            if (_sinLeer > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$_sinLeer', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        itemBuilder: (context) => [
          const PopupMenuItem(
            enabled: false,
            child: Text('NAVEGACIÓN', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
          _itemMenu('cuidadores', Icons.people_alt_outlined, Colors.deepPurple, 'Cuidadores', 'Busca el apoyo ideal'),
          _itemMenu('solicitudes', Icons.assignment_outlined, Colors.pink, 'Solicitudes', 'Servicios y conversaciones'),
          _itemMenu('alertas', Icons.notifications_none_rounded, Colors.orange, 'Alertas', '$_sinLeer sin leer'),
        ],
      ),
    );
  }

  PopupMenuItem<String> _itemMenu(String value, IconData icono, Color color, String titulo, String subtitulo) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: color.withOpacity(0.12), child: Icon(icono, size: 16, color: color)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitulo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}