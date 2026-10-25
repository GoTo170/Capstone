import 'package:flutter/material.dart';
 
import '../../../core/api_exception.dart';
import '../services/tareas_service.dart';
 
/// Categorías que se pueden adelantar. Debe coincidir con CATEGORIAS_FLEXIBLES del servidor
/// (el servidor es quien decide en última instancia). El resto tiene horario estricto.
const Set<String> categoriasFlexibles = {'comida', 'higiene', 'evento', 'mascota'};
 
/// Minutos antes de su hora en que se puede adelantar una actividad flexible.
/// Debe coincidir con MINUTOS_MAXIMOS_ADELANTO del servidor.
const int minutosMaximosAdelanto = 30;
 
/// Botón "Adelantar" de una actividad pendiente. Solo aparece en actividades flexibles
/// (comida, higiene, evento, mascota) y cuando faltan 30 minutos o menos para su hora.
/// Las de horario estricto y las ya registradas no muestran nada.
/// Se usa desde la pantalla del adulto mayor y la del cuidador, por eso recibe datos sueltos
/// y no una actividad de un modelo en particular.
class AccionesHorario extends StatelessWidget {
  final String id;
  final String titulo;
  /// Nombre del tipo de la actividad (tipo.name): comida, higiene, medicamento…
  final String categoria;
  final DateTime horaProgramada;
 
  /// true si la actividad aún no se registra como realizada ni como no realizada.
  final bool pendiente;
 
  /// Se llama después de adelantarla: la pantalla debe volver a cargar su lista.
  final VoidCallback onAdelantada;
 
  const AccionesHorario({
    super.key,
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.horaProgramada,
    required this.pendiente,
    required this.onAdelantada,
  });
 
  String _hora(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.hour)}:${d(f.minute)}';
  }
 
  Future<void> _adelantar(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adelantar actividad'),
        content: Text('"$titulo" está programada a las ${_hora(horaProgramada)}. ¿La quieres hacer ahora?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Adelantar')),
        ],
      ),
    );
    if (confirmar != true) return;
 
    try {
      await TareasService.adelantar(id);
      onAdelantada();
      mensajero.showSnackBar(const SnackBar(content: Text('Actividad adelantada. Se avisó a la familia.')));
    } on ApiException catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      mensajero.showSnackBar(const SnackBar(content: Text('No se pudo adelantar. Revisa tu conexión.')));
    }
  }
 
  @override
  Widget build(BuildContext context) {
    if (!pendiente) return const SizedBox.shrink();
 
    // Las actividades de horario estricto (medicamentos, citas médicas, recordatorios…) no se pueden adelantar: no muestran botón.
    if (!categoriasFlexibles.contains(categoria)) return const SizedBox.shrink();
 
    final falta = horaProgramada.difference(DateTime.now());
    if (falta <= Duration.zero) return const SizedBox.shrink(); // ya llegó su hora
 
    if (falta > const Duration(minutes: minutosMaximosAdelanto)) {
      final desde = horaProgramada.subtract(const Duration(minutes: minutosMaximosAdelanto));
      return Text(
        'Se puede adelantar desde las ${_hora(desde)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
 
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _adelantar(context),
        icon: const Icon(Icons.fast_forward_rounded, size: 16),
        label: const Text('Adelantar', style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );
  }
}
 