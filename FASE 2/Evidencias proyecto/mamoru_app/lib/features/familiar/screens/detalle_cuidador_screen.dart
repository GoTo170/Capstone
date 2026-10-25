import 'package:flutter/material.dart';
 
import '../../auth/models/profesion_cuidador.dart';
import '../../shared/widgets/aviso_profesional_salud.dart';
import '../../shared/widgets/avatar_foto.dart';
import '../models/cuidador_marketplace.dart';
import 'solicitud_servicio_screen.dart';
 
class DetalleCuidadorScreen extends StatelessWidget {
  final CuidadorMarketplace cuidador;
  const DetalleCuidadorScreen({super.key, required this.cuidador});
 
  /// Datos de la profesión según el catálogo del registro.
  ProfesionCuidador? get _infoProfesion {
    for (final p in catalogoProfesiones) {
      if (p.nombre == cuidador.profesion) return p;
    }
    return null;
  }
 
  /// Mismo criterio que usa el perfil del propio cuidador (esProfesionMedica).
  /// Además se respeta lo que el servidor tiene marcado como área de la salud,
  /// para que el aviso no se pierda si el nombre de la profesión no coincide
  /// con el catálogo.
  bool get _esAreaSalud {
    final info = _infoProfesion;
    return (info != null && esProfesionMedica(info.id)) || cuidador.esAreaSalud;
  }
 
  @override
  Widget build(BuildContext context) {
    final tarifa = cuidador.tarifa;
 
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F5),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Perfil del cuidador'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ------------------------------------------------ encabezado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarFoto(radio: 30, url: cuidador.fotoUrl, iconoVacio: const Icon(Icons.person, color: Colors.blue, size: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(cuidador.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                            if (cuidador.verificado) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 15, color: Colors.green),
                              const Text(' Verificado', style: TextStyle(fontSize: 12, color: Colors.green)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(cuidador.profesion, style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              cuidador.numeroResenas == 0
                                  ? 'Sin reseñas todavía'
                                  : '${cuidador.calificacion} (${cuidador.numeroResenas} ${cuidador.numeroResenas == 1 ? 'reseña' : 'reseñas'})',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(child: Text(cuidador.ciudad, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
 
            // ------------------------------------------------ advertencia (profesiones de la salud)
            if (_esAreaSalud) ...[
              const AvisoProfesionalSalud(),
              const SizedBox(height: 10),
            ],
 
            // ------------------------------------------------ sobre mí
            _Seccion(
              titulo: 'Sobre mí',
              child: Text(cuidador.descripcion, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 16),
 
            // ------------------------------------------------ información
            _Seccion(
              titulo: 'Información',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilaDato(icono: Icons.badge_outlined, etiqueta: 'Profesión', valor: cuidador.profesion),
                  if (_esAreaSalud) ...[
                    const SizedBox(height: 8),
                    const _FilaDato(icono: Icons.health_and_safety_outlined, etiqueta: 'Formación', valor: 'Profesional del área de la salud'),
                  ],
                  const SizedBox(height: 8),
                  _FilaDato(
                    icono: Icons.school_outlined,
                    etiqueta: 'Experiencia',
                    valor: cuidador.experienciaAnios > 0
                        ? '${cuidador.experienciaAnios} ${cuidador.experienciaAnios == 1 ? 'año' : 'años'}'
                        : 'No indicada',
                  ),
                  const SizedBox(height: 8),
                  _FilaDato(icono: Icons.location_on_outlined, etiqueta: 'Ubicación', valor: cuidador.ciudad),
                  const SizedBox(height: 8),
                  _FilaDato(icono: Icons.calendar_month_outlined, etiqueta: 'Disponibilidad', valor: cuidador.disponibilidad),
                ],
              ),
            ),
            const SizedBox(height: 16),
 
            // ------------------------------------------------ tarifas
            _Seccion(
              titulo: 'Tarifas',
              child: tarifa == null
                  ? const Text('Este cuidador aún no tiene tarifa disponible.', style: TextStyle(fontSize: 13, color: Colors.grey))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FilaTarifa(
                          titulo: 'Período corto',
                          detalle: '1 a 3 horas',
                          valor: '${formatearPrecioCLP(tarifa.periodoCorto)} / hora',
                        ),
                        const Divider(height: 18),
                        _FilaTarifa(
                          titulo: 'Período intermedio',
                          detalle: '4 a 7 horas · 20% menos que el período corto',
                          valor: '${formatearPrecioCLP(tarifa.periodoIntermedio)} / hora',
                        ),
                        const Divider(height: 18),
                        _FilaTarifa(
                          titulo: 'Período largo',
                          detalle: '8 a 16 horas',
                          valor: '${formatearPrecioCLP(tarifa.periodoLargo)} / hora',
                        ),
                        if (cuidador.ofrecePuertasAdentro) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFDFF3E3), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Disponible puertas adentro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                                      Text('Modalidad de cuidado diario', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${formatearPrecioCLP(tarifa.puertasAdentro!)} / día',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          'El total se calcula según la duración del servicio que solicites.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
 
            // ------------------------------------------------ servicios
            _Seccion(
              titulo: 'Servicios ofrecidos',
              child: cuidador.servicios.isEmpty
                  ? const Text('Aún no ha indicado servicios.', style: TextStyle(fontSize: 13, color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cuidador.servicios
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                                child: Text(s, style: const TextStyle(fontSize: 12, color: Colors.blue)),
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
 
            // ------------------------------------------------ valoraciones
            _Seccion(
              titulo: 'Valoraciones',
              child: cuidador.valoraciones.isEmpty
                  ? const Text('Todavía no tiene valoraciones.', style: TextStyle(fontSize: 13, color: Colors.grey))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < cuidador.valoraciones.length; i++) ...[
                          _ItemValoracionLectura(valoracion: cuidador.valoraciones[i]),
                          if (i != cuidador.valoraciones.length - 1) const Divider(height: 20),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),
 
            ElevatedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => SolicitudServicioScreen(cuidador: cuidador),
              ),
              icon: const Icon(Icons.send),
              label: const Text('Enviar solicitud de servicio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
 
/// Una fila de la tabla de tarifas: nombre del período a la izquierda y precio a la derecha.
class _FilaTarifa extends StatelessWidget {
  final String titulo;
  final String detalle;
  final String valor;
 
  const _FilaTarifa({required this.titulo, required this.detalle, required this.valor});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(detalle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
      ],
    );
  }
}
 
class _Seccion extends StatelessWidget {
  final String titulo;
  final Widget child;
 
  const _Seccion({required this.titulo, required this.child});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
 
class _FilaDato extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
 
  const _FilaDato({required this.icono, required this.etiqueta, required this.valor});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
 
class _ItemValoracionLectura extends StatelessWidget {
  final ValoracionMarketplace valoracion;
 
  const _ItemValoracionLectura({required this.valoracion});
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${valoracion.autor}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Row(children: List.generate(5, (i) => Icon(Icons.star, size: 14, color: i < valoracion.estrellas ? Colors.amber : Colors.grey.shade300))),
        const SizedBox(height: 4),
        Text(valoracion.comentario, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}