import 'dart:typed_data';
 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
 
import 'foto_perfil_service.dart';
import 'sesion.dart';
 
/// Foto redonda de solo lectura. Si no hay foto (o no carga), muestra [sinFoto].
class AvatarFoto extends StatelessWidget {
  final double radio;
  final Color colorFondo;
  final String? fotoUrl;
  final Uint8List? fotoLocal;
  final Widget sinFoto;
 
  const AvatarFoto({
    super.key,
    required this.radio,
    required this.colorFondo,
    required this.sinFoto,
    this.fotoUrl,
    this.fotoLocal,
  });
 
  @override
  Widget build(BuildContext context) {
    final ImageProvider? imagen = fotoLocal != null
        ? MemoryImage(fotoLocal!)
        : (fotoUrl != null && fotoUrl!.isNotEmpty ? NetworkImage(fotoUrl!) : null);
 
    return CircleAvatar(
      radius: radio,
      backgroundColor: colorFondo,
      backgroundImage: imagen,
      // Si la imagen no carga, queda el color de fondo en vez de un error rojo.
      onBackgroundImageError: imagen != null ? (_, _) {} : null,
      child: imagen == null ? sinFoto : null,
    );
  }
}
 
/// Foto redonda con botón de cámara. La pantalla que la usa decide qué hacer con la
/// foto elegida ([onElegida]) y al quitarla ([onQuitar]); si lanzan [FotoException],
/// el mensaje se muestra como aviso.
class AvatarFotoEditable extends StatefulWidget {
  final double radio;
  final Color colorFondo;
  final Color colorCamara;
  final Widget sinFoto;
 
  /// Foto ya guardada en el servidor.
  final String? fotoUrl;
 
  /// Foto recién elegida que todavía no se sube (por ejemplo, al crear la vinculación).
  final Uint8List? fotoLocal;
 
  final Future<void> Function(Uint8List bytes) onElegida;
  final Future<void> Function() onQuitar;
 
  /// Muestra "Foto actualizada" / "Foto eliminada" al terminar.
  final bool avisarExito;
 
  const AvatarFotoEditable({
    super.key,
    required this.radio,
    required this.colorFondo,
    required this.colorCamara,
    required this.sinFoto,
    required this.onElegida,
    required this.onQuitar,
    this.fotoUrl,
    this.fotoLocal,
    this.avisarExito = true,
  });
 
  @override
  State<AvatarFotoEditable> createState() => _AvatarFotoEditableState();
}
 
class _AvatarFotoEditableState extends State<AvatarFotoEditable> {
  bool _guardando = false;
 
  bool get _hayFoto => widget.fotoLocal != null || (widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty);
 
  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }
 
  Future<void> _opciones() async {
    if (_guardando) return;
 
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, 'elegir'),
            ),
            if (_hayFoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Quitar foto', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'quitar'),
              ),
          ],
        ),
      ),
    );
 
    if (accion == 'elegir') {
      await _elegir();
    } else if (accion == 'quitar') {
      await _quitar();
    }
  }
 
  Future<void> _elegir() async {
    try {
      // Se reduce la foto en el teléfono (el servidor acepta hasta 600 KB).
      final imagen = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (imagen == null) return;
 
      final bytes = await imagen.readAsBytes();
      if (!mounted) return;
 
      setState(() => _guardando = true);
      await widget.onElegida(bytes);
      if (widget.avisarExito) _aviso('Foto actualizada');
    } on FotoException catch (e) {
      _aviso(e.mensaje);
    } catch (_) {
      _aviso('No se pudo abrir la galería.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
 
  Future<void> _quitar() async {
    setState(() => _guardando = true);
    try {
      await widget.onQuitar();
      if (widget.avisarExito) _aviso('Foto eliminada');
    } on FotoException catch (e) {
      _aviso(e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final diametro = widget.radio * 2;
 
    return SizedBox(
      width: diametro,
      height: diametro,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarFoto(
            radio: widget.radio,
            colorFondo: widget.colorFondo,
            fotoUrl: widget.fotoUrl,
            fotoLocal: widget.fotoLocal,
            sinFoto: widget.sinFoto,
          ),
          if (_guardando)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: -2,
            right: -2,
            child: InkWell(
              onTap: _opciones,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                ),
                child: Icon(Icons.camera_alt, size: 16, color: widget.colorCamara),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 
/// Foto de perfil PROPIA (la del familiar que inició sesión): se guarda en el servidor
/// y en la sesión, así no se pierde al cambiar de pantalla ni al cerrar la app.
class AvatarPerfilEditable extends StatefulWidget {
  final double radio;
  final Color colorFondo;
  final Color colorCamara;
 
  /// Lo que se ve cuando todavía no hay foto (iniciales o un ícono).
  final Widget sinFoto;
 
  const AvatarPerfilEditable({
    super.key,
    required this.radio,
    required this.colorFondo,
    required this.colorCamara,
    required this.sinFoto,
  });
 
  @override
  State<AvatarPerfilEditable> createState() => _AvatarPerfilEditableState();
}
 
class _AvatarPerfilEditableState extends State<AvatarPerfilEditable> {
  @override
  Widget build(BuildContext context) {
    return AvatarFotoEditable(
      radio: widget.radio,
      colorFondo: widget.colorFondo,
      colorCamara: widget.colorCamara,
      sinFoto: widget.sinFoto,
      fotoUrl: Sesion.usuario?.fotoUrl,
      onElegida: (bytes) async {
        await FotoPerfilService.subir(bytes);
        if (mounted) setState(() {});
      },
      onQuitar: () async {
        await FotoPerfilService.quitar();
        if (mounted) setState(() {});
      },
    );
  }
}
 