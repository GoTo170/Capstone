import 'package:flutter/material.dart';
import 'ingresar_codigo_screen.dart';

class EscanearInvitacionScreen extends StatelessWidget {
  const EscanearInvitacionScreen({super.key});

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Escanear invitación', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Apunta la cámara al código QR', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
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
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.no_photography, color: Colors.redAccent, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('No se pudo acceder a la cámara', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Verifica los permisos de cámara o usa el código manual',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Centra el código QR dentro del recuadro',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const Text('¿El adulto mayor no puede mostrar el QR?', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const IngresarCodigoScreen()),
                      ),
                      icon: const Icon(Icons.dialpad),
                      label: const Text('Ingresar código manualmente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: Colors.white,
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