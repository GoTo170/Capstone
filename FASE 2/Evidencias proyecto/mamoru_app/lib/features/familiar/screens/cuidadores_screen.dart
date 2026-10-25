import 'package:flutter/material.dart';
import '../../../core/api_exception.dart';
import '../../shared/widgets/avatar_foto.dart';
import '../models/cuidador_marketplace.dart';
import '../services/marketplace_service.dart';
import 'detalle_cuidador_screen.dart';

class CuidadoresScreen extends StatefulWidget {
  const CuidadoresScreen({super.key});

  @override
  State<CuidadoresScreen> createState() => _CuidadoresScreenState();
}

class _CuidadoresScreenState extends State<CuidadoresScreen> {
  final _busquedaController = TextEditingController();
  String _filtroSeleccionado = 'Todos';

  List<CuidadorMarketplace> _cuidadores = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final lista = await MarketplaceService.listarCuidadores();

      if (!mounted) return;

      setState(() {
        _cuidadores = lista;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  /// Servicios que ofrece al menos un cuidador (para los filtros).
  List<String> get _serviciosDisponibles {
    final servicios = <String>{for (final c in _cuidadores) ...c.servicios}.toList();
    servicios.sort();
    return servicios;
  }

  List<CuidadorMarketplace> get _cuidadoresFiltrados {
    final texto = _busquedaController.text.trim().toLowerCase();
    return _cuidadores.where((c) {
      final coincideTexto = texto.isEmpty ||
          c.nombre.toLowerCase().contains(texto) ||
          c.ciudad.toLowerCase().contains(texto) ||
          c.servicios.any((s) => s.toLowerCase().contains(texto));
      final coincideFiltro = _filtroSeleccionado == 'Todos' || c.servicios.contains(_filtroSeleccionado);
      return coincideTexto && coincideFiltro;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Cuidadores'),
      ),
      backgroundColor: const Color(0xFFFFF7F5),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _busquedaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, servicio o ciudad...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ChipFiltro(texto: 'Todos', seleccionado: _filtroSeleccionado == 'Todos', onTap: () => setState(() => _filtroSeleccionado = 'Todos')),
                  const SizedBox(width: 8),
                  for (final servicio in _serviciosDisponibles) ...[
                    _ChipFiltro(texto: servicio, seleccionado: _filtroSeleccionado == servicio, onTap: () => setState(() => _filtroSeleccionado = servicio)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                            ],
                          ),
                        )
                      : _cuidadoresFiltrados.isEmpty
                          ? Center(
                              child: Text(
                                _cuidadores.isEmpty
                                    ? 'Todavía no hay cuidadores verificados disponibles.'
                                    : 'No se encontraron cuidadores con esos criterios.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                      itemCount: _cuidadoresFiltrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final c = _cuidadoresFiltrados[index];
                        return _TarjetaCuidador(
                          cuidador: c,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleCuidadorScreen(cuidador: c))),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipFiltro({required this.texto, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: seleccionado ? Colors.pink : Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
        child: Text(texto, style: TextStyle(fontSize: 12, color: seleccionado ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _TarjetaCuidador extends StatelessWidget {
  final CuidadorMarketplace cuidador;
  final VoidCallback onTap;

  const _TarjetaCuidador({required this.cuidador, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final serviciosVisibles = cuidador.servicios.take(3).toList();
    final restantes = cuidador.servicios.length - serviciosVisibles.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarFoto(radio: 26, url: cuidador.fotoUrl, iconoVacio: const Icon(Icons.person, color: Colors.blue, size: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(cuidador.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (cuidador.verificado) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 14, color: Colors.green),
                        const Text(' Verificado', style: TextStyle(fontSize: 11, color: Colors.green)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('${cuidador.calificacion} (${cuidador.numeroResenas} reseñas)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(cuidador.ciudad, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                      Text(
                        cuidador.tarifa == null ? 'Tarifa no disponible' : 'Desde ${formatearPrecioCLP(cuidador.precioDesde)}/hr',
                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in serviciosVisibles)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha:0.08), borderRadius: BorderRadius.circular(20)),
                          child: Text(s, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                        ),
                      if (restantes > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                          child: Text('+$restantes más', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}