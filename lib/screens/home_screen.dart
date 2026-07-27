import 'package:flutter/material.dart';

import '../data/destinations_data.dart';
import '../models/destination.dart';
import '../services/route_engine.dart';
import 'route_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Destination> get _filteredDestinations {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return campusDestinations;
    return campusDestinations.where((destination) {
      return destination.name.toLowerCase().contains(normalized) ||
          destination.category.toLowerCase().contains(normalized) ||
          destination.shortDescription.toLowerCase().contains(normalized);
    }).toList(growable: false);
  }

  void _openDestination(Destination destination) {
    if (!RouteEngine.supportsDestination(destination.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este destino todavía no tiene una ruta configurada.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutePreviewScreen(destination: destination),
      ),
    );
  }

  void _showAbout() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff171c25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.view_in_ar_rounded,
                        color: Color(0xff36b8ff), size: 30),
                    SizedBox(width: 10),
                    Text(
                      'Campus AR ESPE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Guía exterior del campus Belisario Quevedo mediante cámara, GPS, brújula, flecha aumentada, baliza virtual e indicaciones por voz.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 16),
                const _FeatureRow(
                  icon: Icons.navigation_rounded,
                  text: 'Flecha guía con rotación suavizada',
                ),
                const _FeatureRow(
                  icon: Icons.record_voice_over_rounded,
                  text: 'Indicaciones por voz durante el recorrido',
                ),
                const _FeatureRow(
                  icon: Icons.location_searching_rounded,
                  text: 'Baliza virtual cuando el destino está cerca',
                ),
                const _FeatureRow(
                  icon: Icons.flag_rounded,
                  text: 'Confirmación visual, sonora y háptica al llegar',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _filteredDestinations;

    return Scaffold(
      backgroundColor: const Color(0xff0c1119),
      body: Stack(
        children: [
          const Positioned.fill(child: _ArBackground()),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xff36b8ff), Color(0xff3563ff)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff36b8ff)
                                    .withValues(alpha: 0.24),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.view_in_ar_rounded,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Campus AR ESPE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Navegación exterior aumentada',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          onPressed: _showAbout,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.10),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.info_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff193251), Color(0xff142235)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¿A dónde quieres ir?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Selecciona un destino y sigue la flecha sobre la cámara.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 14),
                          Icon(
                            Icons.navigation_rounded,
                            color: Color(0xff4dc4ff),
                            size: 66,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar bar, laboratorio, cancha...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Colors.white54),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white54),
                              ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Text(
                          'Destinos disponibles',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${destinations.length}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
                if (destinations.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No se encontraron destinos.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    sliver: SliverList.separated(
                      itemCount: destinations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final destination = destinations[index];
                        return _DestinationTile(
                          destination: destination,
                          onTap: () => _openDestination(destination),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final Destination destination;
  final VoidCallback onTap;

  const _DestinationTile({required this.destination, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff171e29),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'destination-${destination.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: destination.imageAsset == null
                        ? const ColoredBox(
                            color: Color(0xff24334a),
                            child: Icon(Icons.place_rounded,
                                color: Color(0xff36b8ff), size: 34),
                          )
                        : Image.asset(destination.imageAsset!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      destination.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      destination.category,
                      style: const TextStyle(
                        color: Color(0xff4dc4ff),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff36b8ff), size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _ArBackground extends StatelessWidget {
  const _ArBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -0.8),
          radius: 1.25,
          colors: [Color(0xff1b4162), Color(0xff0c1119)],
        ),
      ),
      child: CustomPaint(painter: _ArGridPainter()),
    );
  }
}

class _ArGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 34.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
