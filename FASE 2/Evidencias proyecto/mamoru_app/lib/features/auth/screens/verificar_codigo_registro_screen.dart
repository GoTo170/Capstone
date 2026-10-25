import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cuenta_pendiente_validacion_screen.dart';

class VerificarCodigoRegistroScreen extends StatefulWidget {
  final String email;
  final String rol;

  const VerificarCodigoRegistroScreen({
    super.key,
    required this.email,
    required this.rol,
  });

  @override
  State<VerificarCodigoRegistroScreen> createState() =>
      _VerificarCodigoRegistroScreenState();
}

class _VerificarCodigoRegistroScreenState
    extends State<VerificarCodigoRegistroScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _codigoController =
      TextEditingController();

  bool _verificando = false;
  bool _reenviando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  // =========================
  // VALIDACIÓN DEL CÓDIGO
  // =========================

  String? _validarCodigo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el código de verificación';
    }

    if (value.trim().length != 6) {
      return 'El código debe tener 6 dígitos';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'El código solo puede contener números';
    }

    return null;
  }

  // =========================
  // VERIFICAR CÓDIGO
  // =========================

  Future<void> _verificarCodigo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _verificando = true;
    });

    // TODO:
    // Posteriormente se llamará al backend FastAPI.
    //
    // Se debería enviar:
    //
    // email: widget.email
    // codigo: _codigoController.text.trim()
    //
    // El backend deberá validar:
    // 1. Que el código exista.
    // 2. Que pertenezca al correo.
    // 3. Que no haya expirado.
    // 4. Que no haya sido utilizado anteriormente.

    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    if (!mounted) return;

    setState(() {
      _verificando = false;
    });

    // -------------------------------------------------
    // POR AHORA SIMULAMOS QUE EL CÓDIGO ES CORRECTO.
    // -------------------------------------------------

    final rol = widget.rol.trim().toLowerCase();

    if (rol == 'cuidador') {
      _irAPendienteValidacion();
    } else if (rol == 'familiar') {
      _registroFamiliarExitoso();
    } else {
      _mostrarError(
        'El rol seleccionado no es válido.',
      );
    }
  }

  // =========================
  // FAMILIAR
  // =========================

  Future<void> _registroFamiliarExitoso() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            24,
            28,
            24,
            22,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F8EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 36,
                  color: Color(0xFF52B788),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                '¡Correo verificado!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF342A38),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Tu cuenta fue creada correctamente. '
                'Ya puedes iniciar sesión en Mamoru.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.5,
                  fontSize: 13,
                  color: Color(0xFF8F8590),
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF59C49C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ir a iniciar sesión',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    // Regresa a la primera pantalla.
    // Si tu LoginScreen es la pantalla inicial,
    // volverá directamente al login.
    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }

  // =========================
  // CUIDADOR
  // =========================

  void _irAPendienteValidacion() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CuentaPendienteValidacionScreen(
          email: widget.email,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  // =========================
  // REENVIAR CÓDIGO
  // =========================

  Future<void> _reenviarCodigo() async {
    if (_reenviando) return;

    setState(() {
      _reenviando = true;
    });

    // TODO:
    // Posteriormente llamar al endpoint para
    // generar y enviar un nuevo código.

    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) return;

    setState(() {
      _reenviando = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Se envió un nuevo código a ${widget.email}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================
  // ERROR
  // =========================

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================
  // INTERFAZ
  // =========================

  @override
  Widget build(BuildContext context) {
    final esCuidador =
        widget.rol.trim().toLowerCase() == 'cuidador';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF0E8E4),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  30,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 6),

                      _buildIcono(),

                      const SizedBox(height: 20),

                      const Text(
                        'Verifica tu correo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF342A38),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Enviamos un código de 6 dígitos al correo '
                        'que utilizaste para crear tu cuenta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF9D929F),
                        ),
                      ),

                      const SizedBox(height: 28),

                      _buildCorreo(),

                      const SizedBox(height: 14),

                      _buildMensajeCodigo(),

                      if (esCuidador) ...[
                        const SizedBox(height: 14),
                        _buildMensajeCuidador(),
                      ],

                      const SizedBox(height: 24),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CÓDIGO DE VERIFICACIÓN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: Color(0xFF766C76),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _codigoController,
                        keyboardType:
                            TextInputType.number,
                        textInputAction:
                            TextInputAction.done,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        autovalidateMode:
                            AutovalidateMode
                                .onUserInteraction,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly,
                          LengthLimitingTextInputFormatter(
                            6,
                          ),
                        ],
                        validator: _validarCodigo,
                        onFieldSubmitted: (_) {
                          _verificarCodigo();
                        },
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 10,
                          color: Color(0xFF342A38),
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: const TextStyle(
                            letterSpacing: 10,
                            color: Color(0xFFD2C9D0),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            vertical: 17,
                            horizontal: 14,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  Color(0xFF63CEA6),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  Color(0xFF59C49C),
                              width: 2,
                            ),
                          ),
                          errorBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  Colors.redAccent,
                            ),
                          ),
                          focusedErrorBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  Colors.redAccent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _verificando
                              ? null
                              : _verificarCodigo,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(
                                  0xFF59C49C,
                                ),
                            disabledBackgroundColor:
                                const Color(
                                  0xFFB9E1D2,
                                ),
                            foregroundColor:
                                Colors.white,
                            elevation: 1,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                          child: _verificando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Verificar correo',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 7),

                      TextButton(
                        onPressed: _reenviando
                            ? null
                            : _reenviarCodigo,
                        child: Text(
                          _reenviando
                              ? 'Enviando...'
                              : 'Reenviar código',
                          style: const TextStyle(
                            color:
                                Color(0xFF59C49C),
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'Cambiar correo electrónico',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              const Color(
                                0xFF8F8590,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // HEADER
  // =========================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        15,
        20,
        14,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2EDEB),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back,
                size: 19,
                color: Color(0xFF817780),
              ),
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Verificación de cuenta',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF342A38),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Confirma tu correo electrónico',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA69CA6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // ICONO
  // =========================

  Widget _buildIcono() {
    return Container(
      width: 66,
      height: 66,
      decoration: const BoxDecoration(
        color: Color(0xFFDDF4FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.mark_email_read_outlined,
        size: 31,
        color: Color(0xFF39789A),
      ),
    );
  }

  // =========================
  // CORREO
  // =========================

  Widget _buildCorreo() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'CORREO ELECTRÓNICO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF766C76),
          ),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F5),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE4DDDA),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 18,
                color: Color(0xFF968B96),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF817780),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // MENSAJE DE CÓDIGO
  // =========================

  Widget _buildMensajeCodigo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBF6),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFAFE4CF),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF479B78),
            size: 19,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Código enviado a ${widget.email}',
                  style: const TextStyle(
                    color: Color(0xFF479B78),
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'El código tiene una duración de 10 minutos.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFF67AA8E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // MENSAJE CUIDADOR
  // =========================

  Widget _buildMensajeCuidador() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FC),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFDCCFF2),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF7B63A8),
            size: 20,
          ),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              'Después de verificar tu correo, tu cuenta será enviada a revisión antes de ser habilitada como cuidador.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Color(0xFF756487),
              ),
            ),
          ),
        ],
      ),
    );
  }
}