import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'crear_nueva_contrasena_screen.dart';

class VerificarCodigoRecuperacionScreen extends StatefulWidget {
  final String email;

  const VerificarCodigoRecuperacionScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerificarCodigoRecuperacionScreen> createState() =>
      _VerificarCodigoRecuperacionScreenState();
}

class _VerificarCodigoRecuperacionScreenState
    extends State<VerificarCodigoRecuperacionScreen> {
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

  String? _validarCodigo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el código de verificación';
    }

    if (value.length != 6) {
      return 'El código debe tener 6 dígitos';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'El código solo puede contener números';
    }

    return null;
  }

  Future<void> _verificarCodigo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _verificando = true;
    });

    // TODO:
    // Aquí posteriormente verificaremos el código
    // contra el backend FastAPI.

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    setState(() {
      _verificando = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearNuevaContrasenaScreen(
          email: widget.email,
          codigo: _codigoController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _reenviarCodigo() async {
    setState(() {
      _reenviando = true;
    });

    // TODO:
    // Aquí posteriormente solicitaremos al backend
    // un nuevo código.

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

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 5),

                      _buildIcono(),

                      const SizedBox(height: 20),

                      const Text(
                        'Revisa tu correo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF342A38),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Te enviamos un código de 6 dígitos para\n'
                        'verificar que eres tú.',
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

                      const SizedBox(height: 20),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CÓDIGO DE VERIFICACIÓN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF766C76),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _codigoController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        autovalidateMode:
                            AutovalidateMode.onUserInteraction,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: _validarCodigo,
                        onFieldSubmitted: (_) =>
                            _verificarCodigo(),
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
                            vertical: 16,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF63CEA6),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF59C49C),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF59C49C),
                            disabledBackgroundColor:
                                const Color(0xFFB9E1D2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: _verificando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Verificar código',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 5),

                      TextButton(
                        onPressed: _reenviando
                            ? null
                            : _reenviarCodigo,
                        child: Text(
                          _reenviando
                              ? 'Enviando...'
                              : 'Reenviar código',
                          style: const TextStyle(
                            color: Color(0xFF59C49C),
                            fontWeight: FontWeight.w600,
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
              borderRadius: BorderRadius.circular(12),
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
                  'Recuperar contraseña',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF342A38),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Verifica tu correo electrónico',
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

  Widget _buildIcono() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFFDDF4FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.mail_outline_rounded,
        size: 30,
        color: Color(0xFF39789A),
      ),
    );
  }

  Widget _buildCorreo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE4DDDA),
            ),
          ),
          child: Text(
            widget.email,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF817780),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMensajeCodigo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFAFE4CF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Código enviado a ${widget.email}',
            style: const TextStyle(
              color: Color(0xFF479B78),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'El código tiene una duración de 10 minutos',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF67AA8E),
            ),
          ),
        ],
      ),
    );
  }
}