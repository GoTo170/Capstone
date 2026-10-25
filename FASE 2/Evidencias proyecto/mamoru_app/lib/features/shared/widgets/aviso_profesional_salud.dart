import 'package:flutter/material.dart';
 
/// Texto de la advertencia. Es el mismo que se muestra en el perfil del propio
/// cuidador cuando su profesión está relacionada con la salud.
const String textoAdvertenciaProfesionalSalud =
    'El cuidador NO está capacitado para diagnosticar, hacer recetas médicas y NO reemplaza ni sustituye a un médico.';
 
/// Recuadro rojo que deben ver las familias en el perfil de un cuidador cuya
/// profesión está relacionada con la salud.
class AvisoProfesionalSalud extends StatelessWidget {
  const AvisoProfesionalSalud({super.key});
 
  @override
  Widget build(BuildContext context) {
    const Color color = Colors.red;
 
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white,
            child: Icon(Icons.error_outline, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Advertencia importante',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
                SizedBox(height: 2),
                Text(
                  textoAdvertenciaProfesionalSalud,
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}