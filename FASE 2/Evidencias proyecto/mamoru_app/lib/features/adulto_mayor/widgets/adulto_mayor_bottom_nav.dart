import 'package:flutter/material.dart';
import '../../familiar/models/actividad.dart';
import '../screens/inicio_adulto_mayor_screen.dart';
import '../screens/perfil_adulto_mayor_screen.dart';
import '../screens/tareas_adulto_mayor_screen.dart';

enum PestanaAdultoMayor { inicio, tareas, perfil }

class AdultoMayorBottomNav extends StatelessWidget {
  final PestanaAdultoMayor seleccionada;
  final String nombre;
  final List<Actividad> actividades;

  const AdultoMayorBottomNav({
    super.key,
    required this.seleccionada,
    required this.nombre,
    required this.actividades,
  });

  void _navegar(BuildContext context, PestanaAdultoMayor destino) {
    if (destino == seleccionada) return;

    late final Widget pantalla;
    switch (destino) {
      case PestanaAdultoMayor.inicio:
        pantalla = InicioAdultoMayorScreen(nombre: nombre, actividadesIniciales: actividades);
        break;
      case PestanaAdultoMayor.tareas:
        pantalla = TareasAdultoMayorScreen(actividades: actividades);
        break;
      case PestanaAdultoMayor.perfil:
        pantalla = const PerfilAdultoMayorScreen();
        break;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: seleccionada.index,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.green[700],
      unselectedItemColor: Colors.grey,
      selectedFontSize: 13,
      unselectedFontSize: 12,
      onTap: (index) => _navegar(context, PestanaAdultoMayor.values[index]),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home, size: 28), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.check_circle, size: 28), label: 'Tareas'),
        BottomNavigationBarItem(icon: Icon(Icons.person, size: 28), label: 'Perfil'),
      ],
    );
  }
}