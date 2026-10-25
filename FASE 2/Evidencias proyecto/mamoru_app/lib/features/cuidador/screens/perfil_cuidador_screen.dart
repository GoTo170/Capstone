import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/models/profesion_cuidador.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/api_exception.dart';
import '../models/perfil_cuidador.dart';
import '../../shared/services/notificaciones_service.dart';
import '../../shared/widgets/avatar_foto.dart';
import '../services/cuidador_service.dart';
import '../../../core/sesion.dart';
import '../widgets/cuidador_bottom_nav.dart';
 
class PerfilCuidadorScreen extends StatefulWidget {
  const PerfilCuidadorScreen({super.key});
 
  @override
  State<PerfilCuidadorScreen> createState() => _PerfilCuidadorScreenState();
}
 
class _PerfilCuidadorScreenState extends State<PerfilCuidadorScreen> {
  late PerfilCuidadorData _perfil;
  bool _cargando = true;
  String? _error;
  bool _guardando = false;
 
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
      final perfil = await CuidadorService.miPerfil();
      final valoraciones = await CuidadorService.listarValoraciones();
 
      NotificacionApp? aviso;
      try {
        aviso = await CuidadorService.ultimoAvisoPuertasAdentro();
      } on ApiException {
        // Sin el aviso, el perfil se puede ver igual.
      }
 
      if (!mounted) return;
 
      setState(() {
        _perfil = perfil;
        _valoraciones = valoraciones;
        _avisoPuertasAdentro = aviso;
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
 
  File? _foto;
  bool _subiendoFoto = false;
  bool _cambiandoPuertasAdentro = false;
  NotificacionApp? _avisoPuertasAdentro;
 
  // Tope que acepta el servidor para la foto.
  static const int _maxBytesFoto = 600 * 1024;
 
  List<Valoracion> _valoraciones = [];
  bool _editando = false;
  bool _verTodasValoraciones = false;
  String? _idValoracionSolicitandoRevision;
  late PerfilCuidadorData _borrador;
 
  ProfesionCuidador? get _infoProfesion => buscarProfesionPorId(_perfil.profesionId);
  bool get _esMedica => esProfesionMedica(_perfil.profesionId);
  List<String> get _catalogoServicios => _infoProfesion == null ? [] : serviciosPorCategoria(_infoProfesion!.categoria);
 
  double get _promedio =>
      _valoraciones.isEmpty ? 0 : _valoraciones.map((v) => v.estrellas).reduce((a, b) => a + b) / _valoraciones.length;
 
  /// Lo que todavía falta para que el perfil se muestre a las familias.
  List<String> get _faltantesPerfil => [
        if ((_perfil.fotoUrl ?? '').isEmpty) 'foto de perfil',
        if (_perfil.descripcionPersonal.trim().isEmpty) 'descripción personal',
        if (_perfil.especialidadesSeleccionadas.isEmpty) 'al menos una especialidad',
        if (_perfil.telefono.trim().isEmpty) 'teléfono',
      ];
 
  bool get _perfilCompleto => _faltantesPerfil.isEmpty;
 
  String get _textoEstadoPuertasAdentro {
    if (_perfil.puertasAdentroPendienteAprobacion) return 'Solicitud pendiente de aprobación';
    if (_perfil.puertasAdentroActivo) return 'Activa';
    return 'Requiere aprobación del administrador';
  }
 
  void _entrarModoEdicion() {
    setState(() {
      _borrador = _perfil.copia();
      _editando = true;
    });
  }
 
  void _cancelarEdicion() {
    setState(() => _editando = false);
  }
 
  Future<ImageSource?> _elegirOrigenFoto() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(contexto, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(contexto, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }
 
  /// La foto se guarda al instante (no depende de "Guardar cambios").
  Future<void> _cambiarFoto() async {
    if (_subiendoFoto) return;
 
    final origen = await _elegirOrigenFoto();
    if (origen == null || !mounted) return;
 
    final mensajero = ScaffoldMessenger.of(context);
 
    XFile? imagen;
    try {
      // El propio selector reduce la imagen: así pesa unos pocos cientos de KB.
      imagen = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
    } on PlatformException {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la cámara o la galería. Revisa los permisos de la app.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (imagen == null) return;
 
    final bytes = await imagen.readAsBytes();
    if (bytes.length > _maxBytesFoto) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text('La foto pesa ${bytes.length ~/ 1024} KB. Elige otra más liviana (máximo ${_maxBytesFoto ~/ 1024} KB).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
 
    if (!mounted) return;
    setState(() {
      _foto = File(imagen!.path); // se ve al instante, mientras sube
      _subiendoFoto = true;
    });
 
    try {
      final actualizado = await CuidadorService.subirFoto(bytes);
 
      if (!mounted) return;
 
      setState(() => _perfil = actualizado);
      mensajero.showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _foto = null); // no se guardó: se vuelve a la anterior
      mensajero.showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }
 
  Future<void> _quitarFoto() async {
    if (_subiendoFoto) return;
 
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _subiendoFoto = true);
 
    try {
      final actualizado = await CuidadorService.quitarFoto();
 
      if (!mounted) return;
 
      setState(() {
        _perfil = actualizado;
        _foto = null;
      });
      mensajero.showSnackBar(const SnackBar(content: Text('Foto eliminada.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      mensajero.showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }
 
  /// Pedir la modalidad puertas adentro (queda pendiente), cancelar la
  /// solicitud o dejar de ofrecerla. Se aplica al momento.
  Future<void> _alternarPuertasAdentro(bool quiere) async {
    final pendiente = _perfil.puertasAdentroPendienteAprobacion;
 
    final String titulo;
    final String mensaje;
    final String boton;
 
    if (quiere) {
      titulo = 'Solicitar puertas adentro';
      mensaje = 'Se enviará una solicitud al administrador. Cuando la apruebe, las familias verán tu tarifa por día. '
          'Te avisaremos aquí mismo.';
      boton = 'Enviar solicitud';
    } else if (pendiente) {
      titulo = 'Cancelar solicitud';
      mensaje = 'Se cancelará tu solicitud pendiente.';
      boton = 'Cancelar solicitud';
    } else {
      titulo = 'Dejar de ofrecer puertas adentro';
      mensaje = 'Dejarás de ofrecer esta modalidad de inmediato.';
      boton = 'Dejar de ofrecer';
    }
 
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: Text(boton)),
        ],
      ),
    );
 
    if (confirmado != true || !mounted) return;
 
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _cambiandoPuertasAdentro = true);
 
    try {
      final actualizado = await CuidadorService.cambiarPuertasAdentro(quiere);
 
      if (!mounted) return;
 
      setState(() => _perfil = actualizado);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            quiere
                ? 'Solicitud enviada. Queda pendiente de aprobación.'
                : pendiente
                    ? 'Solicitud cancelada.'
                    : 'Dejaste de ofrecer puertas adentro.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      mensajero.showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _cambiandoPuertasAdentro = false);
    }
  }
 
  Future<void> _entendidoAvisoPuertasAdentro() async {
    final aviso = _avisoPuertasAdentro;
    if (aviso == null) return;
 
    setState(() => _avisoPuertasAdentro = null); // se oculta al instante
 
    try {
      await NotificacionesService.marcarLeida(aviso.id);
    } on ApiException {
      // Si no se pudo marcar, el aviso volverá a mostrarse la próxima vez.
    }
  }
 
  String? get _errorTelefono {
    final limpio = _borrador.telefono.replaceAll(' ', '');
    if (limpio.isEmpty) return 'El teléfono es obligatorio.';
    if (!RegExp(r'^(\+?56)?9\d{8}$').hasMatch(limpio)) return 'Formato inválido. Ej: +56 9 1234 5678';
    return null;
  }
 
  String? get _errorDescripcion {
    if (_borrador.descripcionPersonal.length > 500) return 'Máximo 500 caracteres.';
    return null;
  }
 
  bool get _formularioValido =>
      _errorTelefono == null && _errorDescripcion == null && _borrador.especialidadesSeleccionadas.isNotEmpty;
 
  Future<void> _guardarCambios() async {
    setState(() {});
    if (!_formularioValido || _guardando) return;
 
    final mensajero = ScaffoldMessenger.of(context);
 
    setState(() => _guardando = true);
 
    try {
      final guardado = await CuidadorService.guardarPerfil(_borrador);
 
      if (!mounted) return;
 
      setState(() {
        _perfil = guardado;
        _editando = false;
      });
      mensajero.showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente.')),
      );
    } on ApiException catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
 
  Future<void> _reportarValoracion(int index, String motivo) async {
    final valoracion = _valoraciones[index];
    final id = valoracion.id;
    if (id == null) return;
 
    final mensajero = ScaffoldMessenger.of(context);
 
    try {
      await CuidadorService.reportarValoracion(id, motivo);
 
      if (!mounted) return;
 
      setState(() {
        valoracion.solicitudRevisionEnviada = true;
        valoracion.motivoRevision = motivo;
        _idValoracionSolicitandoRevision = null;
      });
      mensajero.showSnackBar(
        const SnackBar(content: Text('Solicitud de revisión enviada. Quedará pendiente hasta que el administrador la revise.')),
      );
    } on ApiException catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    }
  }
 
  Future<void> _confirmarCerrarSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?'),
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
    if (confirmado == true && mounted) {
      AuthService.cerrarSesion();
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    }
  }
 
  String _formatearCLP(int valor) {
    final texto = valor.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < texto.length; i++) {
      if (i != 0 && (texto.length - i) % 3 == 0) buffer.write('.');
      buffer.write(texto[i]);
    }
    return '\$${buffer.toString()} CLP';
  }
 
  @override
  Widget build(BuildContext context) {
    if (_cargando || _error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF7F5),
        bottomNavigationBar: CuidadorBottomNav(
          seleccionada: PestanaCuidador.perfil,
          nombreCuidador: Sesion.usuario?.nombre ?? '',
          servicio: null,
          actividades: const [],
        ),
        body: SafeArea(
          child: Center(
            child: _cargando
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                        TextButton(onPressed: _confirmarCerrarSesion, child: const Text('Cerrar sesión')),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }
 
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      bottomNavigationBar: CuidadorBottomNav(
        seleccionada: PestanaCuidador.perfil,
        nombreCuidador: _perfil.nombre,
        servicio: null,
        actividades: const [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Encabezado(
                perfil: _perfil,
                foto: _foto,
                promedio: _promedio,
                totalValoraciones: _valoraciones.length,
                editando: _editando,
                onEditar: _entrarModoEdicion,
                onCancelarEdicion: _cancelarEdicion,
              ),
              const SizedBox(height: 12),
              if (!_perfilCompleto)
                _AlertaBanner(
                  color: Colors.orange,
                  icono: Icons.error_outline,
                  titulo: 'Completa tu perfil',
                  texto: 'Te falta: ${_faltantesPerfil.join(', ')}. Sin el perfil completo, las familias no podrán verte.',
                ),
              if (_avisoPuertasAdentro != null) ...[
                const SizedBox(height: 10),
                _AvisoAdministrador(aviso: _avisoPuertasAdentro!, onEntendido: _entendidoAvisoPuertasAdentro),
              ],
              if (_esMedica) ...[
                const SizedBox(height: 10),
                const _AlertaBanner(
                  color: Colors.red,
                  icono: Icons.error_outline,
                  titulo: 'Advertencia importante',
                  texto: 'El cuidador NO está capacitado para diagnosticar, hacer recetas médicas y NO reemplaza ni sustituye a un médico.',
                ),
              ],
              const SizedBox(height: 16),
              if (!_editando) ...[
                _TarjetaInformacionPersonal(perfil: _perfil),
                const SizedBox(height: 16),
                _TarjetaSeccion(
                  titulo: 'Descripción personal',
                  child: Text(_perfil.descripcionPersonal, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 16),
                _TarjetaSeccion(
                  titulo: 'Especialidades y servicios',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _perfil.especialidadesSeleccionadas
                        .map((e) => _ChipEspecialidad(texto: e, seleccionada: true, editable: false))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _TarjetaTarifas(perfil: _perfil, infoProfesion: _infoProfesion, formatear: _formatearCLP),
                const SizedBox(height: 16),
                _TarjetaValoraciones(
                  valoraciones: _valoraciones,
                  verTodas: _verTodasValoraciones,
                  idSolicitandoRevision: _idValoracionSolicitandoRevision,
                  onVerTodas: () => setState(() => _verTodasValoraciones = true),
                  onSolicitarRevision: (index) => setState(
                    () => _idValoracionSolicitandoRevision = _idValoracionSolicitandoRevision == '$index' ? null : '$index',
                  ),
                  onEnviarSolicitud: (index, motivo) => _reportarValoracion(index, motivo),
                  onCancelarSolicitud: () => setState(() => _idValoracionSolicitandoRevision = null),
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
              ] else ...[
                _TarjetaFotoEditable(
                  foto: _foto,
                  fotoUrl: _perfil.fotoUrl,
                  subiendo: _subiendoFoto,
                  onCambiarFoto: _cambiarFoto,
                  onQuitarFoto: _quitarFoto,
                ),
                const SizedBox(height: 16),
                _TarjetaInformacionBloqueada(perfil: _perfil),
                const SizedBox(height: 16),
                _TarjetaSeccion(
                  titulo: 'Teléfono',
                  conError: _errorTelefono != null,
                  child: TextField(
                    controller: TextEditingController(text: _borrador.telefono)..selection = TextSelection.collapsed(offset: _borrador.telefono.length),
                    keyboardType: TextInputType.phone,
                    onChanged: (v) => setState(() => _borrador.telefono = v),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      errorText: _errorTelefono,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _TarjetaSeccion(
                  titulo: 'Descripción personal',
                  conError: _errorDescripcion != null,
                  child: TextField(
                    controller: TextEditingController(text: _borrador.descripcionPersonal)
                      ..selection = TextSelection.collapsed(offset: _borrador.descripcionPersonal.length),
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (v) => setState(() => _borrador.descripcionPersonal = v),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      errorText: _errorDescripcion,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _TarjetaSeccion(
                  titulo: 'Especialidades y servicios',
                  conError: _borrador.especialidadesSeleccionadas.isEmpty,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _catalogoServicios.map((especialidad) {
                      final seleccionada = _borrador.especialidadesSeleccionadas.contains(especialidad);
                      return _ChipEspecialidad(
                        texto: especialidad,
                        seleccionada: seleccionada,
                        editable: true,
                        onTap: () => setState(() {
                          if (seleccionada) {
                            _borrador.especialidadesSeleccionadas.remove(especialidad);
                          } else {
                            _borrador.especialidadesSeleccionadas.add(especialidad);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
                if (_infoProfesion != null && _infoProfesion!.admitePuertasAdentro) ...[
                  const SizedBox(height: 16),
                  _TarjetaSeccion(
                    titulo: 'Disponibilidad puertas adentro',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ofrecer cuidado puertas adentro', style: TextStyle(fontSize: 13)),
                          subtitle: Text(
                            'Tarifa diaria: ${_formatearCLP(_infoProfesion!.tarifaPuertasAdentro!)} · $_textoEstadoPuertasAdentro',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          value: _perfil.puertasAdentroActivo || _perfil.puertasAdentroPendienteAprobacion,
                          activeTrackColor: Colors.blue,
                          onChanged: _cambiandoPuertasAdentro ? null : _alternarPuertasAdentro,
                        ),
                        const Text(
                          'Este cambio se aplica al momento, sin necesidad de guardar el perfil.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        if (_perfil.puertasAdentroPendienteAprobacion) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Row(
                              children: [
                                Icon(Icons.hourglass_top, size: 14, color: Colors.orange),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Tu solicitud está pendiente de aprobación por el administrador.',
                                    style: TextStyle(fontSize: 11, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _guardando ? null : _guardarCambios,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('✓ Guardar cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
 
// ---------- Widgets ----------
 
class _AlertaBanner extends StatelessWidget {
  final Color color;
  final IconData icono;
  final String titulo;
  final String texto;
 
  const _AlertaBanner({required this.color, required this.icono, required this.titulo, required this.texto});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, backgroundColor: Colors.white, child: Icon(icono, size: 16, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
class _Encabezado extends StatelessWidget {
  final PerfilCuidadorData perfil;
  final File? foto;
  final double promedio;
  final int totalValoraciones;
  final bool editando;
  final VoidCallback onEditar;
  final VoidCallback onCancelarEdicion;
 
  const _Encabezado({
    required this.perfil,
    required this.foto,
    required this.promedio,
    required this.totalValoraciones,
    required this.editando,
    required this.onEditar,
    required this.onCancelarEdicion,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFEAF4FB), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarFoto(
            radio: 28,
            url: perfil.fotoUrl,
            archivo: foto,
            colorFondo: const Color(0xFFF6D998),
            iconoVacio: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${perfil.nombre} ${perfil.apellido}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(perfil.profesionNombre, style: const TextStyle(fontSize: 12, color: Colors.blue)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(5, (i) => Icon(Icons.star, size: 14, color: i < promedio.round() ? Colors.amber : Colors.grey.shade300)),
                    const SizedBox(width: 6),
                    Text('${promedio.toStringAsFixed(1)} · $totalValoraciones valoraciones', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(icon: Icon(editando ? Icons.close : Icons.edit, size: 20), onPressed: editando ? onCancelarEdicion : onEditar),
        ],
      ),
    );
  }
}
 
class _TarjetaFotoEditable extends StatelessWidget {
  final File? foto;
  final String? fotoUrl;
  final bool subiendo;
  final VoidCallback onCambiarFoto;
  final VoidCallback onQuitarFoto;
 
  const _TarjetaFotoEditable({
    required this.foto,
    required this.fotoUrl,
    required this.subiendo,
    required this.onCambiarFoto,
    required this.onQuitarFoto,
  });
 
  @override
  Widget build(BuildContext context) {
    final tieneFoto = foto != null || (fotoUrl ?? '').isNotEmpty;
 
    return _TarjetaSeccion(
      titulo: 'Foto de perfil',
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AvatarFoto(
                radio: 32,
                url: fotoUrl,
                archivo: foto,
                colorFondo: const Color(0xFFF6D998),
                iconoVacio: const Icon(Icons.person, color: Colors.white, size: 32),
              ),
              if (subiendo) const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: subiendo ? null : onCambiarFoto,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(tieneFoto ? 'Cambiar foto' : 'Subir foto'),
                ),
                if (tieneFoto)
                  TextButton(
                    onPressed: subiendo ? null : onQuitarFoto,
                    child: const Text('Quitar foto'),
                  ),
                const Text(
                  'La foto se guarda al instante.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
class _TarjetaSeccion extends StatelessWidget {
  final String titulo;
  final Widget child;
  final bool conError;
 
  const _TarjetaSeccion({required this.titulo, required this.child, this.conError = false});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: conError ? Border.all(color: Colors.red) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: conError ? Colors.red : Colors.black)),
          const SizedBox(height: 10),
          child,
          if (conError)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Selecciona al menos una especialidad.', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
 
class _TarjetaInformacionPersonal extends StatelessWidget {
  final PerfilCuidadorData perfil;
 
  const _TarjetaInformacionPersonal({required this.perfil});
 
  @override
  Widget build(BuildContext context) {
    return _TarjetaSeccion(
      titulo: 'Información personal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DatoConIcono(icono: Icons.badge_outlined, etiqueta: 'NOMBRE COMPLETO', valor: '${perfil.nombre} ${perfil.apellido}'),
          const SizedBox(height: 10),
          _DatoConIcono(icono: Icons.phone, etiqueta: 'TELÉFONO', valor: perfil.telefono),
          const SizedBox(height: 10),
          _DatoConIcono(icono: Icons.email_outlined, etiqueta: 'CORREO', valor: perfil.correo),
          const SizedBox(height: 10),
          _DatoConIcono(icono: Icons.medical_services_outlined, etiqueta: 'PROFESIÓN', valor: perfil.profesionNombre),
          const SizedBox(height: 10),
          _DatoConIcono(icono: Icons.access_time, etiqueta: 'EXPERIENCIA', valor: '${perfil.experienciaAnios} años'),
        ],
      ),
    );
  }
}
 
class _TarjetaInformacionBloqueada extends StatelessWidget {
  final PerfilCuidadorData perfil;
 
  const _TarjetaInformacionBloqueada({required this.perfil});
 
  @override
  Widget build(BuildContext context) {
    return _TarjetaSeccion(
      titulo: 'Información personal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CampoBloqueado(etiqueta: 'NOMBRE COMPLETO', valor: '${perfil.nombre} ${perfil.apellido}'),
          const SizedBox(height: 12),
          _CampoBloqueado(etiqueta: 'PROFESIÓN', valor: perfil.profesionNombre, nota: 'La profesión se valida mediante la documentación registrada.'),
          const SizedBox(height: 12),
          _CampoBloqueado(etiqueta: 'AÑOS DE EXPERIENCIA', valor: '${perfil.experienciaAnios} años', nota: 'Este dato se registró junto con tu documentación y no puede modificarse aquí.'),
          const SizedBox(height: 12),
          _CampoBloqueado(etiqueta: 'CORREO ELECTRÓNICO', valor: perfil.correo, nota: 'El correo no se modifica desde aquí.'),
        ],
      ),
    );
  }
}
 
class _CampoBloqueado extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String? nota;
 
  const _CampoBloqueado({required this.etiqueta, required this.valor, this.nota});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
          child: Text(valor, style: const TextStyle(color: Colors.black54)),
        ),
        if (nota != null) ...[
          const SizedBox(height: 4),
          Text(nota!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ],
    );
  }
}
 
class _DatoConIcono extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
 
  const _DatoConIcono({required this.icono, required this.etiqueta, required this.valor});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 15, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.4)),
              Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
 
class _TarjetaTarifas extends StatelessWidget {
  final PerfilCuidadorData perfil;
  final ProfesionCuidador? infoProfesion;
  final String Function(int) formatear;
 
  const _TarjetaTarifas({required this.perfil, required this.infoProfesion, required this.formatear});
 
  @override
  Widget build(BuildContext context) {
    if (infoProfesion == null) return const SizedBox.shrink();
 
    return _TarjetaSeccion(
      titulo: 'Tarifas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _CajaTarifa(etiqueta: 'PERIODO CORTO', valor: formatear(infoProfesion!.tarifaCorta))),
              const SizedBox(width: 10),
              Expanded(child: _CajaTarifa(etiqueta: 'PERIODO LARGO', valor: formatear(infoProfesion!.tarifaLarga))),
            ],
          ),
          if (perfil.puertasAdentroActivo && infoProfesion!.admitePuertasAdentro) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFDFF3E3), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Disponible puerta adentro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                        Text('Modalidad de cuidado diario', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text('${formatear(infoProfesion!.tarifaPuertasAdentro!)} / día', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
          ],
          if (perfil.puertasAdentroPendienteAprobacion) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top, size: 14, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(child: Text('Cambio de disponibilidad puertas adentro pendiente de aprobación.', style: TextStyle(fontSize: 11, color: Colors.orange))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
 
class _CajaTarifa extends StatelessWidget {
  final String etiqueta;
  final String valor;
 
  const _CajaTarifa({required this.etiqueta, required this.valor});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEAF4FB), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Text('por hora', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
 
class _ChipEspecialidad extends StatelessWidget {
  final String texto;
  final bool seleccionada;
  final bool editable;
  final VoidCallback? onTap;
 
  const _ChipEspecialidad({required this.texto, required this.seleccionada, required this.editable, this.onTap});
 
  @override
  Widget build(BuildContext context) {
    final colorFondo = seleccionada ? Colors.green.withOpacity(0.12) : Colors.grey.shade100;
    final colorTexto = seleccionada ? Colors.green[800] : Colors.grey[700];
 
    return InkWell(
      onTap: editable ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: editable ? colorFondo : Colors.blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: editable && seleccionada ? Border.all(color: Colors.green.shade200) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (editable) Icon(seleccionada ? Icons.check : Icons.add, size: 13, color: colorTexto),
            if (editable) const SizedBox(width: 4),
            Flexible(
              child: Text(texto, style: TextStyle(fontSize: 12, color: editable ? colorTexto : Colors.blue[800])),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _TarjetaValoraciones extends StatelessWidget {
  final List<Valoracion> valoraciones;
  final bool verTodas;
  final String? idSolicitandoRevision;
  final VoidCallback onVerTodas;
  final ValueChanged<int> onSolicitarRevision;
  final void Function(int index, String motivo) onEnviarSolicitud;
  final VoidCallback onCancelarSolicitud;
 
  const _TarjetaValoraciones({
    required this.valoraciones,
    required this.verTodas,
    required this.idSolicitandoRevision,
    required this.onVerTodas,
    required this.onSolicitarRevision,
    required this.onEnviarSolicitud,
    required this.onCancelarSolicitud,
  });
 
  @override
  Widget build(BuildContext context) {
    final mostradas = verTodas ? valoraciones : valoraciones.take(2).toList();
 
    return _TarjetaSeccion(
      titulo: 'Valoraciones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < mostradas.length; i++) ...[
            _ItemValoracion(
              valoracion: mostradas[i],
              solicitandoRevision: idSolicitandoRevision == '$i',
              onSolicitarRevision: mostradas[i].solicitudRevisionEnviada ? null : () => onSolicitarRevision(i),
              onEnviarSolicitud: (motivo) => onEnviarSolicitud(i, motivo),
              onCancelarSolicitud: onCancelarSolicitud,
            ),
            if (i != mostradas.length - 1) const Divider(height: 20),
          ],
          if (!verTodas && valoraciones.length > 2) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: onVerTodas,
                child: Text('Ver todas (${valoraciones.length}) ↓', style: const TextStyle(color: Colors.green)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
 
class _ItemValoracion extends StatefulWidget {
  final Valoracion valoracion;
  final bool solicitandoRevision;
  final VoidCallback? onSolicitarRevision;
  final ValueChanged<String> onEnviarSolicitud;
  final VoidCallback onCancelarSolicitud;
 
  const _ItemValoracion({
    required this.valoracion,
    required this.solicitandoRevision,
    required this.onSolicitarRevision,
    required this.onEnviarSolicitud,
    required this.onCancelarSolicitud,
  });
 
  @override
  State<_ItemValoracion> createState() => _ItemValoracionState();
}
 
class _ItemValoracionState extends State<_ItemValoracion> {
  static const _motivos = ['Información falsa', 'Lenguaje ofensivo', 'No corresponde al servicio', 'Contenido inapropiado', 'Otro'];
 
  String? _motivoSeleccionado;
  final _motivoOtroController = TextEditingController();
 
  bool get _esOtro => _motivoSeleccionado == 'Otro';
  bool get _puedeEnviar => _motivoSeleccionado != null && (!_esOtro || _motivoOtroController.text.trim().isNotEmpty);
 
  void _enviar() {
    if (!_puedeEnviar) return;
    final motivoFinal = _esOtro ? _motivoOtroController.text.trim() : _motivoSeleccionado!;
    widget.onEnviarSolicitud(motivoFinal);
  }
 
  @override
  Widget build(BuildContext context) {
    final v = widget.valoracion;
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${v.autor}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Row(children: List.generate(5, (i) => Icon(Icons.star, size: 15, color: i < v.estrellas ? Colors.amber : Colors.grey.shade300))),
        const SizedBox(height: 4),
        Text(v.comentario, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        if (v.solicitudRevisionEnviada)
          Row(children: const [Icon(Icons.hourglass_top, size: 13, color: Colors.orange), SizedBox(width: 4), Text('Reporte enviado · Pendiente', style: TextStyle(fontSize: 12, color: Colors.orange))])
        else
          GestureDetector(
            onTap: widget.onSolicitarRevision,
            child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.flag_outlined, size: 13, color: Colors.deepPurple), SizedBox(width: 4), Text('Reportar', style: TextStyle(fontSize: 12, color: Colors.deepPurple))]),
          ),
        if (widget.solicitandoRevision) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reportar valoración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                for (final motivo in _motivos) ...[
                  _OpcionMotivo(texto: motivo, seleccionado: _motivoSeleccionado == motivo, onTap: () => setState(() => _motivoSeleccionado = motivo)),
                  const SizedBox(height: 6),
                ],
                if (_esOtro) ...[
                  TextField(
                    controller: _motivoOtroController,
                    maxLength: 300,
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(hintText: 'Escribe el motivo obligatorio...', hintStyle: const TextStyle(fontSize: 12), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: _puedeEnviar ? _enviar : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, disabledBackgroundColor: Colors.deepPurple.withOpacity(0.3), foregroundColor: Colors.white), child: const Text('Enviar'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: widget.onCancelarSolicitud, child: const Text('Cancelar'))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
 
class _OpcionMotivo extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;
 
  const _OpcionMotivo({required this.texto, required this.seleccionado, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: seleccionado ? Colors.deepPurple.withOpacity(0.08) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: seleccionado ? Colors.deepPurple : Colors.grey.shade300)),
        child: Row(children: [Icon(seleccionado ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: seleccionado ? Colors.deepPurple : Colors.grey), const SizedBox(width: 10), Text(texto, style: const TextStyle(fontSize: 13))]),
      ),
    );
  }
}
 
/// Aviso del administrador sobre la solicitud de puertas adentro.
class _AvisoAdministrador extends StatelessWidget {
  final NotificacionApp aviso;
  final VoidCallback onEntendido;
 
  const _AvisoAdministrador({required this.aviso, required this.onEntendido});
 
  @override
  Widget build(BuildContext context) {
    final aprobado = aviso.tipo == 'puertas_adentro_aprobada';
    final color = aprobado ? Colors.green : Colors.red;
 
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(aprobado ? Icons.check_circle_outline : Icons.cancel_outlined, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aviso del administrador',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(aviso.mensaje, style: const TextStyle(fontSize: 12)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onEntendido, child: const Text('Entendido')),
          ),
        ],
      ),
    );
  }
}