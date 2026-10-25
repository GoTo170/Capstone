import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api_exception.dart';
import 'core/sesion.dart';
import 'features/adulto_mayor/screens/inicio_adulto_mayor_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/cuidador/screens/inicio_cuidador_screen.dart';
import 'features/familiar/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lee del teléfono la sesión guardada (si la hay).
  await Sesion.cargar();
  

  runApp(const MamoruApp());
}

class MamoruApp extends StatelessWidget {
  const MamoruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mamoru',
      debugShowCheckedModeBanner: false,
      // Idioma español para el calendario, botones del sistema, etc.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3FAE85),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const _Arranque(),
    );
  }
}

// ================================================================
// ARRANQUE
// ================================================================
//
// Al abrir la app decide a dónde ir:
// - Sin sesión guardada o ya vencida: pantalla de inicio de sesión.
// - Con sesión válida: directo al inicio del rol que corresponda.
// - Sin conexión con el servidor: pantalla para reintentar. La sesión NO
//   se borra, para que el adulto mayor (cuyo código es de un solo uso)
//   no pierda su acceso por un corte de internet.
// ================================================================

class _Arranque extends StatefulWidget {
  const _Arranque();

  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  late Future<Widget> _destino = _decidirDestino();

  Future<Widget> _decidirDestino() async {
    final usuario = await AuthService.restaurarSesion();

    if (usuario == null) return const LoginScreen();

    if (usuario.rol == 'familiar') return const HomeScreen();

    if (usuario.rol == 'adulto_mayor') {
      return InicioAdultoMayorScreen(nombre: usuario.nombre);
    }

    if (usuario.rol == 'cuidador') {
      final estado = await AuthService.estadoValidacionCuidador();
      if (estado == 'aprobado') {
        return InicioCuidadorScreen(nombreCuidador: usuario.nombre);
      }
    }

    // Administrador, o cuidador que todavía no está aprobado.
    AuthService.cerrarSesion();
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destino,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PantallaCarga();
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final mensaje = error is ApiException
              ? error.mensaje
              : 'No se pudo conectar con el servidor.';

          return _PantallaSinConexion(
            mensaje: mensaje,
            onReintentar: () {
              setState(() {
                _destino = _decidirDestino();
              });
            },
          );
        }

        return snapshot.data!;
      },
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo_mamoru.png', width: 140),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFF3FAE85)),
          ],
        ),
      ),
    );
  }
}

class _PantallaSinConexion extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _PantallaSinConexion({
    required this.mensaje,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onReintentar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3FAE85),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}