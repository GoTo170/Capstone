import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../services/auth_service.dart';
import '../widgets/validated_text_field.dart';

/// Paso 1 de "Olvidé mi contraseña": se pide el correo y el servidor envía un mensaje
/// que pregunta si fuiste tú. Si presiona "Sí, fui yo", el enlace abre la app en la
/// pantalla de nueva contraseña.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _segundosEntreEnvios = 60;

  final _emailController = TextEditingController();

  bool? _emailValido;
  bool _cargando = false;
  bool _enviado = false;
  String _emailEnviado = '';

  Timer? _temporizador;
  int _segundosRestantes = 0;

  bool _validarEmail() {
    final texto = _emailController.text.trim();
    final valido =
        RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(texto);
    setState(() => _emailValido = valido);
    return valido;
  }

  String get _mensajeErrorEmail {
    if (_emailController.text.trim().isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }
    return 'El correo ingresado no tiene un formato válido.';
  }

  Future<void> _enviar() async {
    if (_cargando) return;
    if (!_validarEmail()) return;

    final email = _emailController.text.trim();
    setState(() => _cargando = true);

    try {
      await AuthService.solicitarRecuperacion(email);
      if (!mounted) return;
      setState(() {
        _enviado = true;
        _emailEnviado = email;
      });
      _iniciarEspera();
    } on ApiException catch (e) {
      if (!mounted) return;
      _mostrarMensaje(e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _iniciarEspera() {
    _temporizador?.cancel();
    setState(() => _segundosRestantes = _segundosEntreEnvios);
    _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _segundosRestantes--;
        if (_segundosRestantes <= 0) t.cancel();
      });
    });
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  // ==========================================================
  // INTERFAZ
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0E8E4)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                child: _enviado ? _buildEnviado() : _buildFormulario(),
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
                  'Te enviaremos un correo para crear una nueva',
                  style: TextStyle(fontSize: 12, color: Color(0xFFA69CA6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcono(IconData icono) {
    return Container(
      width: 66,
      height: 66,
      decoration: const BoxDecoration(
        color: Color(0xFFDDF4FF),
        shape: BoxShape.circle,
      ),
      child: Icon(icono, size: 31, color: const Color(0xFF39789A)),
    );
  }

  Widget _buildFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _buildIcono(Icons.lock_reset)),
        const SizedBox(height: 20),
        const Text(
          '¿Olvidó su contraseña?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF342A38),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Escribe el correo de tu cuenta. Te enviaremos un mensaje para '
          'confirmar que fuiste tú y poder crear una contraseña nueva.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF9D929F),
          ),
        ),
        const SizedBox(height: 28),
        ValidatedTextField(
          controller: _emailController,
          label: 'CORREO ELECTRÓNICO',
          hint: 'tucorreo@ejemplo.com',
          isValid: _emailValido,
          errorText: _mensajeErrorEmail,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            if (_emailValido != null) _validarEmail();
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _cargando ? null : _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF59C49C),
              disabledBackgroundColor: const Color(0xFFB9E1D2),
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Enviar correo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnviado() {
    final puedeReenviar = _segundosRestantes <= 0 && !_cargando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _buildIcono(Icons.mark_email_read_outlined)),
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
        Text(
          'Si $_emailEnviado corresponde a una cuenta, te enviamos un '
          'mensaje que pregunta si fuiste tú quien pidió cambiar la '
          'contraseña.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF9D929F),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF4FBF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD5EFE5)),
          ),
          child: const Text(
            'Si fuiste tú, presiona "Sí, fui yo" en el correo: volverás a la '
            'app para crear tu nueva contraseña.\n\n'
            'Si no fuiste tú, ignora el correo y no pasará nada.\n\n'
            'El enlace vence en 30 minutos. Si no lo ves, revisa también la '
            'carpeta de spam.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF4F6B60),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: puedeReenviar ? _enviar : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3FAE85),
              side: const BorderSide(color: Color(0xFF59C49C)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              puedeReenviar
                  ? 'Reenviar correo'
                  : 'Reenviar en $_segundosRestantes s',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _enviado = false),
          child: const Text('Usar otro correo'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    );
  }
}