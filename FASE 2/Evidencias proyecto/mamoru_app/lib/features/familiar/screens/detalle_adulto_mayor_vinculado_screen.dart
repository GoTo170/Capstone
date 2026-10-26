import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../../../core/avatar_perfil.dart';
import '../../../core/foto_perfil_service.dart';
import '../models/perfil_adulto_mayor_vinculado.dart';
import '../services/familiar_service.dart';
 
class DetalleAdultoMayorVinculadoScreen extends StatefulWidget {
  final String adultoMayorId;
 
  const DetalleAdultoMayorVinculadoScreen({super.key, required this.adultoMayorId});
 
  @override
  State<DetalleAdultoMayorVinculadoScreen> createState() => _DetalleAdultoMayorVinculadoScreenState();
}
 
class _DetalleAdultoMayorVinculadoScreenState extends State<DetalleAdultoMayorVinculadoScreen> {
  late PerfilAdultoMayorVinculado _perfil;
  String? _fotoUrl;
  bool _cargando = true;
  String? _error;
 
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
      final detalle = await FamiliarService.detalleConFoto(widget.adultoMayorId);
 
      if (!mounted) return;
 
      setState(() {
        _perfil = detalle.perfil;
        _fotoUrl = detalle.fotoUrl;
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
 
  @override
  Widget build(BuildContext context) {
    if (_cargando || _error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF7F5),
        appBar: AppBar(backgroundColor: const Color(0xFFFFF7F5), elevation: 0),
        body: Center(
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
                    ],
                  ),
                ),
        ),
      );
    }
 
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFE3D9F6), Color(0xFFD9E6F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          AvatarFotoEditable(
                            radio: 28,
                            colorFondo: const Color(0xFFF6D998),
                            colorCamara: Colors.deepPurple,
                            sinFoto: const Icon(Icons.person, size: 30, color: Colors.white),
                            fotoUrl: _fotoUrl,
                            onElegida: (bytes) async {
                              final url = await FotoPerfilService.subirAdultoMayor(widget.adultoMayorId, bytes);
                              if (mounted) setState(() => _fotoUrl = url);
                            },
                            onQuitar: () async {
                              await FotoPerfilService.quitarAdultoMayor(widget.adultoMayorId);
                              if (mounted) setState(() => _fotoUrl = null);
                            },
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PERFIL DEL ADULTO MAYOR', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                              Text('${_perfil.nombre} ${_perfil.apellido}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              if (_perfil.perfilActivo)
                                Row(children: const [Icon(Icons.circle, size: 8, color: Colors.green), SizedBox(width: 4), Text('Perfil vinculado', style: TextStyle(fontSize: 11, color: Colors.green))]),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                          _DatoSoloLectura(etiqueta: 'NOMBRE Y APELLIDO', valor: '${_perfil.nombre} ${_perfil.apellido}'),
                          const SizedBox(height: 10),
                          _DatoSoloLectura(etiqueta: 'FECHA DE NACIMIENTO', valor: _perfil.fechaNacimientoTexto),
                          const SizedBox(height: 10),
                          _DatoSoloLectura(etiqueta: 'EDAD', valor: '${_perfil.edad} años'),
                          const SizedBox(height: 10),
                          _DatoSoloLectura(etiqueta: 'TELÉFONO', valor: _perfil.telefono),
                          const SizedBox(height: 10),
                          _DatoSoloLectura(etiqueta: 'RELACIÓN FAMILIAR', valor: _perfil.relacionFamiliar),
                          const SizedBox(height: 10),
                          _DatoSoloLectura(etiqueta: 'CORREO ELECTRÓNICO', valor: _perfil.correo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TarjetaBlanca(
                      titulo: 'Información de salud',
                      pendienteAprobacion: _perfil.saludPendienteAprobacion,
                      onEditar: () async {
                        final resultado = await Navigator.push<List<String>>(
                          context,
                          MaterialPageRoute(builder: (_) => _EditarListaScreen(titulo: 'Condiciones médicas', items: _perfil.condicionesMedicas, minCaracteres: 3, maxCaracteres: 70, maxItems: 30, ejemplo: 'Ej: Diabetes tipo 2')),
                        );
                        if (resultado != null) {
                          setState(() {
                            _perfil.condicionesMedicas = resultado;
                            _perfil.saludPendienteAprobacion = true;
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('CONDICIONES MÉDICAS', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.4)),
                          const SizedBox(height: 6),
                          _perfil.condicionesMedicas.isEmpty
                              ? const Text('Sin antecedentes registrados', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))
                              : Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _perfil.condicionesMedicas.map((c) => _Chip(texto: c, color: Colors.pink)).toList(),
                                ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('INDICACIONES IMPORTANTES', style: TextStyle(fontSize: 10, color: Colors.deepPurple, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                                const SizedBox(height: 4),
                                Text(_perfil.indicacionesImportantes, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TarjetaBlanca(
                      titulo: 'Alergias e intolerancias',
                      pendienteAprobacion: _perfil.alergiasPendienteAprobacion,
                      onEditar: () async {
                        final resultado = await Navigator.push<_ResultadoAlergias>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _EditarAlergiasScreen(
                              medicamentos: _perfil.alergiaMedicamentos,
                              alimentos: _perfil.alergiaAlimentos,
                              intolerancias: _perfil.intolerancias,
                            ),
                          ),
                        );
                        if (resultado != null) {
                          setState(() {
                            _perfil.alergiaMedicamentos = resultado.medicamentos;
                            _perfil.alergiaAlimentos = resultado.alimentos;
                            _perfil.intolerancias = resultado.intolerancias;
                            _perfil.alergiasPendienteAprobacion = true;
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BloqueAlergia(titulo: 'MEDICAMENTOS', items: _perfil.alergiaMedicamentos),
                          const SizedBox(height: 10),
                          _BloqueAlergia(titulo: 'ALIMENTOS', items: _perfil.alergiaAlimentos),
                          const SizedBox(height: 10),
                          _BloqueAlergia(titulo: 'INTOLERANCIAS', items: _perfil.intolerancias),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TarjetaBlanca(
                      titulo: 'Contactos de emergencia',
                      // Los contactos se guardan directamente (sin aprobación del administrador).
                      onEditar: () async {
                        final resultado = await Navigator.push<List<ContactoEmergenciaInfo>>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _EditarContactosScreen(
                              adultoMayorId: widget.adultoMayorId,
                              contactos: _perfil.contactosEmergencia,
                            ),
                          ),
                        );
                        if (resultado != null && mounted) {
                          setState(() => _perfil.contactosEmergencia = resultado);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contactos de emergencia actualizados'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final c in _perfil.contactosEmergencia) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: const Color(0xFFFFF3F1), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('${c.relacion} · ${c.telefono}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ],
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
 
// ---------- Widgets compartidos de lectura ----------
 
class _TarjetaBlanca extends StatelessWidget {
  final String titulo;
  final Widget child;
  final VoidCallback? onEditar;
  final bool pendienteAprobacion;
 
  const _TarjetaBlanca({required this.titulo, required this.child, this.onEditar, this.pendienteAprobacion = false});
 
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
              if (onEditar != null) TextButton(onPressed: onEditar, child: const Text('Editar')),
            ],
          ),
          if (pendienteAprobacion) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: const [
                  Icon(Icons.hourglass_top, size: 14, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(child: Text('Cambios pendientes de aprobación por el administrador.', style: TextStyle(fontSize: 11, color: Colors.orange))),
                ],
              ),
            ),
          ],
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
 
class _Chip extends StatelessWidget {
  final String texto;
  final Color color;
 
  const _Chip({required this.texto, required this.color});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
 
class _BloqueAlergia extends StatelessWidget {
  final String titulo;
  final List<String> items;
 
  const _BloqueAlergia({required this.titulo, required this.items});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        items.isEmpty
            ? Text('Sin ${titulo.toLowerCase()} registradas', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))
            : Wrap(spacing: 6, runSpacing: 6, children: items.map((i) => _Chip(texto: i, color: Colors.deepOrange)).toList()),
      ],
    );
  }
}
 
// ---------- Pantallas de edición ----------
 
class _EditarListaScreen extends StatefulWidget {
  final String titulo;
  final List<String> items;
  final int minCaracteres;
  final int maxCaracteres;
  final int maxItems;
  final String ejemplo;
 
  const _EditarListaScreen({
    required this.titulo,
    required this.items,
    required this.minCaracteres,
    required this.maxCaracteres,
    required this.maxItems,
    required this.ejemplo,
  });
 
  @override
  State<_EditarListaScreen> createState() => _EditarListaScreenState();
}
 
class _EditarListaScreenState extends State<_EditarListaScreen> {
  late List<TextEditingController> _controladores = widget.items.isEmpty
      ? [TextEditingController()]
      : widget.items.map((i) => TextEditingController(text: i)).toList();
  bool _formularioFueEnviado = false;
 
  bool _itemValido(String texto) {
    final largo = texto.trim().length;
    return largo >= widget.minCaracteres && largo <= widget.maxCaracteres;
  }
 
  bool get _todoValido => _controladores.every((c) => _itemValido(c.text));
 
  void _agregar() {
    if (_controladores.length >= widget.maxItems) return;
    setState(() => _controladores.add(TextEditingController()));
  }
 
  void _eliminar(int index) {
    if (_controladores.length <= 1) return;
    setState(() => _controladores.removeAt(index));
  }
 
  void _guardar() {
    setState(() => _formularioFueEnviado = true);
    if (!_todoValido) return;
    Navigator.pop(context, _controladores.map((c) => c.text.trim()).toList());
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      appBar: AppBar(title: Text('Editar: ${widget.titulo}'), backgroundColor: const Color(0xFFFFF7F5), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (int i = 0; i < _controladores.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controladores[i],
                            maxLength: widget.maxCaracteres,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: widget.ejemplo,
                              counterText: '',
                              helperText: _formularioFueEnviado && !_itemValido(_controladores[i].text) ? 'Entre ${widget.minCaracteres} y ${widget.maxCaracteres} caracteres.' : null,
                              helperStyle: const TextStyle(color: Colors.red, fontSize: 11),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _formularioFueEnviado && !_itemValido(_controladores[i].text) ? Colors.red : Colors.grey.shade300, width: 2)),
                            ),
                          ),
                        ),
                        if (_controladores.length > 1) IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => _eliminar(i)),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_controladores.length < widget.maxItems)
                    TextButton.icon(onPressed: _agregar, icon: const Icon(Icons.add), label: const Text('Agregar')),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Enviar cambios para aprobación'),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _ResultadoAlergias {
  final List<String> medicamentos;
  final List<String> alimentos;
  final List<String> intolerancias;
 
  const _ResultadoAlergias({required this.medicamentos, required this.alimentos, required this.intolerancias});
}
 
class _EditarAlergiasScreen extends StatefulWidget {
  final List<String> medicamentos;
  final List<String> alimentos;
  final List<String> intolerancias;
 
  const _EditarAlergiasScreen({required this.medicamentos, required this.alimentos, required this.intolerancias});
 
  @override
  State<_EditarAlergiasScreen> createState() => _EditarAlergiasScreenState();
}
 
class _EditarAlergiasScreenState extends State<_EditarAlergiasScreen> {
  late List<TextEditingController> _medControllers = widget.medicamentos.map((e) => TextEditingController(text: e)).toList();
  late List<TextEditingController> _aliControllers = widget.alimentos.map((e) => TextEditingController(text: e)).toList();
  late List<TextEditingController> _intControllers = widget.intolerancias.map((e) => TextEditingController(text: e)).toList();
  bool _formularioFueEnviado = false;
 
  bool _valido(String t, int min, int max) => t.trim().length >= min && t.trim().length <= max;
 
  bool get _todoValido =>
      _medControllers.every((c) => _valido(c.text, 3, 45)) &&
      _aliControllers.every((c) => _valido(c.text, 3, 35)) &&
      _intControllers.every((c) => _valido(c.text, 3, 35));
 
  void _guardar() {
    setState(() => _formularioFueEnviado = true);
    if (!_todoValido) return;
    Navigator.pop(
      context,
      _ResultadoAlergias(
        medicamentos: _medControllers.map((c) => c.text.trim()).toList(),
        alimentos: _aliControllers.map((c) => c.text.trim()).toList(),
        intolerancias: _intControllers.map((c) => c.text.trim()).toList(),
      ),
    );
  }
 
  Widget _bloque(String titulo, List<TextEditingController> controllers, int max, int min, int maxCar, String hint, VoidCallback onAgregar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (int i = 0; i < controllers.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  maxLength: maxCar,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: hint,
                    counterText: '',
                    helperText: _formularioFueEnviado && !_valido(controllers[i].text, min, maxCar) ? 'Entre $min y $maxCar caracteres.' : null,
                    helperStyle: const TextStyle(color: Colors.red, fontSize: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => setState(() => controllers.removeAt(i))),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (controllers.length < max) TextButton.icon(onPressed: onAgregar, icon: const Icon(Icons.add), label: const Text('Agregar')),
      ],
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      appBar: AppBar(title: const Text('Editar alergias e intolerancias'), backgroundColor: const Color(0xFFFFF7F5), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  _bloque('Medicamentos', _medControllers, 15, 3, 45, 'Ej: Penicilina', () => setState(() => _medControllers.add(TextEditingController()))),
                  const SizedBox(height: 20),
                  _bloque('Alimentos', _aliControllers, 40, 3, 35, 'Ej: Mariscos', () => setState(() => _aliControllers.add(TextEditingController()))),
                  const SizedBox(height: 20),
                  _bloque('Intolerancias', _intControllers, 10, 3, 35, 'Ej: Lactosa', () => setState(() => _intControllers.add(TextEditingController()))),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Enviar cambios para aprobación'),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _EditarContactosScreen extends StatefulWidget {
  final String adultoMayorId;
  final List<ContactoEmergenciaInfo> contactos;
 
  const _EditarContactosScreen({required this.adultoMayorId, required this.contactos});
 
  @override
  State<_EditarContactosScreen> createState() => _EditarContactosScreenState();
}
 
class _EditarContactosScreenState extends State<_EditarContactosScreen> {
  static const _opcionesRelacion = ['Hijo/a', 'Nieto/a', 'Sobrino/a', 'Amigo/a', 'Vecino/a', 'Otro'];
  late List<_ContactoEditable> _contactos = widget.contactos.map((c) => _ContactoEditable.desde(c)).toList();
  bool _formularioFueEnviado = false;
  bool _guardando = false;
 
  bool _telefonoValido(String t) => t.replaceAll(RegExp(r'[^0-9]'), '').length >= 8 && t.trim().length <= 20;
 
  bool _contactoValido(_ContactoEditable c) => c.nombre.text.trim().isNotEmpty && _telefonoValido(c.telefono.text) && c.relacion != null;
  bool get _todoValido => _contactos.isNotEmpty && _contactos.every(_contactoValido);
 
  Future<void> _guardar() async {
    setState(() => _formularioFueEnviado = true);
    if (!_todoValido || _guardando) return;
 
    setState(() => _guardando = true);
    try {
      final guardados = await FamiliarService.actualizarContactos(
        widget.adultoMayorId,
        _contactos.map((c) => ContactoEmergenciaInfo(nombre: c.nombre.text.trim(), telefono: c.telefono.text.trim(), relacion: c.relacion!)).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, guardados);
    } on ErrorContactos catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      appBar: AppBar(title: const Text('Editar contactos de emergencia'), backgroundColor: const Color(0xFFFFF7F5), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  for (int i = 0; i < _contactos.length; i++) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3F1), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text('Contacto ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
                              const Spacer(),
                              if (_contactos.length > 1) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _contactos.removeAt(i))),
                            ],
                          ),
                          TextField(
                            controller: _contactos[i].nombre,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Nombre',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _formularioFueEnviado && _contactos[i].nombre.text.trim().isEmpty ? Colors.red : Colors.grey.shade300)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _contactos[i].telefono,
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Teléfono (ej: +56912345678)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _formularioFueEnviado && !_telefonoValido(_contactos[i].telefono.text) ? Colors.red : Colors.grey.shade300)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _opcionesRelacion.map((op) {
                              final sel = _contactos[i].relacion == op;
                              return ChoiceChip(
                                label: Text(op, style: const TextStyle(fontSize: 12)),
                                selected: sel,
                                onSelected: (_) => setState(() => _contactos[i].relacion = op),
                                selectedColor: Colors.pink,
                                labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_contactos.length < 3)
                    TextButton.icon(
                      onPressed: () => setState(() => _contactos.add(_ContactoEditable())),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar otro contacto'),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _guardando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _ContactoEditable {
  final TextEditingController nombre;
  final TextEditingController telefono;
  String? relacion;
 
  _ContactoEditable({String nombreInicial = '', String telefonoInicial = '', this.relacion})
      : nombre = TextEditingController(text: nombreInicial),
        telefono = TextEditingController(text: telefonoInicial);
 
  factory _ContactoEditable.desde(ContactoEmergenciaInfo c) =>
      _ContactoEditable(nombreInicial: c.nombre, telefonoInicial: c.telefono, relacion: c.relacion);
}