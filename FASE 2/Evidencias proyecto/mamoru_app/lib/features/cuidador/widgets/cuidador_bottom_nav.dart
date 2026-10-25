import 'package:flutter/material.dart';

import '../models/actividad_cuidador.dart';
import '../models/servicio_activo.dart';

import '../screens/actividades_cuidador_screen.dart';
import '../screens/inicio_cuidador_screen.dart';
import '../screens/perfil_cuidador_screen.dart';
import '../screens/servicios_cuidador_screen.dart';

enum PestanaCuidador {
  inicio,
  servicios,
  actividades,
  perfil,
}

class CuidadorBottomNav extends StatelessWidget {
  final PestanaCuidador seleccionada;
  final String nombreCuidador;
  final ServicioActivo? servicio;
  final List<ActividadCuidador> actividades;

  static Widget pantallaServicios() =>
      const ServiciosCuidadorScreen();

  const CuidadorBottomNav({
    super.key,
    required this.seleccionada,
    required this.nombreCuidador,
    this.servicio,
    this.actividades = const [],
  });

  void _navegar(
    BuildContext context,
    PestanaCuidador destino,
  ) {
    if (destino == seleccionada) return;

    late final Widget pantalla;

    switch (destino) {
      case PestanaCuidador.inicio:
        pantalla = InicioCuidadorScreen(
          nombreCuidador: nombreCuidador,
        );
        break;

      case PestanaCuidador.servicios:
        pantalla = const ServiciosCuidadorScreen();
        break;

      case PestanaCuidador.actividades:
        pantalla = ActividadesCuidadorScreen(
          actividades: actividades,
        );
        break;

      case PestanaCuidador.perfil:
        pantalla = const PerfilCuidadorScreen();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => pantalla,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: seleccionada.index,
      type: BottomNavigationBarType.fixed,

      selectedItemColor: Colors.green[700],
      unselectedItemColor: Colors.grey,

      onTap: (index) {
        _navegar(
          context,
          PestanaCuidador.values[index],
        );
      },

      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),

        BottomNavigationBarItem(
          icon: Icon(
            Icons.medical_services_outlined,
          ),
          label: 'Servicios',
        ),

        BottomNavigationBarItem(
          icon: Icon(
            Icons.check_circle_outline,
          ),
          label: 'Actividades',
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    );
  }
}