import 'package:flutter/material.dart';
 
import '../state/familiar_contexto.dart';
import '../models/actividad.dart';
 
class SeguimientoScreen extends StatefulWidget {
  final List<Actividad> actividades;
 
  const SeguimientoScreen({super.key, required this.actividades});
 
  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}
 
class _SeguimientoScreenState extends State<SeguimientoScreen> {
  final Set<int> _expandidas = {};
 
  int get _realizadas =>
      widget.actividades.where((a) => a.estado == EstadoTarea.realizada).length;
 
  int get _pendientes =>
      widget.actividades.where((a) => a.estado == EstadoTarea.pendiente).length;
 
  int get _noRealizadas =>
      widget.actividades
          .where((a) => a.estado == EstadoTarea.noRealizada)
          .length;
 
  int get _conNotas => widget.actividades
      .where(
        (a) =>
            a.observacionCuidador != null &&
            a.observacionCuidador!.isNotEmpty,
      )
      .length;
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFBD5D8), Color(0xFFFDEDEB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
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
                            const Text('Seguimiento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('${FamiliarContexto.seleccionado?.nombreCompleto ?? 'Adulto mayor'} · Hoy', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Contador(numero: _realizadas, etiqueta: 'Realizadas', color: Colors.green),
                        const SizedBox(width: 8),
                        _Contador(numero: _pendientes, etiqueta: 'Pendientes', color: Colors.orange),
                        const SizedBox(width: 8),
                        _Contador(numero: _noRealizadas, etiqueta: 'No hechas', color: Colors.red),
                        const SizedBox(width: 8),
                        _Contador(numero: _conNotas, etiqueta: 'Con notas', color: Colors.deepPurple),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (int i = 0; i < widget.actividades.length; i++) ...[
                      _TarjetaSeguimiento(
                        actividad: widget.actividades[i],
                        expandida: _expandidas.contains(i),
                        onToggle: () => setState(() {
                          if (_expandidas.contains(i)) {
                            _expandidas.remove(i);
                          } else {
                            _expandidas.add(i);
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
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
 
class _Contador extends StatelessWidget {
  final int numero;
  final String etiqueta;
  final Color color;
 
  const _Contador({required this.numero, required this.etiqueta, required this.color});
 
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$numero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(etiqueta, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
 
class _TarjetaSeguimiento extends StatelessWidget {
  final Actividad actividad;
  final bool expandida;
  final VoidCallback onToggle;
 
  const _TarjetaSeguimiento({required this.actividad, required this.expandida, required this.onToggle});
 
  String _formatearHora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.hour)}:${d(f.minute)}';
  }
 
  Color get _colorBorde {
    switch (actividad.estado) {
      case EstadoTarea.realizada:
        return Colors.green.shade200;
      case EstadoTarea.noRealizada:
        return Colors.red.shade200;
      case EstadoTarea.pendiente:
        return Colors.orange.shade100;
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final tieneObservacion = actividad.observacionCuidador != null && actividad.observacionCuidador!.isNotEmpty;
    final completada = actividad.estado == EstadoTarea.realizada;
 
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _colorBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: actividad.tipo.color.withValues(alpha: 0.15),
                  child: Icon(actividad.tipo.icono, color: actividad.tipo.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              actividad.titulo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: completada ? TextDecoration.lineThrough : null,
                                color: completada ? Colors.grey : Colors.black87,
                              ),
                            ),
                          ),
                          _EtiquetaEstado(estado: actividad.estado),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${_formatearHora(actividad.fechaHora)} · ${actividad.tipo.etiqueta}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _TextoEstadoRegistro(actividad: actividad),
                    ],
                  ),
                ),
                if (tieneObservacion)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(expandida ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey[600]),
                    onPressed: onToggle,
                  ),
              ],
            ),
          ),
          if (tieneObservacion && expandida)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.edit_note, size: 14, color: Colors.deepPurple),
                        SizedBox(width: 4),
                        Text('Observación del cuidador', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(actividad.observacionCuidador!, style: const TextStyle(fontSize: 13)),
                    if (actividad.horaObservacion != null) ...[
                      const SizedBox(height: 6),
                      Text('Registrado a las ${_formatearHora(actividad.horaObservacion!)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
 
class _TextoEstadoRegistro extends StatelessWidget {
  final Actividad actividad;
 
  const _TextoEstadoRegistro({required this.actividad});
 
  String _formatearHora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.hour)}:${d(f.minute)}';
  }
 
  @override
  Widget build(BuildContext context) {
    final hora = actividad.horaRegistroEstado != null ? _formatearHora(actividad.horaRegistroEstado!) : null;
    final rol = actividad.completadaPorRol;
 
    // Quién la registró: el servidor lo guarda desde que se marca la actividad.
    // Las actividades antiguas no tienen ese dato y se muestran sin nombrar a nadie.
    final quien = rol == 'adulto_mayor'
        ? 'El adulto mayor'
        : rol == 'cuidador'
            ? 'El cuidador'
            : null;
 
    late final Widget principal;
    switch (actividad.estado) {
      case EstadoTarea.realizada:
        final texto = quien != null
            ? '$quien la realizó${hora != null ? ' a las $hora' : ''}'
            : 'Realizada${hora != null ? ' a las $hora' : ''}';
        principal = Row(
          children: [
            const Icon(Icons.check, size: 12, color: Colors.green),
            const SizedBox(width: 4),
            Flexible(child: Text(texto, style: const TextStyle(fontSize: 11, color: Colors.green))),
          ],
        );
        break;
      case EstadoTarea.noRealizada:
        final texto = rol == 'sistema'
            ? 'Se marcó sola: pasó su hora sin registrarse'
            : quien != null
                ? '$quien indicó que no se realizó'
                : 'No se realizó';
        principal = Row(
          children: [
            const Icon(Icons.close, size: 12, color: Colors.red),
            const SizedBox(width: 4),
            Flexible(child: Text(texto, style: const TextStyle(fontSize: 11, color: Colors.red))),
          ],
        );
        break;
      case EstadoTarea.pendiente:
        principal = const Row(
          children: [
            Icon(Icons.hourglass_empty, size: 12, color: Colors.orange),
            SizedBox(width: 4),
            Text('Aún no registrada', style: TextStyle(fontSize: 11, color: Colors.orange)),
          ],
        );
        break;
    }
 
    if (actividad.horaOriginal == null) return principal;
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        principal,
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.fast_forward_rounded, size: 12, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Adelantada: estaba programada a las ${_formatearHora(actividad.horaOriginal!)}',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
 
class _EtiquetaEstado extends StatelessWidget {
  final EstadoTarea estado;
 
  const _EtiquetaEstado({required this.estado});
 
  @override
  Widget build(BuildContext context) {
    late final String texto;
    late final Color color;
 
    switch (estado) {
      case EstadoTarea.pendiente:
        texto = 'Pendiente';
        color = Colors.orange;
        break;
      case EstadoTarea.realizada:
        texto = 'Realizada';
        color = Colors.green;
        break;
      case EstadoTarea.noRealizada:
        texto = 'No realizada';
        color = Colors.red;
        break;
    }
 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}