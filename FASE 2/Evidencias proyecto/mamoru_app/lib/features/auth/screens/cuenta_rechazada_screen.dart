import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../services/auth_service.dart';
import '../services/documento_cuidador_service.dart';
import 'cuenta_pendiente_validacion_screen.dart';

/// Cuidador cuyo perfil fue rechazado: puede subir su documento otra vez para que el
/// equipo lo revise de nuevo. La sesión sigue abierta solo mientras está en esta pantalla.
class CuentaRechazadaScreen extends StatefulWidget {
  final String email;

  const CuentaRechazadaScreen({super.key, required this.email});

  @override
  State<CuentaRechazadaScreen> createState() => _CuentaRechazadaScreenState();
}

class _CuentaRechazadaScreenState extends State<CuentaRechazadaScreen> {
  PlatformFile? _documento;
  bool _enviando = false;
  String? _motivo;

  @override
  void initState() {
    super.initState();
    _cargarMotivo();
  }

  /// Muestra el motivo que escribió el equipo (si no se puede leer, la pantalla sigue igual).
  Future<void> _cargarMotivo() async {
    try {
      final datos = await ApiClient.get('/cuidadores/mi-perfil')
          as Map<String, dynamic>;
      final motivo = (datos['motivo_rechazo'] ?? '').toString().trim();
      if (!mounted || motivo.isEmpty) return;
      setState(() => _motivo = motivo);
    } catch (_) {
      // Sin motivo visible: no impide subir el documento.
    }
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _seleccionarDocumento() async {
    final PlatformFile? archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (archivo == null || !mounted) return;

    final grande = await DocumentoCuidadorService.demasiadoGrande(archivo);
    if (!mounted) return;

    if (grande) {
      _mostrarMensaje('El documento pesa más de 5 MB. Elige uno más liviano.');
      return;
    }

    setState(() => _documento = archivo);
  }

  Future<void> _enviar() async {
    if (_documento == null || _enviando) return;

    setState(() => _enviando = true);
    try {
      final bytes = await DocumentoCuidadorService.leerBytes(_documento!);
      if (bytes == null) {
        throw const DocumentoException(
          'No se pudo leer el documento seleccionado. Vuelve a elegirlo.',
        );
      }

      await DocumentoCuidadorService.subir(bytes);

      if (!mounted) return;

      // Queda pendiente de revisión: se cierra la sesión y se muestra la pantalla de espera.
      AuthService.cerrarSesion();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CuentaPendienteValidacionScreen(email: widget.email),
        ),
      );
    } on DocumentoException catch (e) {
      if (!mounted) return;
      _mostrarMensaje(e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _volverAlInicio() {
    AuthService.cerrarSesion();
    Navigator.pop(context);
  }

  // ==========================================================
  // INTERFAZ
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Al salir (botón atrás), la sesión se cierra.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) AuthService.cerrarSesion();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF9),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF0E8E4)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _buildIcono()),
                      const SizedBox(height: 20),
                      const Text(
                        'Tu cuenta está rechazada',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF342A38),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tu cuenta actualmente se encuentra rechazada por un '
                        'inconveniente en tu documento. Sube aquí tu documento '
                        'para que sea revisado nuevamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF9D929F),
                        ),
                      ),
                      if (_motivo != null) ...[
                        const SizedBox(height: 18),
                        _buildMotivo(_motivo!),
                      ],
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _enviando ? null : _seleccionarDocumento,
                        icon: Icon(
                          _documento == null
                              ? Icons.upload_file
                              : Icons.check_circle,
                          color: const Color(0xFF3FAE85),
                        ),
                        label: Text(
                          _documento?.name ?? 'Seleccionar documento',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3FAE85),
                          side: const BorderSide(color: Color(0xFF59C49C)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'PDF, JPG o PNG de hasta 5 MB.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA69CA6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _documento != null && !_enviando ? _enviar : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF59C49C),
                            disabledBackgroundColor: const Color(0xFFB9E1D2),
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                              : const Text(
                                  'Enviar para revisión',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Si en esta nueva revisión tampoco podemos aprobarlo, '
                        'tu cuenta quedará desactivada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFFA69CA6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _enviando ? null : _volverAlInicio,
                        child: const Text('Volver al inicio'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 18, 20, 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revisión de tu cuenta',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF342A38),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Sube tu documento para una nueva revisión',
              style: TextStyle(fontSize: 12, color: Color(0xFFA69CA6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcono() {
    return Container(
      width: 66,
      height: 66,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE9E5),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.description_outlined,
        size: 31,
        color: Color(0xFFC0594B),
      ),
    );
  }

  Widget _buildMotivo(String motivo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3D3CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MOTIVO INDICADO POR EL EQUIPO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9B6A62),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            motivo,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF5A3E39),
            ),
          ),
        ],
      ),
    );
  }
}
