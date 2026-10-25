import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_exception.dart';
import '../../adulto_mayor/screens/inicio_adulto_mayor_screen.dart';
import '../services/auth_service.dart';

class IngresarCodigoScreen extends StatefulWidget {
  const IngresarCodigoScreen({super.key});

  @override
  State<IngresarCodigoScreen> createState() => _IngresarCodigoScreenState();
}

class _IngresarCodigoScreenState extends State<IngresarCodigoScreen> {
  final _parte1Controller = TextEditingController();
  final _parte2Controller = TextEditingController();
  bool _formularioFueEnviado = false;
  bool _cargando = false;

  bool get _parte1Valida => _parte1Controller.text.trim().length == 4;
  bool get _parte2Valida => _parte2Controller.text.trim().length == 4;
  bool get _codigoCompleto => _parte1Valida && _parte2Valida;

  String get _codigoFormateado =>
      '${_parte1Controller.text.trim()}-${_parte2Controller.text.trim()}';

  Future<void> _ingresar() async {
    setState(() => _formularioFueEnviado = true);
    if (!_codigoCompleto || _cargando) return;

    setState(() => _cargando = true);

    try {
      final usuario = await AuthService.canjearInvitacion(_codigoFormateado);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => InicioAdultoMayorScreen(nombre: usuario.nombre),
        ),
        (route) => false,
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
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDCD6F7), Color(0xFFF3E8EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                            const Text('Ingresar código', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            const Text('Accede con tu código de invitación', style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 12),
                            const Text(
                              'El familiar que te invitó generó un código único. Ingrésalo aquí para vincularte a Mamoru.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.dialpad, size: 36, color: Colors.indigo[400]),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        children: const [
                          TextSpan(text: 'El código tiene el formato '),
                          TextSpan(text: 'XXXX-0000', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('CÓDIGO DE INVITACIÓN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.6)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CasillaCodigo(
                          controller: _parte1Controller,
                          conError: _formularioFueEnviado && !_parte1Valida,
                          onChanged: (_) => setState(() {}),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('—', style: TextStyle(fontSize: 20)),
                        ),
                        _CasillaCodigo(
                          controller: _parte2Controller,
                          conError: _formularioFueEnviado && !_parte2Valida,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_codigoCompleto)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Text('Código listo: $_codigoFormateado',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      )
                    else if (_formularioFueEnviado)
                      const Text('Completa las 8 letras/números del código.',
                          style: TextStyle(color: Colors.red, fontSize: 12)),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _ingresar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Ingresar  →', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Volver a escanear QR'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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

class _CasillaCodigo extends StatelessWidget {
  final TextEditingController controller;
  final bool conError;
  final ValueChanged<String> onChanged;

  const _CasillaCodigo({required this.controller, required this.conError, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        maxLength: 4,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          UpperCaseTextFormatter(),
        ],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: conError ? Colors.red : Colors.deepPurple.shade100, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: conError ? Colors.red : Colors.deepPurple.shade100, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: conError ? Colors.red : Colors.deepPurple, width: 2),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}