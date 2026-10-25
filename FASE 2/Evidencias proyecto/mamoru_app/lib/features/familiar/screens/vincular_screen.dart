import 'package:flutter/material.dart';
import '../models/categoria_salud.dart';
import '../../../core/api_exception.dart';
import '../services/familiar_service.dart';
import 'invitacion_generada_screen.dart';

class VincularScreen extends StatefulWidget {
  const VincularScreen({super.key});

  @override
  State<VincularScreen> createState() => _VincularScreenState();
}

class ContactoEmergencia {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  String? relacion;
  final TextEditingController relacionOtroController = TextEditingController();
}

class _VincularScreenState extends State<VincularScreen> {
  final _nombreAdultoController = TextEditingController();
  final _apellidoAdultoController = TextEditingController();
  String? _relacionFamiliar;
  final _relacionFamiliarOtroController = TextEditingController();
  DateTime? _fechaNacimiento;

  final List<ContactoEmergencia> _contactos = [ContactoEmergencia()];

  late final CategoriaSalud _enfermedades = CategoriaSalud(
    nombre: 'Enfermedades o condiciones',
    preguntaCorta: '¿Tiene alguna enfermedad o condición de salud?',
    maxItems: 30,
    minCaracteres: 3,
    maxCaracteres: 70,
    ejemplo: 'Ej: Diabetes tipo 2',
  );
  late final CategoriaSalud _alergiaMedicamentos = CategoriaSalud(
    nombre: 'Alergia a medicamentos',
    preguntaCorta: '¿Tiene alergia a algún medicamento?',
    maxItems: 15,
    minCaracteres: 3,
    maxCaracteres: 45,
    ejemplo: 'Ej: Penicilina',
  );
  late final CategoriaSalud _alergiaAlimentos = CategoriaSalud(
    nombre: 'Alergia a alimentos',
    preguntaCorta: '¿Tiene alergia a algún alimento?',
    maxItems: 40,
    minCaracteres: 3,
    maxCaracteres: 35,
    ejemplo: 'Ej: Mariscos',
  );
  late final CategoriaSalud _intolerancias = CategoriaSalud(
    nombre: 'Intolerancias alimentarias',
    preguntaCorta: '¿Tiene alguna intolerancia alimentaria?',
    maxItems: 10,
    minCaracteres: 3,
    maxCaracteres: 35,
    ejemplo: 'Ej: Lactosa',
  );

  List<CategoriaSalud> get _categoriasSalud => [_enfermedades, _alergiaMedicamentos, _alergiaAlimentos, _intolerancias];

  bool _formularioFueEnviado = false;
  bool _enviando = false;

  static const _opcionesRelacionFamiliar = ['Madre', 'Padre', 'Abuela', 'Abuelo', 'Tía', 'Tío', 'Cónyuge', 'Otro'];
  static const _opcionesRelacionContacto = ['Hijo/a', 'Nieto/a', 'Sobrino/a', 'Amigo/a', 'Vecino/a', 'Otro'];

  static const int _edadMinima = 60;

  int _calcularEdad(DateTime nacimiento) {
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }

  bool get _fechaNacimientoValida =>
      _fechaNacimiento != null && _calcularEdad(_fechaNacimiento!) >= _edadMinima;

  String? get _errorFechaNacimiento {
    final fecha = _fechaNacimiento;
    if (fecha == null) {
      return _formularioFueEnviado ? 'Selecciona la fecha de nacimiento.' : null;
    }
    if (_calcularEdad(fecha) < _edadMinima) {
      return 'El adulto mayor debe tener al menos $_edadMinima años. No es posible generar la invitación.';
    }
    return null;
  }

  String _textoFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  Future<void> _elegirFechaNacimiento() async {
    final hoy = DateTime.now();
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(hoy.year - 70, 1, 1),
      firstDate: DateTime(1900),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
    );
    if (seleccionada != null) {
      setState(() => _fechaNacimiento = seleccionada);
    }
  }

  /// Junta los ítems de una categoría de salud (uno por línea).
  /// Si respondió "No" (o no escribió nada), no se envía nada.
  String? _textoSalud(CategoriaSalud categoria) {
    if (categoria.tiene != true) return null;
    final items = categoria.itemsControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return items.isEmpty ? null : items.join('\n');
  }

  bool get _datosAdultoValidos =>
      _nombreAdultoController.text.trim().isNotEmpty &&
      _apellidoAdultoController.text.trim().isNotEmpty &&
      _fechaNacimientoValida &&
      _relacionFamiliar != null &&
      (_relacionFamiliar != 'Otro' || _relacionFamiliarOtroController.text.trim().isNotEmpty);

  bool get _saludValida => _categoriasSalud.every((c) => c.respondida && c.itemValido);

  bool _contactoValido(ContactoEmergencia c) =>
      c.nombreController.text.trim().isNotEmpty &&
      c.telefonoController.text.trim().isNotEmpty &&
      c.relacion != null &&
      (c.relacion != 'Otro' || c.relacionOtroController.text.trim().isNotEmpty);

  bool get _contactosValidos => _contactos.every(_contactoValido);

  void _elegirRespuestaSalud(CategoriaSalud categoria, bool respuesta) {
    setState(() {
      categoria.tiene = respuesta;
      if (respuesta && categoria.itemsControllers.isEmpty) {
        categoria.itemsControllers.add(TextEditingController());
      }
      if (!respuesta) {
        categoria.itemsControllers.clear();
      }
    });
  }

  void _agregarItemSalud(CategoriaSalud categoria) {
    if (categoria.itemsControllers.length >= categoria.maxItems) return;
    setState(() => categoria.itemsControllers.add(TextEditingController()));
  }

  void _eliminarItemSalud(CategoriaSalud categoria, int index) {
    if (categoria.itemsControllers.length <= 1) return;
    setState(() => categoria.itemsControllers.removeAt(index));
  }

  void _agregarContacto() {
    if (_contactos.length >= 3) return;
    setState(() => _contactos.add(ContactoEmergencia()));
  }

  void _eliminarContacto(int index) {
    if (_contactos.length <= 1) return;
    setState(() => _contactos.removeAt(index));
  }

  Future<void> _generarInvitacion() async {
    setState(() => _formularioFueEnviado = true);

    if (!_datosAdultoValidos || !_saludValida || !_contactosValidos) return;
    if (_enviando) return;

    setState(() => _enviando = true);

    try {
      final invitacion = await FamiliarService.crearAdultoMayor(
        nombre: _nombreAdultoController.text.trim(),
        apellido: _apellidoAdultoController.text.trim(),
        fechaNacimiento: _fechaNacimiento!,
        relacionFamiliar: _relacionFamiliar == 'Otro'
            ? _relacionFamiliarOtroController.text.trim()
            : _relacionFamiliar!,
        enfermedades: _textoSalud(_enfermedades),
        alergiaMedicamentos: _textoSalud(_alergiaMedicamentos),
        alergiaAlimentos: _textoSalud(_alergiaAlimentos),
        intoleranciaAlimentaria: _textoSalud(_intolerancias),
        contactos: [
          for (int i = 0; i < _contactos.length; i++)
            {
              'nombre': _contactos[i].nombreController.text.trim(),
              'telefono': _contactos[i].telefonoController.text.trim(),
              'parentesco': _contactos[i].relacion == 'Otro'
                  ? _contactos[i].relacionOtroController.text.trim()
                  : _contactos[i].relacion,
              'orden': i + 1,
            },
        ],
      );

      if (!mounted) return;

      // pushReplacement: así, al volver atrás no se regresa al formulario
      // lleno (y no se crea el mismo adulto mayor dos veces por error).
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvitacionGeneradaScreen(
            nombreAdultoMayor: invitacion.nombreAdultoMayor,
            codigo: invitacion.codigo,
            adultoMayorId: invitacion.adultoMayorId,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.mensaje),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EncabezadoRosado(
                icono: Icons.link,
                titulo: 'Vincular adulto mayor',
                descripcion:
                    'Genera una invitación para que el adulto mayor pueda acceder a Mamoru sin necesidad de crear una cuenta ni ingresar una contraseña.',
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TarjetaSeccion(
                      numero: 1,
                      titulo: 'Datos del adulto mayor',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _CampoConEtiqueta(
                                  etiqueta: 'NOMBRE',
                                  controller: _nombreAdultoController,
                                  conError: _formularioFueEnviado && _nombreAdultoController.text.trim().isEmpty,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CampoConEtiqueta(
                                  etiqueta: 'APELLIDO',
                                  controller: _apellidoAdultoController,
                                  conError: _formularioFueEnviado && _apellidoAdultoController.text.trim().isEmpty,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _EtiquetaCampo(texto: 'FECHA DE NACIMIENTO', conError: _errorFechaNacimiento != null),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _elegirFechaNacimiento,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _errorFechaNacimiento != null ? Colors.red : Colors.grey.shade300,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _fechaNacimiento == null ? 'Selecciona una fecha' : _textoFecha(_fechaNacimiento!),
                                      style: TextStyle(color: _fechaNacimiento == null ? Colors.grey : Colors.black),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _errorFechaNacimiento ?? 'El adulto mayor debe tener 60 años o más.',
                            style: TextStyle(fontSize: 12, color: _errorFechaNacimiento != null ? Colors.red : Colors.grey),
                          ),
                          const SizedBox(height: 14),
                          _EtiquetaCampo(texto: 'RELACIÓN FAMILIAR', conError: _formularioFueEnviado && _relacionFamiliar == null),
                          const SizedBox(height: 6),
                          _GrupoChips(
                            opciones: _opcionesRelacionFamiliar,
                            seleccionado: _relacionFamiliar,
                            onSeleccionar: (v) => setState(() => _relacionFamiliar = v),
                          ),
                          if (_relacionFamiliar == 'Otro') ...[
                            const SizedBox(height: 10),
                            _CampoConEtiqueta(
                              etiqueta: '¿CUÁL ES LA RELACIÓN?',
                              controller: _relacionFamiliarOtroController,
                              conError: _formularioFueEnviado && _relacionFamiliarOtroController.text.trim().isEmpty,
                              onChanged: (_) => setState(() {}),
                              hint: 'Ej: Madrina',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TarjetaSeccion(
                      numero: 2,
                      titulo: 'Información de salud',
                      etiquetaExtra: 'Opcional',
                      subtitulo: 'Esta información será visible para el cuidador asignado en la sección de información importante del servicio.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < _categoriasSalud.length; i++) ...[
                            _SeccionSalud(
                              categoria: _categoriasSalud[i],
                              formularioFueEnviado: _formularioFueEnviado,
                              onResponder: (v) => _elegirRespuestaSalud(_categoriasSalud[i], v),
                              onAgregarItem: () => _agregarItemSalud(_categoriasSalud[i]),
                              onEliminarItem: (index) => _eliminarItemSalud(_categoriasSalud[i], index),
                              onChanged: () => setState(() {}),
                            ),
                            if (i != _categoriasSalud.length - 1) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TarjetaSeccion(
                      numero: 3,
                      titulo: 'Contactos de emergencia',
                      etiquetaExtra: 'Máx. 3',
                      subtitulo: 'Personas que serán notificadas en caso de emergencia.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < _contactos.length; i++) ...[
                            _TarjetaContacto(
                              numero: i + 1,
                              contacto: _contactos[i],
                              opcionesRelacion: _opcionesRelacionContacto,
                              formularioFueEnviado: _formularioFueEnviado,
                              onChanged: () => setState(() {}),
                              onEliminar: _contactos.length > 1 ? () => _eliminarContacto(i) : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_contactos.length < 3)
                            OutlinedButton.icon(
                              onPressed: _agregarContacto,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar otro contacto'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.pink,
                                side: const BorderSide(color: Colors.pink),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _enviando ? null : _generarInvitacion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _enviando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Generar invitación  →', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'La invitación será válida por 48 horas y permitirá vincular al adulto mayor con tu cuenta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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

// ---------- Sección de Información de salud ----------

class _SeccionSalud extends StatelessWidget {
  final CategoriaSalud categoria;
  final bool formularioFueEnviado;
  final ValueChanged<bool> onResponder;
  final VoidCallback onAgregarItem;
  final ValueChanged<int> onEliminarItem;
  final VoidCallback onChanged;

  const _SeccionSalud({
    required this.categoria,
    required this.formularioFueEnviado,
    required this.onResponder,
    required this.onAgregarItem,
    required this.onEliminarItem,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sinResponder = formularioFueEnviado && !categoria.respondida;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          categoria.preguntaCorta,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: sinResponder ? Colors.red : Colors.black87),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _BotonSiNo(
                texto: 'Sí',
                seleccionado: categoria.tiene == true,
                color: Colors.green,
                onTap: () => onResponder(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BotonSiNo(
                texto: 'No',
                seleccionado: categoria.tiene == false,
                color: Colors.grey.shade700,
                onTap: () => onResponder(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (categoria.tiene == false)
          const Text('Sin antecedentes registrados', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
        if (categoria.tiene == true) ...[
          for (int i = 0; i < categoria.itemsControllers.length; i++) ...[
            _ItemSalud(
              controller: categoria.itemsControllers[i],
              hint: categoria.ejemplo,
              minCaracteres: categoria.minCaracteres,
              maxCaracteres: categoria.maxCaracteres,
              formularioFueEnviado: formularioFueEnviado,
              onChanged: onChanged,
              onEliminar: categoria.itemsControllers.length > 1 ? () => onEliminarItem(i) : null,
            ),
            const SizedBox(height: 8),
          ],
          if (categoria.itemsControllers.length < categoria.maxItems)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAgregarItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: TextButton.styleFrom(foregroundColor: Colors.pink),
              ),
            )
          else
            Text('Máximo de ${categoria.maxItems} alcanzado', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
        if (sinResponder)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Selecciona Sí o No.', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}

class _BotonSiNo extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  const _BotonSiNo({required this.texto, required this.seleccionado, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: seleccionado ? color : Colors.grey.shade300, width: seleccionado ? 2 : 1),
        ),
        child: Text(texto, textAlign: TextAlign.center, style: TextStyle(color: seleccionado ? color : Colors.black87, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ItemSalud extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int minCaracteres;
  final int maxCaracteres;
  final bool formularioFueEnviado;
  final VoidCallback onChanged;
  final VoidCallback? onEliminar;

  const _ItemSalud({
    required this.controller,
    required this.hint,
    required this.minCaracteres,
    required this.maxCaracteres,
    required this.formularioFueEnviado,
    required this.onChanged,
    required this.onEliminar,
  });

  bool get _valido {
    final largo = controller.text.trim().length;
    return largo >= minCaracteres && largo <= maxCaracteres;
  }

  @override
  Widget build(BuildContext context) {
    final mostrarError = formularioFueEnviado && !_valido;
    final borderColor = mostrarError ? Colors.red : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLength: maxCaracteres,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              counterText: '',
              helperText: mostrarError ? 'Entre $minCaracteres y $maxCaracteres caracteres.' : null,
              helperStyle: const TextStyle(color: Colors.red, fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2), borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2), borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2), borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        if (onEliminar != null)
          IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: onEliminar),
      ],
    );
  }
}

// ---------- Widgets ya existentes (sin cambios) ----------

class _EncabezadoRosado extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const _EncabezadoRosado({required this.icono, required this.titulo, required this.descripcion});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFBD5D8), Color(0xFFFDEDEB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icono, color: Colors.pink[700], size: 20),
                      const SizedBox(width: 8),
                      Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(descripcion, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaSeccion extends StatelessWidget {
  final int numero;
  final String titulo;
  final String? subtitulo;
  final String? etiquetaExtra;
  final Widget child;

  const _TarjetaSeccion({required this.numero, required this.titulo, this.subtitulo, this.etiquetaExtra, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.pink[100],
                child: Text('$numero', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pink[700])),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              if (etiquetaExtra != null) Text(etiquetaExtra!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.only(left: 32), child: Text(subtitulo!, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EtiquetaCampo extends StatelessWidget {
  final String texto;
  final bool conError;

  const _EtiquetaCampo({required this.texto, required this.conError});

  @override
  Widget build(BuildContext context) {
    return Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.4, color: conError ? Colors.red : Colors.grey[600]));
  }
}

class _CampoConEtiqueta extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controller;
  final bool conError;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextInputType keyboardType;

  const _CampoConEtiqueta({
    required this.etiqueta,
    required this.controller,
    required this.conError,
    required this.onChanged,
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = conError ? Colors.red : Colors.grey.shade300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EtiquetaCampo(texto: etiqueta, conError: conError),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2), borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2), borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2), borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _GrupoChips extends StatelessWidget {
  final List<String> opciones;
  final String? seleccionado;
  final ValueChanged<String> onSeleccionar;

  const _GrupoChips({required this.opciones, required this.seleccionado, required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((opcion) {
        final seleccionadoActual = seleccionado == opcion;
        return InkWell(
          onTap: () => onSeleccionar(opcion),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: seleccionadoActual ? Colors.pink : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: seleccionadoActual ? Colors.pink : Colors.grey.shade300),
            ),
            child: Text(opcion, style: TextStyle(fontSize: 13, color: seleccionadoActual ? Colors.white : Colors.black87)),
          ),
        );
      }).toList(),
    );
  }
}

class _TarjetaContacto extends StatelessWidget {
  final int numero;
  final ContactoEmergencia contacto;
  final List<String> opcionesRelacion;
  final bool formularioFueEnviado;
  final VoidCallback onChanged;
  final VoidCallback? onEliminar;

  const _TarjetaContacto({
    required this.numero,
    required this.contacto,
    required this.opcionesRelacion,
    required this.formularioFueEnviado,
    required this.onChanged,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF3F1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Contacto $numero', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
              const Spacer(),
              if (onEliminar != null) IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: onEliminar),
            ],
          ),
          _CampoConEtiqueta(
            etiqueta: 'NOMBRE DEL CONTACTO',
            controller: contacto.nombreController,
            conError: formularioFueEnviado && contacto.nombreController.text.trim().isEmpty,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          _CampoConEtiqueta(
            etiqueta: 'NÚMERO DE TELÉFONO',
            controller: contacto.telefonoController,
            conError: formularioFueEnviado && contacto.telefonoController.text.trim().isEmpty,
            onChanged: (_) => onChanged(),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _EtiquetaCampo(texto: 'RELACIÓN CON EL ADULTO MAYOR', conError: formularioFueEnviado && contacto.relacion == null),
          const SizedBox(height: 6),
          _GrupoChips(
            opciones: opcionesRelacion,
            seleccionado: contacto.relacion,
            onSeleccionar: (v) {
              contacto.relacion = v;
              onChanged();
            },
          ),
          if (contacto.relacion == 'Otro') ...[
            const SizedBox(height: 10),
            _CampoConEtiqueta(
              etiqueta: '¿CUÁL ES LA RELACIÓN?',
              controller: contacto.relacionOtroController,
              conError: formularioFueEnviado && contacto.relacionOtroController.text.trim().isEmpty,
              onChanged: (_) => onChanged(),
              hint: 'Ej: Cuidadora de confianza',
            ),
          ],
        ],
      ),
    );
  }
}