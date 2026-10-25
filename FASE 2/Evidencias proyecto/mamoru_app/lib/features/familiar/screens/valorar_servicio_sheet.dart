import 'package:flutter/material.dart';
 
import '../../../core/api_exception.dart';
import '../services/marketplace_service.dart';
 
/// Abre la hoja para valorar al cuidador de un servicio finalizado.
/// Devuelve true si la valoración se envió.
Future<bool?> mostrarValoracion(
  BuildContext context, {
  required String solicitudId,
  required String nombreCuidador,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _HojaValoracion(
      solicitudId: solicitudId,
      nombreCuidador: nombreCuidador,
    ),
  );
}
 
class _HojaValoracion extends StatefulWidget {
  final String solicitudId;
  final String nombreCuidador;
 
  const _HojaValoracion({
    required this.solicitudId,
    required this.nombreCuidador,
  });
 
  @override
  State<_HojaValoracion> createState() => _HojaValoracionState();
}
 
class _HojaValoracionState extends State<_HojaValoracion> {
  static const int _largoMaximo = 500;
 
  static const List<String> _etiquetas = [
    '',
    'Muy mala',
    'Mala',
    'Regular',
    'Buena',
    'Excelente',
  ];
 
  final TextEditingController _comentario = TextEditingController();
  int _nota = 0;
  bool _enviando = false;
  String? _error;
 
  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }
 
  Future<void> _enviar() async {
    if (_nota < 1 || _nota > 5) {
      setState(() => _error = 'Elige una nota de 1 a 5 estrellas');
      return;
    }
 
    setState(() {
      _enviando = true;
      _error = null;
    });
 
    try {
      await MarketplaceService.valorarServicio(
        solicitudId: widget.solicitudId,
        puntuacion: _nota,
        comentario: _comentario.text,
      );
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      mensajero.showSnackBar(
        const SnackBar(content: Text('¡Gracias por tu valoración!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _enviando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo enviar la valoración. Revisa tu conexión.';
        _enviando = false;
      });
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
 
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + teclado),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Valorar servicio',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '¿Cómo fue el servicio de ${widget.nombreCuidador}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: _enviando ? null : () => setState(() => _nota = i),
                    iconSize: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: Icon(
                      i <= _nota ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 20,
              child: Text(
                _etiquetas[_nota],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comentario,
              enabled: !_enviando,
              maxLines: 4,
              maxLength: _largoMaximo,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Cuéntanos tu experiencia (opcional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_enviando || _nota == 0) ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enviar valoración'),
            ),
          ],
        ),
      ),
    );
  }
}
 