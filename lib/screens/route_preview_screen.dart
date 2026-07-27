import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/campus_route.dart';
import '../models/destination.dart';
import '../services/route_engine.dart';
import '../utils/geo_utils.dart';
import 'ar_navigation_screen.dart';
import 'place_detail_screen.dart';

class RoutePreviewScreen extends StatefulWidget {
  final Destination destination;

  const RoutePreviewScreen({super.key, required this.destination});

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  CampusRoute? _campusRoute;
  bool _loading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadRouteInfo();
  }

  Future<void> _loadRouteInfo() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      if (!RouteEngine.supportsDestination(widget.destination.id)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _statusMessage = 'Este destino todavía no está conectado al recorrido.';
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _statusMessage = 'Activa el GPS para calcular la ruta exterior.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _statusMessage = 'Permite la ubicación para calcular la ruta.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      final route = RouteEngine.calculateRoute(
        currentLatitude: position.latitude,
        currentLongitude: position.longitude,
        destinationId: widget.destination.id,
      );

      if (!mounted) return;
      setState(() {
        _campusRoute = route;
        _loading = false;
        _statusMessage = route == null
            ? 'No existe una conexión caminable hacia este destino.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = 'No se pudo calcular la ubicación actual.';
      });
    }
  }

  double? get _distanceMeters => _campusRoute?.totalDistanceMeters;

  int? get _estimatedMinutes {
    final distance = _distanceMeters;
    if (distance == null) return null;
    return math.max(1, (distance / 75).ceil());
  }

  void _startArGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArNavigationScreen(destination: widget.destination),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = _campusRoute;
    final distance = _distanceMeters;
    final minutes = _estimatedMinutes;

    return Scaffold(
      backgroundColor: const Color(0xff0c1119),
      appBar: AppBar(
        backgroundColor: const Color(0xff0c1119),
        foregroundColor: Colors.white,
        title: const Text('Preparar navegación AR'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                children: [
                  _DestinationHero(destination: widget.destination),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.directions_walk_rounded,
                          label: 'Tiempo estimado',
                          value: minutes == null ? '--' : '$minutes min',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.route_rounded,
                          label: 'Distancia',
                          value: distance == null
                              ? '--'
                              : GeoUtils.formatDistance(distance),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StatusCard(
                    loading: _loading,
                    message: _statusMessage,
                    hasRoute: route != null,
                    onRetry: _loadRouteInfo,
                  ),
                  const SizedBox(height: 16),
                  const _ArFeatureCard(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaceDetailScreen(
                              destination: widget.destination,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.info_outline_rounded),
                      label: const Text('Información'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: route == null ? null : _startArGuide,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff168cff),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.view_in_ar_rounded),
                      label: const Text('Iniciar AR'),
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
}

class _DestinationHero extends StatelessWidget {
  final Destination destination;

  const _DestinationHero({required this.destination});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: Hero(
        tag: 'destination-${destination.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (destination.imageAsset != null)
                Image.asset(destination.imageAsset!, fit: BoxFit.cover)
              else
                const ColoredBox(color: Color(0xff23344b)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xd9000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff168cff),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        destination.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      destination.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      destination.locationHint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
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

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xff171e29),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff36b8ff)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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

class _StatusCard extends StatelessWidget {
  final bool loading;
  final String? message;
  final bool hasRoute;
  final VoidCallback onRetry;

  const _StatusCard({
    required this.loading,
    required this.message,
    required this.hasRoute,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Calculando el recorrido desde tu ubicación...'
        : message ??
            'Ruta lista. La aplicación usará GPS, brújula y cámara para guiarte.';
    final color = hasRoute ? const Color(0xff21c985) : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff171e29),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(
              hasRoute
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: color,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          if (!loading && !hasRoute)
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _ArFeatureCard extends StatelessWidget {
  const _ArFeatureCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xff168cff).withValues(alpha: 0.18),
            const Color(0xff171e29),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xff36b8ff).withValues(alpha: 0.25)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Durante la navegación',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 13),
          _FeatureLine(Icons.navigation_rounded,
              'Una flecha aumentada indicará la dirección.'),
          _FeatureLine(Icons.record_voice_over_rounded,
              'La guía por voz anunciará giros y distancia.'),
          _FeatureLine(Icons.location_searching_rounded,
              'Una baliza virtual aparecerá cerca del destino.'),
          _FeatureLine(Icons.vibration_rounded,
              'El celular vibrará y mostrará una confirmación al llegar.'),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureLine(this.icon, this.text);

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
