import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../models/servicio_activo.dart';
import '../services/cuidador_service.dart';
import 'servicio_finalizado_screen.dart';
 
class FinalizarServicioScreen extends StatefulWidget {
  final ServicioActivo servicio;
  final int realizadas;
  final int pendientes;
  final int noRealizadas;
  final int observaciones;
 
  const FinalizarServicioScreen({
    super.key,
    required this.servicio,
    required this.realizadas,
    required this.pendientes,
    required this.noRealizadas,
    required this.observaciones,
  });
 
  @override
  State<FinalizarServicioScreen> createState() => _FinalizarServicioScreenState();
}
 
class _FinalizarServicioScreenState extends State<FinalizarServicioScreen> {
  bool _confirmoEntendimiento = false;
  bool _finalizando = false;
 
  String _formatearFecha(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${f.year}-${d(f.month)}-${d(f.day)}';
  }
 
  Future<void> _finalizar() async {
    if (!_confirmoEntendimiento || _finalizando) return;
 
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _finalizando = true);
 
    try {
      // Primero se le avisa al servidor: sin esto el servicio seguiría activo.
      await CuidadorService.finalizarServicio(widget.servicio.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _finalizando = false);
      mensajero.showSnackBar(
        SnackBar(content: Text(e.mensaje), behavior: SnackBarBehavior.floating),
      );
      return;
    }
 
    if (!mounted) return;
 
    setState(() {
      widget.servicio.finalizadoManualmente = true;
      widget.servicio.fechaTermino = DateTime.now();
    });
 
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ServicioFinalizadoScreen(servicio: widget.servicio)),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Finalizar servicio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Esta acción no se puede deshacer', style: TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 22, backgroundColor: Color(0xFFF6D998), child: Icon(Icons.person, color: Colors.white)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.servicio.nombreAdultoMayor, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${widget.servicio.edad} años · ${widget.servicio.familiarResponsable}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('${_formatearFecha(widget.servicio.fechaInicio)} → hoy', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Resumen del servicio', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Estadistica(numero: widget.realizadas, etiqueta: 'Actividades realizadas', color: Colors.green),
                        const SizedBox(width: 10),
                        _Estadistica(numero: widget.noRealizadas, etiqueta: 'No realizadas', color: Colors.red),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Estadistica(numero: widget.pendientes, etiqueta: 'Pendientes', color: Colors.orange),
                        const SizedBox(width: 10),
                        _Estadistica(numero: widget.observaciones, etiqueta: 'Observaciones', color: Colors.deepPurple),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFFDE6E6), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                              SizedBox(width: 6),
                              Text('Antes de confirmar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _puntoLista('El servicio quedará marcado como Finalizado'),
                          _puntoLista('Ya no podrás registrar nuevas actividades u observaciones'),
                          _puntoLista('La familia recibirá una notificación y podrá valorar'),
                          _puntoLista('El historial se conserva para tu referencia'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Barra inferior fija con la casilla de confirmación y los botones de acción.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _confirmoEntendimiento = !_confirmoEntendimiento),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _confirmoEntendimiento,
                          onChanged: (v) => setState(() => _confirmoEntendimiento = v ?? false),
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Entiendo que esta acción no se puede deshacer y confirmo la finalización del servicio',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: (_confirmoEntendimiento && !_finalizando) ? _finalizar : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _finalizando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Finalizar servicio', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
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
 
  Widget _puntoLista(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 13)),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
 
class _Estadistica extends StatelessWidget {
  final int numero;
  final String etiqueta;
  final Color color;
 
  const _Estadistica({required this.numero, required this.etiqueta, required this.color});
 
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text('$numero', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(etiqueta, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}