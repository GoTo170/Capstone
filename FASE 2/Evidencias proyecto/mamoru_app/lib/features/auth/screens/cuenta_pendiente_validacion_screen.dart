import 'package:flutter/material.dart';

class CuentaPendienteValidacionScreen
    extends StatelessWidget {
  final String email;

  const CuentaPendienteValidacionScreen({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFFBF9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 30,
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration:
                      const BoxDecoration(
                    color: Color(0xFFF0E8FA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons
                        .admin_panel_settings_outlined,
                    size: 42,
                    color: Color(0xFF7B63A8),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Tu correo fue verificado',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF342A38),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Tu cuenta de cuidador está pendiente de validación.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(0xFF766C76),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Un administrador de Mamoru revisará la información y documentación de tu perfil antes de habilitar tu cuenta.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color:
                        Color(0xFF9D929F),
                  ),
                ),

                const SizedBox(height: 26),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color:
                        const Color(
                          0xFFF8F5FC,
                        ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color:
                          const Color(
                            0xFFE3D8F1,
                          ),
                    ),
                  ),
                  child: Column(
                    children: [
                      _estado(
                        icon:
                            Icons.check_circle,
                        texto:
                            'Correo electrónico verificado',
                        completado: true,
                      ),

                      _linea(),

                      _estado(
                        icon:
                            Icons.manage_search,
                        texto:
                            'Revisión de antecedentes',
                        completado: false,
                      ),

                      _linea(),

                      _estado(
                        icon:
                            Icons.verified_outlined,
                        texto:
                            'Habilitación como cuidador',
                        completado: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        const Color(
                          0xFFF0FBF6,
                        ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .email_outlined,
                        size: 19,
                        color:
                            Color(
                              0xFF479B78,
                            ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Text(
                          'Te avisaremos en $email cuando finalice la revisión.',
                          style:
                              const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color:
                                Color(
                                  0xFF479B78,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil(
                        (route) =>
                            route.isFirst,
                      );
                    },
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                            0xFF59C49C,
                          ),
                      foregroundColor:
                          Colors.white,
                      elevation: 0,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Volver al inicio',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Mientras tu cuenta esté pendiente no podrás ofrecer servicios como cuidador.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color:
                        Color(0xFFA69CA6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _estado({
    required IconData icon,
    required String texto,
    required bool completado,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: completado
                ? const Color(0xFFE3F7ED)
                : const Color(0xFFEDE7F5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: completado
                ? const Color(0xFF52B788)
                : const Color(0xFF927DA9),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
              color: completado
                  ? const Color(
                      0xFF4B866D,
                    )
                  : const Color(
                      0xFF766C76,
                    ),
            ),
          ),
        ),

        if (completado)
          const Icon(
            Icons.check,
            size: 18,
            color:
                Color(0xFF52B788),
          ),
      ],
    );
  }

  Widget _linea() {
    return Container(
      margin: const EdgeInsets.only(
        left: 16,
      ),
      height: 18,
      alignment: Alignment.centerLeft,
      child: Container(
        width: 2,
        height: 18,
        color: const Color(
          0xFFE7DEE9,
        ),
      ),
    );
  }
}