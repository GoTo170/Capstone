import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/perfil_familiar_screen.dart';
import '../screens/tareas_screen.dart';

enum PestanaFamiliar { inicio, tareas, perfil }

class FamiliarBottomNav extends StatelessWidget {
  final PestanaFamiliar seleccionada;

  const FamiliarBottomNav({super.key, required this.seleccionada});

  void _navegar(BuildContext context, PestanaFamiliar destino) {
    if (destino == seleccionada) return;

    late final Widget pantalla;
    switch (destino) {
      case PestanaFamiliar.inicio:
        pantalla = const HomeScreen();
        break;
      case PestanaFamiliar.tareas:
        pantalla = const TareasScreen();
        break;
      case PestanaFamiliar.perfil:
        pantalla = const PerfilFamiliarScreen();
        break;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: seleccionada.index,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.pink,
      unselectedItemColor: Colors.grey,
      onTap: (index) => _navegar(context, PestanaFamiliar.values[index]),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tareas'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}