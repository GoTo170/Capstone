import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../models/solicitud_servicio.dart';
import '../services/cuidador_service.dart';
 
class SolicitudesServicioScreen extends StatefulWidget {
  final List<SolicitudServicio> solicitudes;
 
  const SolicitudesServicioScreen({super.key, required this.solicitudes});
 
  @override
  State<SolicitudesServicioScreen> createState() => _SolicitudesServicioScreenState();
}
 
class _SolicitudesServicioScreenState extends State<SolicitudesServicioScreen> {
  bool _procesando = false;
 
  static const _motivosRechazo = [
    'No tengo disponibilidad',
    'El horario no me acomoda',
    'La ubicación está fuera de mi zona',
    'El tipo de cuidado no corresponde a mis servicios',
    'Otro motivo',
  ];
 
  Future<void> _aceptar(SolicitudServicio solicitud) async {
    if (_procesando) return;
 
    setState(() => _procesando = true);
 
    try {
      await CuidadorService.aceptarSolicitud(solicitud.id);
 
      if (!mounted) return;
 
      setState(() {
        solicitud.estado = EstadoSolicitud.aceptada;
        solicitud.fechaHistorialTexto = 'Hoy';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }
 
  Future<void> _abrirRechazo(SolicitudServicio solicitud) async {
    String? motivoSeleccionado;
    final motivoOtroController = TextEditingController();
    bool enviandoRechazo = false;
 
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final esOtro = motivoSeleccionado == 'Otro motivo';
            final puedeConfirmar = motivoSeleccionado != null && (!esOtro || motivoOtroController.text.trim().isNotEmpty);
 
            return Dialog(
              backgroundColor: const Color(0xFFFFF7F5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rechazar solicitud', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                Text('Indica el motivo para informar a la familia.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      for (final motivo in _motivosRechazo) ...[
                        _OpcionRechazo(
                          texto: motivo,
                          seleccionado: motivoSeleccionado == motivo,
                          esOtro: motivo == 'Otro motivo',
                          onTap: () => setDialogState(() => motivoSeleccionado = motivo),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (esOtro) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: motivoOtroController,
                          maxLength: 300,
                          maxLines: 3,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Escribe el motivo obligatorio...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: puedeConfirmar
                            ? () async {
                                if (enviandoRechazo) return;
                                enviandoRechazo = true;
 
                                final detalle = esOtro ? motivoOtroController.text.trim() : null;
                                final navegador = Navigator.of(context);
                                final mensajero = ScaffoldMessenger.of(this.context);
 
                                try {
                                  await CuidadorService.rechazarSolicitud(solicitud.id, motivoSeleccionado!, detalle: detalle);
 
                                  if (!mounted) return;
 
                                  setState(() {
                                    solicitud.estado = EstadoSolicitud.rechazada;
                                    solicitud.motivoRechazo = esOtro ? detalle : motivoSeleccionado;
                                    solicitud.fechaHistorialTexto = 'Hoy';
                                  });
                                  navegador.pop();
                                } on ApiException catch (e) {
                                  enviandoRechazo = false;
                                  mensajero.showSnackBar(
                                    SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          disabledBackgroundColor: Colors.red.withValues(alpha:0.3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Confirmar rechazo', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final nuevas = widget.solicitudes.where((s) => s.estado == EstadoSolicitud.nueva).toList();
    final historial = widget.solicitudes.where((s) => s.estado != EstadoSolicitud.nueva).toList();
 
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Solicitudes de servicio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        nuevas.isEmpty ? 'Sin solicitudes pendientes' : '${nuevas.length} solicitud${nuevas.length > 1 ? 'es' : ''} pendiente${nuevas.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    if (nuevas.isNotEmpty) ...[
                      const _EtiquetaSeccion(texto: 'NUEVAS SOLICITUDES'),
                      const SizedBox(height: 10),
                      for (final s in nuevas) ...[
                        _TarjetaSolicitudNueva(
                          solicitud: s,
                          onAceptar: () => _aceptar(s),
                          onRechazar: () => _abrirRechazo(s),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
                    ],
                    if (historial.isNotEmpty) ...[
                      const _EtiquetaSeccion(texto: 'HISTORIAL'),
                      const SizedBox(height: 10),
                      for (final s in historial) ...[
                        _TarjetaHistorial(solicitud: s),
                        const SizedBox(height: 12),
                      ],
                    ],
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
 
class _EtiquetaSeccion extends StatelessWidget {
  final String texto;
  const _EtiquetaSeccion({required this.texto});
 
  @override
  Widget build(BuildContext context) {
    return Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.6));
  }
}
 
class _TarjetaSolicitudNueva extends StatelessWidget {
  final SolicitudServicio solicitud;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
 
  const _TarjetaSolicitudNueva({required this.solicitud, required this.onAceptar, required this.onRechazar});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFDF3D8), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(radius: 20, backgroundColor: Color(0xFFF6B9D0), child: Icon(Icons.people, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(solicitud.nombreFamiliar, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Para: ${solicitud.nombreAdultoMayor}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(solicitud.fechaSolicitudTexto, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(20)),
                child: const Text('Nueva', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DatoSolicitud(etiqueta: 'FECHA Y HORA', valor: '${solicitud.fechaServicioTexto}\n${solicitud.horarioTexto}'),
                    ),
                    Expanded(
                      child: _DatoSolicitud(etiqueta: 'TIPO DE SERVICIO', valor: solicitud.tipoServicio),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _FilaTexto(icono: Icons.location_on_outlined, etiqueta: 'Dirección:', valor: solicitud.direccion),
                const SizedBox(height: 4),
                _FilaTexto(icono: Icons.info_outline, etiqueta: 'Información:', valor: solicitud.informacion),
                if (solicitud.mensaje != null) ...[
                  const SizedBox(height: 4),
                  _FilaTexto(icono: Icons.chat_bubble_outline, etiqueta: 'Mensaje:', valor: solicitud.mensaje!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRechazar,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAceptar,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Aceptar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
 
class _DatoSolicitud extends StatelessWidget {
  final String etiqueta;
  final String valor;
 
  const _DatoSolicitud({required this.etiqueta, required this.valor});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 0.4)),
        Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
 
class _FilaTexto extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
 
  const _FilaTexto({required this.icono, required this.etiqueta, required this.valor});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(text: '$etiqueta ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: valor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
 
class _TarjetaHistorial extends StatelessWidget {
  final SolicitudServicio solicitud;
 
  const _TarjetaHistorial({required this.solicitud});
 
  @override
  Widget build(BuildContext context) {
    final aceptada = solicitud.estado == EstadoSolicitud.aceptada || solicitud.estado == EstadoSolicitud.finalizada;
 
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: aceptada ? const Color(0xFFEAF7EE) : const Color(0xFFF1EEFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: aceptada ? Colors.green : Colors.deepPurple,
            child: Icon(aceptada ? Icons.check : Icons.close, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(solicitud.nombreFamiliar, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      solicitud.estado == EstadoSolicitud.finalizada
                          ? 'Finalizada'
                          : solicitud.estado == EstadoSolicitud.aceptada
                              ? 'Aceptada'
                              : 'Rechazada',
                      style: TextStyle(fontSize: 12, color: aceptada ? Colors.green[700] : Colors.deepPurple, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(solicitud.nombreAdultoMayor, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (solicitud.comentarioHistorial != null) ...[
                  const SizedBox(height: 4),
                  Text('"${solicitud.comentarioHistorial}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                ],
                if (solicitud.motivoRechazo != null) ...[
                  const SizedBox(height: 4),
                  Text('Motivo: ${solicitud.motivoRechazo}', style: const TextStyle(fontSize: 12, color: Colors.deepPurple)),
                ],
                if (solicitud.fechaHistorialTexto != null) ...[
                  const SizedBox(height: 4),
                  Text(solicitud.fechaHistorialTexto!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 
class _OpcionRechazo extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final bool esOtro;
  final VoidCallback onTap;
 
  const _OpcionRechazo({required this.texto, required this.seleccionado, required this.esOtro, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    final colorActivo = esOtro ? Colors.red : Colors.deepPurple;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? colorActivo.withValues(alpha:0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: seleccionado ? colorActivo : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(seleccionado ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: seleccionado ? colorActivo : Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: TextStyle(fontSize: 13, color: seleccionado && esOtro ? Colors.red : Colors.black87))),
          ],
        ),
      ),
    );
  }
}