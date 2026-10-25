import 'dart:async';
 
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
 
import '../../../core/api_exception.dart';
import '../../adulto_mayor/screens/inicio_adulto_mayor_screen.dart';
import '../services/auth_service.dart';
import 'ingresar_codigo_screen.dart';
 
/// Pantalla donde el adulto mayor escanea el QR de su invitación.
///
/// El QR que genera la familia contiene el código de invitación
/// (formato XXXX-0000). Al leerlo se canjea igual que si se escribiera
/// a mano en "Ingresar código".
class EscanearInvitacionScreen extends StatefulWidget {
  const EscanearInvitacionScreen({super.key});
 
  @override
  State<EscanearInvitacionScreen> createState() =>
      _EscanearInvitacionScreenState();
}
 
class _EscanearInvitacionScreenState extends State<EscanearInvitacionScreen> {
  // Acepta "ABCD-1234" o "ABCD1234", incluso dentro de un texto más largo
  // (por ejemplo un enlace que termine en el código).
  static final RegExp _formatoCodigo = RegExp(r'([A-Z]{4})-?([0-9]{4})');
 
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
 
  bool _procesando = false;
  String? _ultimoInvalido;
  DateTime _ultimoAviso = DateTime.fromMillisecondsSinceEpoch(0);
 
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
 
  /// Devuelve el código normalizado (ABCD-1234) o null si el texto no lo trae.
  String? _extraerCodigo(String? crudo) {
    if (crudo == null) return null;
    final m = _formatoCodigo.firstMatch(crudo.trim().toUpperCase());
    if (m == null) return null;
    return '${m.group(1)}-${m.group(2)}';
  }
 
  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
      );
  }
 
  Future<void> _alDetectar(BarcodeCapture captura) async {
    if (_procesando) return;
 
    String? crudo;
    for (final b in captura.barcodes) {
      if (b.rawValue != null && b.rawValue!.isNotEmpty) {
        crudo = b.rawValue;
        break;
      }
    }
    if (crudo == null) return;
 
    final codigo = _extraerCodigo(crudo);
 
    if (codigo == null) {
      // Evita repetir el mismo aviso una y otra vez mientras el QR sigue a la vista.
      final ahora = DateTime.now();
      if (crudo != _ultimoInvalido ||
          ahora.difference(_ultimoAviso).inSeconds >= 3) {
        _ultimoInvalido = crudo;
        _ultimoAviso = ahora;
        _avisar('Este QR no es una invitación de Mamoru.');
      }
      return;
    }
 
    setState(() => _procesando = true);
    await _controller.stop();
 
    try {
      final usuario = await AuthService.canjearInvitacion(codigo);
      if (!mounted) return;
 
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => InicioAdultoMayorScreen(nombre: usuario.nombre),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      _avisar(e.mensaje);
      await _reanudar();
    } catch (_) {
      _avisar('No se pudo validar la invitación. Revisa tu conexión.');
      await _reanudar();
    }
  }
 
  /// Vuelve a encender la cámara tras un error para poder reintentar.
  Future<void> _reanudar() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _procesando = false);
    try {
      await _controller.start();
    } catch (_) {
      // Si la cámara no vuelve, el estado de error de la pantalla lo mostrará.
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escanear invitación',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Apunta la cámara al código QR',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, estado, _) {
                      if (estado.error != null) return const SizedBox.shrink();
                      final encendida = estado.torchState == TorchState.on;
                      return IconButton(
                        tooltip: encendida ? 'Apagar linterna' : 'Encender linterna',
                        icon: Icon(
                          encendida ? Icons.flash_on : Icons.flash_off,
                          color: encendida ? Colors.amber : Colors.white70,
                        ),
                        onPressed: () => _controller.toggleTorch(),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, estado, _) {
                  final error = estado.error;
                  if (error != null) {
                    return _SinCamara(
                      permisoDenegado: error.errorCode ==
                          MobileScannerErrorCode.permissionDenied,
                    );
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _alDetectar,
                      ),
                      Center(
                        child: CustomPaint(
                          size: const Size(220, 220),
                          painter: _MarcoEsquinasPainter(),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 24,
                        child: Center(
                          child: _procesando
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Validando invitación…',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Centra el código QR dentro del recuadro',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  const Text(
                    '¿El adulto mayor no puede mostrar el QR?',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _procesando
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const IngresarCodigoScreen(),
                                ),
                              ),
                      icon: const Icon(Icons.dialpad),
                      label: const Text('Ingresar código manualmente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
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
    );
  }
}
 
/// Se muestra cuando la cámara no se puede usar (sin permiso u otro fallo).
class _SinCamara extends StatelessWidget {
  final bool permisoDenegado;
 
  const _SinCamara({required this.permisoDenegado});
 
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(220, 220),
                painter: _MarcoEsquinasPainter(),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.no_photography,
                  color: Colors.redAccent,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'No se pudo acceder a la cámara',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              permisoDenegado
                  ? 'Permite el acceso a la cámara en los ajustes del teléfono o usa el código manual'
                  : 'Verifica los permisos de cámara o usa el código manual',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
 
class _MarcoEsquinasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
 
    const largo = 28.0;
 
    // Esquina superior izquierda
    canvas.drawLine(Offset.zero, Offset(largo, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, largo), paint);
    // Esquina superior derecha
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - largo, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, largo), paint);
    // Esquina inferior izquierda
    canvas.drawLine(Offset(0, size.height), Offset(largo, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - largo), paint);
    // Esquina inferior derecha
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - largo, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - largo), paint);
  }
 
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}