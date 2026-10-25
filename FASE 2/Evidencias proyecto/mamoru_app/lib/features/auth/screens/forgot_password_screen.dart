import 'package:flutter/material.dart';
import 'verificar_codigo_recuperacion_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  bool _enviando = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validarCorreo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu correo electrónico';
    }

    final email = value.trim();

    final regexEmail = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!regexEmail.hasMatch(email)) {
      return 'Ingresa un correo electrónico válido';
    }

    return null;
  }

  Future<void> _enviarCodigo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _enviando = true;
    });

    // TODO: Aquí posteriormente llamaremos al backend FastAPI
    // para verificar que el correo exista y enviar el código.

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    setState(() {
      _enviando = false;
    });

    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => VerificarCodigoRecuperacionScreen(
      email: _emailController.text.trim(),
    ),
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
                        'Te enviaremos un código de 6 dígitos para\n'
                        'verificar que eres tú.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF9D929F),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CORREO ELECTRÓNICO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autovalidateMode:
                            AutovalidateMode.onUserInteraction,
                        validator: _validarCorreo,
                        onFieldSubmitted: (_) => _enviarCodigo(),
                        decoration: InputDecoration(
                          hintText: 'tucorreo@ejemplo.com',
                          hintStyle: const TextStyle(
                            color: Color(0xFFB7AFB8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5DCD8),
                            ),
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
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _enviando ? null : _enviarCodigo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF59C49C),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFFB9E1D2),
                            elevation: 2,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _enviando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Enviar código',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
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
      padding: const EdgeInsets.fromLTRB(18, 15, 20, 14),
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
              onPressed: () => Navigator.pop(context),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
}