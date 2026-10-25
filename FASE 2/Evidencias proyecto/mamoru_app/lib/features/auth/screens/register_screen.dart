import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'cuenta_pendiente_validacion_screen.dart';

import '../models/profesion_cuidador.dart';
import '../widgets/password_requirements_grid.dart';
import '../../../core/api_exception.dart';
import '../services/auth_service.dart';
import '../widgets/validated_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  final _referenciaTelefonoController = TextEditingController();
  final _referenciaCorreoController = TextEditingController();
  final _experienciaController = TextEditingController();

  String? _rolSeleccionado;
  ProfesionCuidador? _profesion;
  PlatformFile? _documentoSeleccionado;
  bool? _puertasAdentro;

  bool _passwordVisible = false;
  bool _confirmarPasswordVisible = false;
  bool _formularioFueEnviado = false;
  bool _enviando = false;

  static const _caracteresEspeciales = r'''!@#$%^&*()_+\-=\[\]{}|;:'",.<>/?~`\\''';

  // Letras (incluye acentuadas/ñ/ü/Ā), espacio, guion y apóstrofe. Nada de números ni otros símbolos.
  static final RegExp _nombreRegex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-ſ' -]+$");

  bool get _esCuidador => _rolSeleccionado == 'cuidador';

  bool _nombreValidoTexto(String texto) {
    final limpio = texto.trim();
    if (limpio.length < 2 || limpio.length > 50) return false;
    return _nombreRegex.hasMatch(limpio);
  }

  String _errorNombre(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return 'Ingresa tu nombre.';
    if (limpio.length < 2) return 'Debe tener al menos 2 caracteres.';
    if (limpio.length > 50) return 'Máximo 50 caracteres.';
    return 'Solo se permiten letras, espacios, guion (-) y apóstrofe (\').';
  }

  bool get _nombreValido => _nombreValidoTexto(_nombreController.text);
  bool get _apellidoValido => _nombreValidoTexto(_apellidoController.text);
  bool get _rolValido => _rolSeleccionado != null;
  bool get _profesionValida => !_esCuidador || _profesion != null;
  bool get _documentoValido => !_esCuidador || _profesion == null || !_profesion!.requiereDocumento || _documentoSeleccionado != null;
  bool get _requiereExperiencia => _profesion != null && _profesion!.requiereDocumento;

  bool get _experienciaValida {
    if (!_requiereExperiencia) return true;
    final valor = int.tryParse(_experienciaController.text.trim());
    return valor != null && valor >= 0;
  }

  bool get _referenciaValida =>
      _profesion?.documentoRequerido != TipoDocumentoRequerido.cartaRecomendacion ||
      (_referenciaTelefonoController.text.trim().isNotEmpty && _referenciaCorreoController.text.trim().isNotEmpty);

  bool get _puertasAdentroRespondida => !_esCuidador || _profesion == null || !_profesion!.admitePuertasAdentro || _puertasAdentro != null;

  bool get _emailValido =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(_emailController.text.trim());

  Map<String, bool> get _requisitosPassword {
    final p = _passwordController.text;
    return {
      'Mínimo 4 caracteres': p.length >= 4,
      '1 mayúscula': RegExp(r'[A-Z]').hasMatch(p),
      '1 minúscula': RegExp(r'[a-z]').hasMatch(p),
      '1 número': RegExp(r'[0-9]').hasMatch(p),
      '1 carácter especial (incluye . y ,)': RegExp('[$_caracteresEspeciales]').hasMatch(p),
    };
  }

  bool get _passwordValida => _requisitosPassword.values.every((v) => v);

  bool get _confirmacionValida =>
      _confirmarPasswordController.text.isNotEmpty &&
      _confirmarPasswordController.text == _passwordController.text;

  bool? _estadoCampo(bool valido, TextEditingController controller) {
    if (!_formularioFueEnviado && controller.text.isEmpty) return null;
    return valido;
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

  Future<void> _elegirProfesion() async {
    final seleccion = await showModalBottomSheet<ProfesionCuidador>(
      context: context,
      backgroundColor: const Color(0xFFFFF7F5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final categorias = CategoriaProfesion.values;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Selecciona tu profesión u oficio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final categoria in categorias) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(etiquetaCategoria(categoria), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        for (final p in catalogoProfesiones.where((p) => p.categoria == categoria))
                          ListTile(
                            dense: true,
                            title: Text(p.nombre),
                            onTap: () => Navigator.pop(context, p),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (seleccion != null) {
      setState(() {
        _profesion = seleccion;
        _documentoSeleccionado = null;
        _puertasAdentro = null;
        _referenciaTelefonoController.clear();
        _referenciaCorreoController.clear();
      });
    }
  }

  Future<void> _seleccionarDocumento() async {
  final PlatformFile? archivo = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
  );

  if (archivo != null) {
    setState(() {
      _documentoSeleccionado = archivo;
    });
  }
}

  Future<void> _crearCuenta() async {
    setState(() {
      _formularioFueEnviado = true;
    });

    final todoValido =
        _nombreValido &&
        _apellidoValido &&
        _emailValido &&
        _passwordValida &&
        _confirmacionValida &&
        _rolValido &&
        _profesionValida &&
        _documentoValido &&
        _experienciaValida &&
        _referenciaValida &&
        _puertasAdentroRespondida;

    if (!todoValido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisa los campos marcados antes de continuar.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    if (_enviando) return;

    setState(() {
      _enviando = true;
    });

    final email = _emailController.text.trim();
    final mensajero = ScaffoldMessenger.of(context);

    // TODO (siguientes etapas):
    // - Verificación del correo con código de 6 dígitos (requiere servicio
    //   de envío de correos en el backend).
    // - Subir el documento que respalda la profesión (_documentoSeleccionado)
    //   y los datos de la carta de recomendación.

    try {
      await AuthService.registrar(
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        email: email,
        password: _passwordController.text,
        rol: _rolSeleccionado!,
        profesion: _profesion?.nombre,
        esAreaSalud: _profesion?.categoria == CategoriaProfesion.areaSalud,
        experiencia: _requiereExperiencia
            ? '${_experienciaController.text.trim()} años de experiencia'
            : null,
        serviciosOfrecidos:
            _puertasAdentro == true ? 'Cuidado puertas adentro' : null,
      );

      if (!mounted) return;

      if (_esCuidador) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CuentaPendienteValidacionScreen(email: email),
          ),
          (route) => route.isFirst,
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);

        mensajero.showSnackBar(
          const SnackBar(
            content: Text(
              'Cuenta creada correctamente. Ya puedes iniciar sesión.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(e.mensaje),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Crear cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Únete a Mamoru', style: TextStyle(fontSize: 12, color: Colors.pink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValidatedTextField(
                      controller: _nombreController,
                      label: 'NOMBRE',
                      hint: 'Tu nombre',
                      isValid: _estadoCampo(_nombreValido, _nombreController),
                      errorText: _errorNombre(_nombreController.text),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      controller: _apellidoController,
                      label: 'APELLIDO',
                      hint: 'Tu apellido',
                      isValid: _estadoCampo(_apellidoValido, _apellidoController),
                      errorText: _errorNombre(_apellidoController.text),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      controller: _emailController,
                      label: 'CORREO ELECTRÓNICO',
                      hint: 'tucorreo@ejemplo.com',
                      isValid: _estadoCampo(_emailValido, _emailController),
                      errorText: _emailController.text.trim().isEmpty
                          ? 'Ingresa tu correo electrónico.'
                          : 'El correo ingresado no tiene un formato válido.',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      controller: _passwordController,
                      label: 'CONTRASEÑA',
                      hint: 'Crea tu contraseña',
                      isValid: _estadoCampo(_passwordValida, _passwordController),
                      obscureText: !_passwordVisible,
                      onChanged: (_) => setState(() {}),
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PasswordRequirementsGrid(requisitos: _requisitosPassword),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      controller: _confirmarPasswordController,
                      label: 'CONFIRMAR CONTRASEÑA',
                      hint: 'Repite tu contraseña',
                      isValid: _estadoCampo(_confirmacionValida, _confirmarPasswordController),
                      errorText: _confirmarPasswordController.text.isEmpty
                          ? 'Confirma tu contraseña.'
                          : 'Las contraseñas no coinciden.',
                      obscureText: !_confirmarPasswordVisible,
                      onChanged: (_) => setState(() {}),
                      suffixIcon: IconButton(
                        icon: Icon(_confirmarPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _confirmarPasswordVisible = !_confirmarPasswordVisible),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'SELECCIONA TU ROL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: _formularioFueEnviado && !_rolValido ? Colors.red : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _TarjetaRol(
                      icono: Icons.groups_rounded,
                      colorFondo: const Color(0xFFFBDCE5),
                      colorIcono: Colors.pink,
                      titulo: 'Familiar',
                      descripcion: 'Quiero cuidar a mi ser querido, gestionar sus actividades y encontrar cuidadores',
                      seleccionado: _rolSeleccionado == 'familiar',
                      onTap: () => setState(() => _rolSeleccionado = 'familiar'),
                    ),
                    const SizedBox(height: 12),
                    _TarjetaRol(
                      icono: Icons.medical_services_rounded,
                      colorFondo: const Color(0xFFD6E8F7),
                      colorIcono: Colors.blue,
                      titulo: 'Cuidador/a',
                      descripcion: 'Ofrezco servicios de cuidado y quiero encontrar personas que me necesiten',
                      seleccionado: _rolSeleccionado == 'cuidador',
                      onTap: () => setState(() => _rolSeleccionado = 'cuidador'),
                    ),

                    if (_esCuidador) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFEAF4FB), borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome, size: 18, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Completa tu perfil profesional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Esta información ayuda a las familias a encontrar el cuidado adecuado.', style: TextStyle(fontSize: 12, color: Colors.black87)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PROFESIÓN U OFICIO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _formularioFueEnviado && !_profesionValida ? Colors.red : Colors.grey[600], letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _elegirProfesion,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: _formularioFueEnviado && !_profesionValida ? Colors.red : Colors.grey.shade300, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(_profesion?.nombre ?? 'Selecciona una opción', style: TextStyle(color: _profesion == null ? Colors.grey : Colors.black))),
                              const Icon(Icons.keyboard_arrow_down),
                            ],
                          ),
                        ),
                      ),

                      if (_profesion != null && _profesion!.requiereDocumento) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _formularioFueEnviado && !_documentoValido ? const Color(0xFFFCE6E6) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _formularioFueEnviado && !_documentoValido ? Colors.red : Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.description_outlined, size: 18, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text.rich(
                                          TextSpan(children: [
                                            TextSpan(text: 'Documento que acredite tu profesión ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                                          ]),
                                        ),
                                        Text(_profesion!.instruccionDocumento, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _seleccionarDocumento,
                                icon: const Icon(Icons.upload_file),
                                label: Text(_documentoSeleccionado?.name ?? 'Seleccionar documento'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  minimumSize: const Size(double.infinity, 0),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Center(child: Text('PDF, JPG o PNG', style: TextStyle(fontSize: 11, color: Colors.grey))),
                              if (_documentoSeleccionado != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: const [
                                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text('Documento adjuntado', style: TextStyle(fontSize: 12, color: Colors.green)),
                                  ],
                                ),
                              ],
                              if (_profesion!.documentoRequerido == TipoDocumentoRequerido.cartaRecomendacion) ...[
                                const SizedBox(height: 14),
                                ValidatedTextField(
                                  controller: _referenciaTelefonoController,
                                  label: 'TELÉFONO DE CONTACTO DEL JEFE/A ANTERIOR',
                                  hint: '+56 9 1234 5678',
                                  isValid: _estadoCampo(_referenciaTelefonoController.text.trim().isNotEmpty, _referenciaTelefonoController),
                                  errorText: 'Ingresa un teléfono de contacto.',
                                  keyboardType: TextInputType.phone,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                ValidatedTextField(
                                  controller: _referenciaCorreoController,
                                  label: 'CORREO DEL JEFE/A ANTERIOR',
                                  hint: 'referencia@ejemplo.com',
                                  isValid: _estadoCampo(_referenciaCorreoController.text.trim().isNotEmpty, _referenciaCorreoController),
                                  errorText: 'Ingresa un correo de contacto.',
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                        if (_requiereExperiencia) ...[
                        const SizedBox(height: 16),
                        ValidatedTextField(
                          controller: _experienciaController,
                          label: 'AÑOS DE EXPERIENCIA',
                          hint: 'Ej: 3',
                          isValid: _estadoCampo(_experienciaValida, _experienciaController),
                          errorText: 'Ingresa un número válido de años (0 o más).',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Este dato quedará asociado a tu documentación y no podrá modificarse desde el perfil.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],

                      if (_profesion != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tus tarifas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              const Text('Mamoru define estos valores según tu profesión.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _CajaTarifa(etiqueta: 'PERIODO CORTO', subetiqueta: '1-3 hrs · por hora', valor: _formatearCLP(_profesion!.tarifaCorta)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _CajaTarifa(etiqueta: 'PERIODO INTERMEDIO', subetiqueta: '4-7 hrs · por hora', valor: _formatearCLP(_profesion!.tarifaIntermedia)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _CajaTarifa(etiqueta: 'PERIODO LARGO', subetiqueta: '8-16 hrs · por hora', valor: _formatearCLP(_profesion!.tarifaLarga)),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text('Tarifas fijas para ${_profesion!.nombre}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                              if (_profesion!.admitePuertasAdentro) ...[
                                const SizedBox(height: 16),
                                Text(
                                  '¿Tienes disponibilidad puertas adentro?',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _formularioFueEnviado && !_puertasAdentroRespondida ? Colors.red : Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                const Text('Considera estadías completas en el hogar de la persona.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _BotonSiNo(texto: 'Sí, disponible', seleccionado: _puertasAdentro == true, onTap: () => setState(() => _puertasAdentro = true)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _BotonSiNo(texto: 'No por ahora', seleccionado: _puertasAdentro == false, onTap: () => setState(() => _puertasAdentro = false)),
                                    ),
                                  ],
                                ),
                                if (_puertasAdentro == true) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: const Color(0xFFEAF4FB), borderRadius: BorderRadius.circular(10)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('TARIFA PUERTA ADENTRO · POR DÍA', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                                        const SizedBox(height: 2),
                                        Text('Valor fijo diario ${_formatearCLP(_profesion!.tarifaPuertasAdentro!)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 26),
                    ElevatedButton(
                      onPressed: _enviando ? null : _crearCuenta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3FAE85),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _enviando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Crear cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(color: Colors.black54, fontSize: 13),
                            children: [
                              TextSpan(text: '¿Ya tienes cuenta? '),
                              TextSpan(text: 'Iniciar sesión', style: TextStyle(color: Color(0xFF3FAE85), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
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

class _TarjetaRol extends StatelessWidget {
  final IconData icono;
  final Color colorFondo;
  final Color colorIcono;
  final String titulo;
  final String descripcion;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TarjetaRol({
    required this.icono,
    required this.colorFondo,
    required this.colorIcono,
    required this.titulo,
    required this.descripcion,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: seleccionado ? colorIcono : Colors.transparent, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(icono, color: colorIcono)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: colorIcono.withOpacity(0.9))),
                  const SizedBox(height: 4),
                  Text(descripcion, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(seleccionado ? Icons.radio_button_checked : Icons.radio_button_off, color: seleccionado ? colorIcono : Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _CajaTarifa extends StatelessWidget {
  final String etiqueta;
  final String subetiqueta;
  final String valor;

  const _CajaTarifa({required this.etiqueta, required this.subetiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEAF4FB), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          Text(subetiqueta, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _BotonSiNo extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BotonSiNo({required this.texto, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.blue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: seleccionado ? Colors.blue : Colors.grey.shade300, width: seleccionado ? 2 : 1),
        ),
        child: Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: seleccionado ? Colors.blue : Colors.black87, fontWeight: FontWeight.w600)),
      ),
    );
  }
}