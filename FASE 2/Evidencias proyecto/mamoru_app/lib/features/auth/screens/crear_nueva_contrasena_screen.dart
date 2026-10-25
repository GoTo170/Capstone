import 'package:flutter/material.dart';

class CrearNuevaContrasenaScreen extends StatefulWidget {
  final String email;
  final String codigo;

  const CrearNuevaContrasenaScreen({
    super.key,
    required this.email,
    required this.codigo,
  });

  @override
  State<CrearNuevaContrasenaScreen> createState() =>
      _CrearNuevaContrasenaScreenState();
}

class _CrearNuevaContrasenaScreenState
    extends State<CrearNuevaContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmarPasswordController =
      TextEditingController();

  bool _ocultarPassword = true;
  bool _ocultarConfirmacion = true;

  bool _guardando = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  bool get _tieneMayuscula =>
      RegExp(r'[A-Z]').hasMatch(_passwordController.text);

  bool get _tieneMinuscula =>
      RegExp(r'[a-z]').hasMatch(_passwordController.text);

  bool get _tieneNumero =>
      RegExp(r'[0-9]').hasMatch(_passwordController.text);

  bool get _tieneEspecial =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text);

  bool get _tieneLargo =>
      _passwordController.text.length >= 6;

  bool get _passwordValida =>
      _tieneLargo &&
      _tieneMayuscula &&
      _tieneMinuscula &&
      _tieneNumero &&
      _tieneEspecial;

  String? _validarPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa una nueva contraseña';
    }

    if (value.length < 6) {
      return 'Debe contener al menos 6 caracteres';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Debe contener al menos una letra mayúscula';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Debe contener al menos una letra minúscula';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Debe contener al menos un número';
    }

    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Debe contener al menos un carácter especial';
    }

    return null;
  }

  String? _validarConfirmacion(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu nueva contraseña';
    }

    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  Future<void> _confirmarNuevaPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _guardando = true;
    });

    // TODO:
    // Aquí conectaremos posteriormente el backend.
    //
    // Datos que enviaremos:
    //
    // email: widget.email
    // codigo: widget.codigo
    // nueva_password: _passwordController.text

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() {
      _guardando = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Contraseña actualizada correctamente',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Vuelve hasta la pantalla inicial.
    // Si LoginScreen es la primera pantalla, regresará al login.
    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }

  void _cancelar() {
    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final passwordsCoinciden =
        _confirmarPasswordController.text.isNotEmpty &&
        _passwordController.text ==
            _confirmarPasswordController.text;

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
                        'Elige una contraseña segura',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF342A38),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'La usarás para tus próximos inicios de sesión.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9D929F),
                        ),
                      ),

                      const SizedBox(height: 30),

                      _buildLabel('NUEVA CONTRASEÑA'),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _ocultarPassword,
                        autovalidateMode:
                            AutovalidateMode.onUserInteraction,
                        validator: _validarPassword,
                        onChanged: (_) {
                          setState(() {});
                        },
                        decoration: _inputDecoration(
                          hint: 'Nueva contraseña',
                          ocultar: _ocultarPassword,
                          onVisibilityPressed: () {
                            setState(() {
                              _ocultarPassword =
                                  !_ocultarPassword;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      _buildRequisitos(),

                      const SizedBox(height: 20),

                      _buildLabel('CONFIRMAR CONTRASEÑA'),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller:
                            _confirmarPasswordController,
                        obscureText:
                            _ocultarConfirmacion,
                        validator: _validarConfirmacion,
                        autovalidateMode:
                            AutovalidateMode.onUserInteraction,
                        onChanged: (_) {
                          setState(() {});
                        },
                        decoration: _inputDecoration(
                          hint: 'Repite la contraseña',
                          ocultar: _ocultarConfirmacion,
                          onVisibilityPressed: () {
                            setState(() {
                              _ocultarConfirmacion =
                                  !_ocultarConfirmacion;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _passwordValida &&
                                      passwordsCoinciden &&
                                      !_guardando
                                  ? _confirmarNuevaPassword
                                  : null,
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
                          child: _guardando
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
                                  'Confirmar nueva contraseña',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _cancelar,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFE6DDD9),
                            ),
                            foregroundColor:
                                const Color(0xFF8B7F8D),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancelar y volver al inicio',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
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

  Widget _buildRequisitos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE7DFDC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TU CONTRASEÑA DEBE INCLUIR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF897F87),
            ),
          ),

          const SizedBox(height: 12),

          _requisito(
            'Mínimo 6 caracteres',
            _tieneLargo,
          ),
          _requisito(
            '1 letra mayúscula',
            _tieneMayuscula,
          ),
          _requisito(
            '1 letra minúscula',
            _tieneMinuscula,
          ),
          _requisito(
            '1 número',
            _tieneNumero,
          ),
          _requisito(
            '1 carácter especial',
            _tieneEspecial,
          ),
        ],
      ),
    );
  }

  Widget _requisito(String texto, bool cumplido) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            cumplido
                ? Icons.check_circle
                : Icons.circle_outlined,
            size: 15,
            color: cumplido
                ? const Color(0xFF59C49C)
                : const Color(0xFFD2C9CF),
          ),

          const SizedBox(width: 8),

          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: cumplido
                  ? const Color(0xFF479B78)
                  : const Color(0xFFA198A2),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool ocultar,
    required VoidCallback onVisibilityPressed,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFB7AFB8),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      suffixIcon: IconButton(
        onPressed: onVisibilityPressed,
        icon: Icon(
          ocultar
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: const Color(0xFFA79CA8),
          size: 21,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE5DCD8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF59C49C),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Widget _buildLabel(String texto) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildIcono() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFFEFE6FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.lock_outline_rounded,
        size: 30,
        color: Color(0xFF7359A5),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 15, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crear nueva contraseña',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF342A38),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Protege el acceso a tu cuenta',
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
}