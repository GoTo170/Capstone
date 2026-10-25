import 'package:flutter/material.dart';

import '../../adulto_mayor/screens/inicio_adulto_mayor_screen.dart';
import '../../cuidador/screens/inicio_cuidador_screen.dart';
import '../../familiar/screens/home_screen.dart';

import '../../../core/api_exception.dart';
import '../../../core/sesion.dart';
import '../services/auth_service.dart';
import '../widgets/validated_text_field.dart';

import 'cuenta_pendiente_validacion_screen.dart';
import 'escanear_invitacion_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool? _emailValido;
  bool? _passwordValida;

  bool _passwordVisible = false;
  bool _formularioFueEnviado = false;
  bool _cargando = false;

  // ==========================================================
  // VALIDACIONES
  // ==========================================================

  bool _validarEmail() {
    final texto = _emailController.text.trim();

    final valido = texto.isNotEmpty &&
        RegExp(
          r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$',
        ).hasMatch(texto);

    setState(() {
      _emailValido = valido;
    });

    return valido;
  }

  bool _validarPassword() {
    final valido = _passwordController.text.isNotEmpty;

    setState(() {
      _passwordValida = valido;
    });

    return valido;
  }

  String? get _mensajeErrorEmail {
    if (_emailController.text.trim().isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }

    return 'El correo ingresado no tiene un formato válido.';
  }

  // ==========================================================
  // INICIAR SESIÓN
  // ==========================================================

  Future<void> _iniciarSesion() async {
    setState(() {
      _formularioFueEnviado = true;
    });

    final emailOk = _validarEmail();
    final passwordOk = _validarPassword();

    if (!emailOk || !passwordOk || _cargando) return;

    setState(() {
      _cargando = true;
    });

    try {
      final usuario = await AuthService.iniciarSesion(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      await _entrarSegunRol(usuario);
    } on ApiException catch (e) {
      AuthService.cerrarSesion();

      if (!mounted) return;

      _mostrarMensaje(e.mensaje);
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  // ==========================================================
  // ENTRAR A LA PANTALLA QUE CORRESPONDE AL ROL
  // ==========================================================

  Future<void> _entrarSegunRol(UsuarioSesion usuario) async {
    if (usuario.rol == 'familiar') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    if (usuario.rol == 'cuidador') {
      final estado = await AuthService.estadoValidacionCuidador();

      if (!mounted) return;

      if (estado == 'aprobado') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => InicioCuidadorScreen(
              nombreCuidador: usuario.nombre,
            ),
          ),
          (route) => false,
        );
        return;
      }

      // Pendiente o rechazado: todavía no puede usar la app.
      AuthService.cerrarSesion();

      if (estado == 'rechazado') {
        _mostrarMensaje(
          'Tu solicitud de cuenta fue rechazada. '
          'Si crees que es un error, contacta al equipo de Mamoru.',
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CuentaPendienteValidacionScreen(
            email: usuario.email ?? _emailController.text.trim(),
          ),
        ),
      );
      return;
    }

    // Administradores y adultos mayores no ingresan con correo en la app.
    AuthService.cerrarSesion();

    _mostrarMensaje(
      usuario.rol == 'administrador'
          ? 'Esta cuenta pertenece al panel administrativo.'
          : 'Esta cuenta ingresa con el código de invitación.',
    );
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // LIBERAR CONTROLADORES
  // ==========================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================================
  // INTERFAZ
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // ENCABEZADO
              // ==================================================

              Container(
  padding: const EdgeInsets.symmetric(
    vertical: 30,
    horizontal: 24,
  ),

  decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0xFFCDEEDD),
        Color(0xFFF6D9E4),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),

  child: Column(
    children: [
      // ==============================================
      // LOGO MAMORU
      // ==============================================

                    Container(
                      width: 155,
                      height: 155,
                      padding: const EdgeInsets.all(10),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),

                      child: Image.asset(
                        'assets/images/logo_mamoru.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==============================================
                    // FRASE MAMORU
                    // ==============================================

                    RichText(
                      textAlign: TextAlign.center,

                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),

                        children: [
                          TextSpan(
                            text: 'Amor',
                          ),

                          TextSpan(
                            text: '  •  ',
                          ),

                          TextSpan(
                            text: 'PROTECCIÓN',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          TextSpan(
                            text: '  •  ',
                          ),

                          TextSpan(
                            text: 'Servicio',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // FORMULARIO
              // ==================================================

              Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==============================================
                    // CORREO
                    // ==============================================

                    ValidatedTextField(
                      controller: _emailController,
                      label: 'CORREO ELECTRÓNICO',

                      isValid:
                          _formularioFueEnviado || _emailValido != null
                              ? _emailValido ?? false
                              : null,

                      errorText: _mensajeErrorEmail,

                      keyboardType: TextInputType.emailAddress,

                      onChanged: (_) {
                        if (_formularioFueEnviado ||
                            _emailValido != null) {
                          _validarEmail();
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // ==============================================
                    // CONTRASEÑA
                    // ==============================================

                    ValidatedTextField(
                      controller: _passwordController,
                      label: 'CONTRASEÑA',

                      isValid:
                          _formularioFueEnviado ||
                                  _passwordValida != null
                              ? _passwordValida ?? false
                              : null,

                      errorText: 'Ingresa tu contraseña.',

                      obscureText: !_passwordVisible,

                      onChanged: (_) {
                        if (_formularioFueEnviado ||
                            _passwordValida != null) {
                          _validarPassword();
                        }
                      },

                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),

                        onPressed: () {
                          setState(() {
                            _passwordVisible =
                                !_passwordVisible;
                          });
                        },
                      ),
                    ),

                    // ==============================================
                    // OLVIDÉ CONTRASEÑA
                    // ==============================================

                    Align(
                      alignment: Alignment.centerRight,

                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },

                        child: const Text(
                          '¿Olvidó su contraseña?',
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ==============================================
                    // BOTÓN INICIAR SESIÓN
                    // ==============================================

                    ElevatedButton(
                      onPressed: _cargando ? null : _iniciarSesion,

                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF3FAE85),

                        foregroundColor: Colors.white,

                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),

                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30),
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
                              'Iniciar sesión',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // ==============================================
                    // SEPARADOR INVITACIÓN
                    // ==============================================

                    Row(
                      children: [
                        const Expanded(
                          child: Divider(),
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),

                          child: Text(
                            '¿tienes una invitación?',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),

                        const Expanded(
                          child: Divider(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ==============================================
                    // ACCESO ADULTO MAYOR POR INVITACIÓN
                    // ==============================================

                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const EscanearInvitacionScreen(),
                          ),
                        );
                      },

                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.deepPurple,
                      ),

                      label: const Text(
                        'Iniciar con invitación',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFEDE7F6),

                        side: BorderSide.none,

                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 16,
                        ),

                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==============================================
                    // REGISTRO
                    // ==============================================

                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RegisterScreen(),
                            ),
                          );
                        },

                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),

                            children: [
                              TextSpan(
                                text:
                                    '¿No tienes cuenta? ',
                              ),

                              TextSpan(
                                text: 'Regístrate aquí',

                                style: TextStyle(
                                  color:
                                      Color(0xFF3FAE85),

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==============================================
                    // PANEL TEMPORAL DE DEMOSTRACIÓN
                    // ==============================================

                    const _PanelAccesoDemostracion(),
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

// ================================================================
// PANEL DE ACCESO RÁPIDO
// ================================================================
//
// Este panel existe solo durante el desarrollo de Mamoru.
//
// Permite ingresar directamente a las vistas de:
// - Adulto mayor
// - Familiar
// - Cuidador
//
// Debe eliminarse o esconderse antes de la versión final.
// ================================================================

class _PanelAccesoDemostracion extends StatelessWidget {
  const _PanelAccesoDemostracion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFF1EEFB),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(
          color: Colors.deepPurple.shade100,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCESO RÁPIDO DE DEMOSTRACIÓN',

            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple[700],
              letterSpacing: 0.4,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              // ==============================================
              // ADULTO MAYOR
              // ==============================================

              Expanded(
                child: _BotonDemo(
                  icono: Icons.elderly,
                  color: Colors.orange,
                  etiqueta: 'Adulto Mayor',

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const InicioAdultoMayorScreen(
                          nombre: 'Rosa',
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 10),

              // ==============================================
              // FAMILIAR
              // ==============================================

              Expanded(
                child: _BotonDemo(
                  icono: Icons.family_restroom,
                  color: Colors.pink,
                  etiqueta: 'Familiar',

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const HomeScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 10),

              // ==============================================
              // CUIDADOR
              // ==============================================

              Expanded(
                child: _BotonDemo(
                  icono: Icons.medical_services,
                  color: Colors.blue,
                  etiqueta: 'Cuidador/a',

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const InicioCuidadorScreen(
                          nombreCuidador: 'María',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BOTÓN DEL PANEL DE DEMOSTRACIÓN
// ================================================================

class _BotonDemo extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String etiqueta;
  final VoidCallback onTap;

  const _BotonDemo({
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(14),

      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 6,
        ),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),

        child: Column(
          children: [
            CircleAvatar(
              radius: 18,

              backgroundColor: color.withValues(
                alpha: 0.12,
              ),

              child: Icon(
                icono,
                color: color,
                size: 18,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              etiqueta,
              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}