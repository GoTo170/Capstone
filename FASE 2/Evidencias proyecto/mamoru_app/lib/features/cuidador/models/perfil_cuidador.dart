class Valoracion {
  final String? id;
  final String autor;
  final int estrellas;
  final String comentario;
  final DateTime fecha;
  bool solicitudRevisionEnviada;
  String? motivoRevision;

  Valoracion({
    this.id,
    required this.autor,
    required this.estrellas,
    required this.comentario,
    required this.fecha,
    this.solicitudRevisionEnviada = false,
    this.motivoRevision,
  });
}

class PerfilCuidadorData {
  // Campos bloqueados (no editables desde el perfil).
  final String nombre;
  final String apellido;
  final String correo;
  final String profesionId;
  final String profesionNombre;
  final int experienciaAnios;

  // Campos editables.
  String telefono;
  String descripcionPersonal;
  Set<String> especialidadesSeleccionadas;
  bool tieneFotoPerfil;

  // Dirección de la foto guardada en el servidor (null si no tiene).
  final String? fotoUrl;

  // Puertas adentro: el cambio queda pendiente de aprobación del administrador.
  bool puertasAdentroActivo;
  bool puertasAdentroPendienteAprobacion;

  PerfilCuidadorData({
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.profesionId,
    required this.profesionNombre,
    required this.experienciaAnios,
    required this.telefono,
    required this.descripcionPersonal,
    required this.especialidadesSeleccionadas,
    required this.tieneFotoPerfil,
    this.fotoUrl,
    this.puertasAdentroActivo = false,
    this.puertasAdentroPendienteAprobacion = false,
  });

  PerfilCuidadorData copia() => PerfilCuidadorData(
        nombre: nombre,
        apellido: apellido,
        correo: correo,
        profesionId: profesionId,
        profesionNombre: profesionNombre,
        experienciaAnios: experienciaAnios,
        telefono: telefono,
        descripcionPersonal: descripcionPersonal,
        especialidadesSeleccionadas: {...especialidadesSeleccionadas},
        tieneFotoPerfil: tieneFotoPerfil,
        fotoUrl: fotoUrl,
        puertasAdentroActivo: puertasAdentroActivo,
        puertasAdentroPendienteAprobacion: puertasAdentroPendienteAprobacion,
      );
}