import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/api_exception.dart';
import '../../../core/sesion.dart';
import '../services/familiar_service.dart';
import 'invitacion_generada_screen.dart';
import 'detalle_adulto_mayor_vinculado_screen.dart';
import 'vincular_screen.dart';
import '../widgets/familiar_bottom_nav.dart';
import '../widgets/menu_navegacion_button.dart';

class AdultoMayorResumen {
  final String id;
  final String nombre;
  final bool activo;

  const AdultoMayorResumen({required this.id, required this.nombre, required this.activo});
}

class PerfilFamiliarScreen extends StatefulWidget {
  const PerfilFamiliarScreen({super.key});

  @override
  State<PerfilFamiliarScreen> createState() => _PerfilFamiliarScreenState();
}

class _PerfilFamiliarScreenState extends State<PerfilFamiliarScreen> {
  // Datos reales de quien inició sesión.
  String get _nombre => Sesion.usuario?.nombre ?? '';
  String get _apellido => Sesion.usuario?.apellido ?? '';
  String get _correo => Sesion.usuario?.email ?? 'No registrado';
  String get _telefono => Sesion.usuario?.telefono ?? 'No registrado';
  static const int _maxAdultosMayores = 2;

  File? _foto;

  List<AdultoMayorResumen> _adultosVinculados = [];
  bool _cargandoAdultos = true;
  String? _errorAdultos;

  @override
  void initState() {
    super.initState();
    _cargarAdultos();
  }

  Future<void> _cargarAdultos() async {
    setState(() {
      _cargandoAdultos = true;
      _errorAdultos = null;
    });

    try {
      final lista = await FamiliarService.listarAdultosMayores();

      if (!mounted) return;

      setState(() {
        _adultosVinculados = lista
            .map((a) => AdultoMayorResumen(id: a.id, nombre: a.nombreCompleto, activo: a.accesoActivado))
            .toList();
        _cargandoAdultos = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAdultos = e.mensaje;
        _cargandoAdultos = false;
      });
    }
  }

  /// Genera un código nuevo para un adulto mayor ya vinculado
  /// (por ejemplo, si cerró sesión o cambió de celular).
  Future<void> _reinvitar(AdultoMayorResumen adulto) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Generar nueva invitación?'),
        content: Text('Se creará un código nuevo para ${adulto.nombre}. El código anterior dejará de funcionar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generar')),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      final invitacion = await FamiliarService.reinvitar(adulto.id, adulto.nombre);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvitacionGeneradaScreen(
            nombreAdultoMayor: invitacion.nombreAdultoMayor,
            codigo: invitacion.codigo,
            adultoMayorId: invitacion.adultoMayorId,
          ),
        ),
      );

      if (mounted) _cargarAdultos();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _cambiarFoto() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.gallery);
    if (imagen != null) setState(() => _foto = File(imagen.path));
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmado == true && mounted) {
      AuthService.cerrarSesion();
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iniciales = '${_nombre.isNotEmpty ? _nombre[0] : ''}${_apellido.isNotEmpty ? _apellido[0] : ''}'.toUpperCase();
    final alMaximo = _adultosVinculados.length >= _maxAdultosMayores;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFFF7F5),
        elevation: 0,
        actions: const [MenuNavegacionButton(alertasSinLeer: 2)],
      ),
      bottomNavigationBar: const FamiliarBottomNav(seleccionada: PestanaFamiliar.perfil),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFF6C9CF), Color(0xFFFBE6D5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.pink[200],
                          backgroundImage: _foto != null ? FileImage(_foto!) : null,
                          child: _foto == null ? Text(iniciales, style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold)) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _cambiarFoto,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)]),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.pink),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('$_nombre $_apellido', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text('Familiar responsable', style: TextStyle(fontSize: 13, color: Colors.pink)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TarjetaBlanca(
                      titulo: 'Información personal',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: _DatoSoloLectura(etiqueta: 'NOMBRE', valor: _nombre)),
                              Expanded(child: _DatoSoloLectura(etiqueta: 'APELLIDO', valor: _apellido)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _DatoSoloLectura(etiqueta: 'CORREO ELECTRÓNICO', valor: _correo),
                          const SizedBox(height: 10),
                          _DatoSoloLectura(etiqueta: 'TELÉFONO', valor: _telefono),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TarjetaBlanca(
                      titulo: 'Perfiles vinculados',
                      etiquetaExtra: '${_adultosVinculados.length}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${_adultosVinculados.length} de $_maxAdultosMayores adultos mayores', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 10),
                          if (_cargandoAdultos)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_errorAdultos != null)
                            Column(
                              children: [
                                Text(_errorAdultos!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                                TextButton(onPressed: _cargarAdultos, child: const Text('Reintentar')),
                              ],
                            )
                          else if (_adultosVinculados.isEmpty)
                            const Text('Aún no has vinculado a ningún adulto mayor.', style: TextStyle(fontSize: 12, color: Colors.grey))
                          else
                            for (final a in _adultosVinculados) ...[
                              _ItemAdultoVinculado(
                                adulto: a,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DetalleAdultoMayorVinculadoScreen(adultoMayorId: a.id)),
                                ),
                                onReinvitar: () => _reinvitar(a),
                              ),
                              const SizedBox(height: 8),
                            ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.pink.shade100)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.link, color: Colors.pink, size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Invitar a un adulto mayor', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Vincula hasta $_maxAdultosMayores adultos mayores a tu cuenta de Mamoru.', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: alMaximo
                                ? null
                                : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VincularScreen())).then((_) => _cargarAdultos()),
                            icon: const Icon(Icons.add),
                            label: Text(alMaximo ? 'Ya alcanzaste el máximo' : 'Invitar a un adulto mayor'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                              disabledBackgroundColor: Colors.pink.withOpacity(0.3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _confirmarCerrarSesion,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
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

class _TarjetaBlanca extends StatelessWidget {
  final String titulo;
  final String? etiquetaExtra;
  final Widget child;

  const _TarjetaBlanca({required this.titulo, this.etiquetaExtra, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              if (etiquetaExtra != null)
                CircleAvatar(radius: 12, backgroundColor: Colors.deepPurple[100], child: Text(etiquetaExtra!, style: TextStyle(fontSize: 11, color: Colors.deepPurple[700], fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DatoSoloLectura extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _DatoSoloLectura({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.4)),
        const SizedBox(height: 2),
        Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ItemAdultoVinculado extends StatelessWidget {
  final AdultoMayorResumen adulto;
  final VoidCallback onTap;
  final VoidCallback onReinvitar;

  const _ItemAdultoVinculado({required this.adulto, required this.onTap, required this.onReinvitar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: Color(0xFFF6D998), child: Icon(Icons.person, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(adulto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (adulto.activo)
                    const Text('✓ Perfil activo', style: TextStyle(fontSize: 11, color: Colors.green))
                  else
                    const Text('Invitación pendiente', style: TextStyle(fontSize: 11, color: Colors.orange)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_2, color: Colors.deepPurple),
              tooltip: 'Generar nueva invitación',
              onPressed: onReinvitar,
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}