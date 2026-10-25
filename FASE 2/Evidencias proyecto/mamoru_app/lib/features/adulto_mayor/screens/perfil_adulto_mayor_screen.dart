import 'package:flutter/material.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/api_exception.dart';
import '../../../core/sesion.dart';
import '../services/adulto_mayor_service.dart';
import '../widgets/adulto_mayor_bottom_nav.dart';

class FamiliarVinculado {
  final String nombre;
  final DateTime fechaVinculacion;

  const FamiliarVinculado({required this.nombre, required this.fechaVinculacion});
}

class PerfilAdultoMayorScreen extends StatefulWidget {
  const PerfilAdultoMayorScreen({super.key});

  @override
  State<PerfilAdultoMayorScreen> createState() => _PerfilAdultoMayorScreenState();
}

class _PerfilAdultoMayorScreenState extends State<PerfilAdultoMayorScreen> {
  String _nombreCompleto = Sesion.usuario?.nombreCompleto ?? '';
  List<FamiliarVinculado> _familiares = [];
  bool _cargando = true;
  String? _error;

  /// Primer nombre real de quien inició sesión (para la barra inferior).
  String get _nombreCorto => Sesion.usuario?.nombre ?? '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final perfil = await AdultoMayorService.miPerfil();

      if (!mounted) return;

      setState(() {
        _nombreCompleto = perfil.nombreCompleto;
        _familiares = perfil.familiares
            .map((f) => FamiliarVinculado(nombre: f.nombre, fechaVinculacion: f.fechaVinculacion))
            .toList();
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  String _formatearFecha(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${f.year}-${d(f.month)}-${d(f.day)}';
  }

  Future<void> _confirmarCerrarSesion(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a ingresar con tu código o QR de invitación.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmado == true && context.mounted) {
      AuthService.cerrarSesion();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAFF),
      bottomNavigationBar: AdultoMayorBottomNav(
        seleccionada: PestanaAdultoMayor.perfil,
        nombre: _nombreCorto,
        actividades: const [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE3D9F6), Color(0xFFD9E6F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.person, size: 32, color: Color(0xFFF6B94D)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nombreCompleto, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text('Adulto Mayor', style: TextStyle(fontSize: 13, color: Colors.black54)),
                        ],
                      ),
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
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Mis familiares vinculados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (_cargando)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_error != null)
                            Column(
                              children: [
                                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                                TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                              ],
                            )
                          else if (_familiares.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Aún no tienes familiares vinculados.', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            for (final familiar in _familiares) ...[
                              _TarjetaFamiliarVinculado(
                                nombre: familiar.nombre,
                                fechaTexto: _formatearFecha(familiar.fechaVinculacion),
                              ),
                              if (familiar != _familiares.last) const SizedBox(height: 10),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _confirmarCerrarSesion(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
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

class _TarjetaFamiliarVinculado extends StatelessWidget {
  final String nombre;
  final String fechaTexto;

  const _TarjetaFamiliarVinculado({required this.nombre, required this.fechaTexto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFEAF7EE), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const CircleAvatar(radius: 20, backgroundColor: Color(0xFFF6B9D0), child: Icon(Icons.people, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.check, size: 13, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('Vinculado desde $fechaTexto', style: const TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}