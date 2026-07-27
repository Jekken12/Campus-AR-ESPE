import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../models/campus_node.dart';
import '../models/campus_route.dart';
import '../models/destination.dart';
import '../services/route_engine.dart';
import '../utils/geo_utils.dart';
import '../widgets/ar_chevron_guide.dart';
import 'place_detail_screen.dart';

class ArNavigationScreen extends StatefulWidget {
  final Destination destination;

  const ArNavigationScreen({
    super.key,
    required this.destination,
  });

  @override
  State<ArNavigationScreen> createState() => _ArNavigationScreenState();
}

class _ArNavigationScreenState extends State<ArNavigationScreen> {
  static const double _waypointRadiusMeters = 11;
  static const double _defaultArrivalRadiusMeters = 14;
  static const double _offRouteRadiusMeters = 45;

  final FlutterTts _tts = FlutterTts();

  CameraController? _cameraController;
  Future<void>? _cameraFuture;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  Position? _currentPosition;
  CampusRoute? _route;
  int _currentWaypointIndex = 0;

  double? _heading;
  double? _distanceToWaypointMeters;
  double? _remainingDistanceMeters;
  double? _relativeAngle;
  double? _destinationRelativeAngle;
  double? _destinationDistanceMeters;

  bool _loading = true;
  bool _arrived = false;
  bool _voiceEnabled = true;
  bool _arrivalFeedbackPlayed = false;
  String? _errorMessage;
  DateTime? _arrivalCandidateSince;

  int _lastSpokenWaypointIndex = -1;
  int _lastSpokenDistanceBucket = 9999;
  String _lastSpokenDirection = '';
  DateTime _lastSpeechAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initialVoiceAnnouncementPlayed = false;

  @override
  void initState() {
    super.initState();
    _startServices();
  }

  Future<void> _startServices() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _arrived = false;
      _arrivalCandidateSince = null;
      _arrivalFeedbackPlayed = false;
    });

    try {
      await _configureVoice();
      await _initCamera();
      await _initLocation();
      _initCompass();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _configureVoice() async {
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.47);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
      try {
        await _tts.setAudioAttributesForNavigation();
      } catch (_) {
        // Esta optimización está disponible principalmente en Android.
      }
    } catch (_) {
      // La navegación sigue funcionando aunque el motor de voz no esté listo.
    }
  }

  Future<void> _initCamera() async {
    final previousController = _cameraController;
    _cameraController = null;
    await previousController?.dispose();

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No se encontró una cámara disponible.');
    }

    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraController = controller;
    _cameraFuture = controller.initialize();
    await _cameraFuture;
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Activa el GPS del celular para usar la navegación.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('La aplicación necesita permiso de ubicación.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'El permiso de ubicación está bloqueado. Actívalo desde Ajustes.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    );
    _updatePosition(position, forceRouteRecalculation: true);

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen(_updatePosition);
  }

  void _initCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Este dispositivo no dispone de brújula para orientar la flecha.';
      });
      return;
    }

    _compassSubscription?.cancel();
    _compassSubscription = stream.listen((event) {
      final rawHeading = event.heading;
      if (rawHeading == null || !mounted) return;
      final normalized = GeoUtils.normalizeAngle(rawHeading);
      setState(() {
        _heading = _heading == null
            ? normalized
            : GeoUtils.smoothAngle(
                previous: _heading!,
                current: normalized,
                alpha: 0.12,
              );
        _recalculateNavigation();
      });
    });
  }

  void _updatePosition(
    Position position, {
    bool forceRouteRecalculation = false,
  }) {
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _ensureRoute(force: forceRouteRecalculation);
      _maybeRecalculateIfOffRoute();
      _recalculateNavigation();
    });
    _maybeSpeakGuidance();
  }

  void _ensureRoute({bool force = false}) {
    final position = _currentPosition;
    if (position == null || (!force && _route != null)) return;

    final route = RouteEngine.calculateRoute(
      currentLatitude: position.latitude,
      currentLongitude: position.longitude,
      destinationId: widget.destination.id,
    );
    if (route == null || route.nodes.isEmpty) {
      _errorMessage = 'No existe una ruta caminable hacia este destino.';
      return;
    }

    _route = route;
    _currentWaypointIndex = _initialWaypointIndex(route, position);
    _arrived = false;
    _arrivalCandidateSince = null;
    _arrivalFeedbackPlayed = false;
    _errorMessage = null;
    _lastSpokenWaypointIndex = -1;
    _lastSpokenDistanceBucket = 9999;
  }

  int _initialWaypointIndex(CampusRoute route, Position position) {
    if (route.nodes.length <= 1) return 0;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      route.nodes.first.latitude,
      route.nodes.first.longitude,
    );
    return distance <= _waypointRadiusMeters ? 1 : 0;
  }

  void _maybeRecalculateIfOffRoute() {
    final position = _currentPosition;
    final waypoint = _currentWaypoint;
    if (position == null || waypoint == null || _arrived) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      waypoint.latitude,
      waypoint.longitude,
    );
    if (distance <= _offRouteRadiusMeters) return;

    final route = RouteEngine.calculateRoute(
      currentLatitude: position.latitude,
      currentLongitude: position.longitude,
      destinationId: widget.destination.id,
    );
    if (route == null || route.nodes.isEmpty) return;
    _route = route;
    _currentWaypointIndex = _initialWaypointIndex(route, position);
    _lastSpokenWaypointIndex = -1;
    _lastSpokenDistanceBucket = 9999;
  }

  void _recalculateNavigation() {
    final position = _currentPosition;
    final route = _route;
    if (position == null || route == null || route.nodes.isEmpty) return;

    _advanceWaypointIfNeeded(position, route);
    final waypoint = _currentWaypoint;
    if (waypoint == null) {
      _markArrived();
      return;
    }

    final distanceToWaypoint = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      waypoint.latitude,
      waypoint.longitude,
    );
    final waypointBearing = GeoUtils.bearingBetween(
      startLatitude: position.latitude,
      startLongitude: position.longitude,
      endLatitude: waypoint.latitude,
      endLongitude: waypoint.longitude,
    );

    final destinationDistance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );
    final destinationBearing = GeoUtils.bearingBetween(
      startLatitude: position.latitude,
      startLongitude: position.longitude,
      endLatitude: widget.destination.latitude,
      endLongitude: widget.destination.longitude,
    );

    _distanceToWaypointMeters = distanceToWaypoint;
    _destinationDistanceMeters = destinationDistance;
    _remainingDistanceMeters = distanceToWaypoint +
        RouteEngine.pathDistance(
          route.nodes,
          fromIndex: _currentWaypointIndex,
        );

    final heading = _heading;
    if (heading != null) {
      _relativeAngle = GeoUtils.relativeDirection(
        destinationBearing: waypointBearing,
        phoneHeading: heading,
      );
      _destinationRelativeAngle = GeoUtils.relativeDirection(
        destinationBearing: destinationBearing,
        phoneHeading: heading,
      );
    }

    if (_isFinalWaypoint &&
        distanceToWaypoint <= _arrivalRadiusMeters &&
        position.accuracy <= _maximumArrivalAccuracyMeters) {
      _arrivalCandidateSince ??= DateTime.now();
      if (DateTime.now().difference(_arrivalCandidateSince!).inMilliseconds >=
          2000) {
        _markArrived();
      }
    } else {
      _arrivalCandidateSince = null;
    }
  }

  void _advanceWaypointIfNeeded(Position position, CampusRoute route) {
    while (_currentWaypointIndex < route.nodes.length - 1) {
      final current = route.nodes[_currentWaypointIndex];
      final following = route.nodes[_currentWaypointIndex + 1];
      final distanceToCurrent = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        current.latitude,
        current.longitude,
      );
      final distanceToFollowing = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        following.latitude,
        following.longitude,
      );

      final reached = distanceToCurrent <= _waypointRadiusMeters;
      final passed = distanceToFollowing + 3 < distanceToCurrent;
      if (!reached && !passed) break;
      _currentWaypointIndex++;
      _lastSpokenDistanceBucket = 9999;
    }
  }

  void _markArrived() {
    if (_arrived) return;
    _arrived = true;
    _arrivalCandidateSince = null;
    _distanceToWaypointMeters = 0;
    _remainingDistanceMeters = 0;
    _relativeAngle = null;

    if (!_arrivalFeedbackPlayed) {
      _arrivalFeedbackPlayed = true;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      unawaited(
        _speak(
          'Has llegado a ${widget.destination.name}.',
          force: true,
        ),
      );
    }
  }

  CampusNode? get _currentWaypoint {
    final route = _route;
    if (route == null || route.nodes.isEmpty) return null;
    if (_currentWaypointIndex < 0 ||
        _currentWaypointIndex >= route.nodes.length) {
      return null;
    }
    return route.nodes[_currentWaypointIndex];
  }

  bool get _isFinalWaypoint {
    final route = _route;
    return route != null && _currentWaypointIndex == route.nodes.length - 1;
  }

  double get _arrivalRadiusMeters =>
      widget.destination.id == 'bar_universitario'
          ? 20
          : _defaultArrivalRadiusMeters;

  double get _maximumArrivalAccuracyMeters =>
      widget.destination.id == 'bar_universitario' ? 50 : 38;

  String get _instructionText {
    if (_arrived) return 'Has llegado';
    if (_currentWaypoint == null) return 'Calculando recorrido...';
    if (_relativeAngle == null) return 'Calibrando orientación...';

    final direction = GeoUtils.humanDirection(_relativeAngle!);
    if (_isFinalWaypoint) {
      return '$direction hacia ${widget.destination.name}';
    }
    return direction;
  }

  IconData get _instructionIcon {
    final angle = _relativeAngle;
    if (angle == null) return Icons.explore_rounded;
    final signed = GeoUtils.normalizeSignedAngle(angle);
    if (signed.abs() <= 25) return Icons.straight_rounded;
    if (signed >= 145 || signed <= -145) return Icons.u_turn_left_rounded;
    if (signed > 0) return Icons.turn_right_rounded;
    return Icons.turn_left_rounded;
  }

  bool get _showDestinationBeacon {
    final distance = _destinationDistanceMeters;
    return !_arrived && distance != null && distance <= 75;
  }

  Future<void> _speak(String text, {bool force = false}) async {
    if (!_voiceEnabled) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSpeechAt).inMilliseconds < 4200) return;
    _lastSpeechAt = now;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // La interfaz visual continúa siendo la fuente principal de navegación.
    }
  }

  void _maybeSpeakGuidance() {
    if (!_voiceEnabled || _arrived) return;
    final waypoint = _currentWaypoint;
    final distance = _distanceToWaypointMeters;
    if (waypoint == null || distance == null) return;

    if (!_initialVoiceAnnouncementPlayed) {
      _initialVoiceAnnouncementPlayed = true;
      unawaited(
        _speak(
          'Navegación iniciada hacia ${widget.destination.name}. Sigue la flecha.',
          force: true,
        ),
      );
      return;
    }

    final direction = _instructionText;
    final distanceBucket = distance <= 8
        ? 8
        : distance <= 15
            ? 15
            : distance <= 30
                ? 30
                : distance <= 60
                    ? 60
                    : 9999;

    final waypointChanged = _lastSpokenWaypointIndex != _currentWaypointIndex;
    final enteredCloserBucket = distanceBucket < _lastSpokenDistanceBucket;
    final directionChanged = direction != _lastSpokenDirection && distance <= 35;

    if (waypointChanged || enteredCloserBucket || directionChanged) {
      _lastSpokenWaypointIndex = _currentWaypointIndex;
      _lastSpokenDistanceBucket = distanceBucket;
      _lastSpokenDirection = direction;
      final distanceText = GeoUtils.formatDistance(distance);
      unawaited(_speak('$direction. En $distanceText.'));
    }
  }

  Future<void> _toggleVoice() async {
    final enabled = !_voiceEnabled;
    setState(() => _voiceEnabled = enabled);
    if (!enabled) {
      await _tts.stop();
    } else {
      unawaited(_speak('Indicaciones por voz activadas.', force: true));
    }
  }

  Future<void> _recalculateRoute() async {
    final position = _currentPosition;
    if (position == null) {
      await _startServices();
      return;
    }
    setState(() {
      _route = null;
      _currentWaypointIndex = 0;
      _arrived = false;
      _ensureRoute(force: true);
      _recalculateNavigation();
    });
    unawaited(_speak('Ruta recalculada.', force: true));
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _cameraController?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: controller == null
                ? const _CameraPlaceholder()
                : FutureBuilder<void>(
                    future: _cameraFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          controller.value.isInitialized) {
                        return _CameraPreviewCover(controller: controller);
                      }
                      return const _CameraPlaceholder();
                    },
                  ),
          ),
          const Positioned.fill(child: _CameraReadabilityGradient()),
          if (!_arrived) ...[
            _buildTopControls(),
            _buildInstructionCard(),
            if (_showDestinationBeacon)
              Positioned.fill(
                child: _DestinationBeacon(
                  destinationName: widget.destination.name,
                  distanceMeters: _destinationDistanceMeters ?? 0,
                  relativeAngle: _destinationRelativeAngle,
                ),
              ),
            Positioned.fill(
              child: ArChevronGuide(
                relativeAngle: _relativeAngle,
                distanceMeters: _distanceToWaypointMeters,
                finalApproach: _isFinalWaypoint,
              ),
            ),
            _buildBottomPanel(),
          ],
          if (_arrived) _buildArrivalOverlay(),
          if (_loading) const _LoadingOverlay(),
          if (_errorMessage != null) _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(
            children: [
              _GlassButton(
                icon: Icons.close_rounded,
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_in_ar_rounded,
                        color: Color(0xff4dc4ff), size: 18),
                    SizedBox(width: 7),
                    Text(
                      'AR EN VIVO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _GlassButton(
                icon: _voiceEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                onPressed: _toggleVoice,
                active: _voiceEnabled,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    final distance = _distanceToWaypointMeters;
    return Positioned(
      top: 84,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff36b8ff), Color(0xff176cff)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(_instructionIcon, color: Colors.white, size: 31),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _instructionText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      distance == null
                          ? 'Esperando ubicación precisa...'
                          : 'Siguiente punto en ${GeoUtils.formatDistance(distance)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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

  Widget _buildBottomPanel() {
    final route = _route;
    final accuracy = _currentPosition?.accuracy;
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              _RoundActionButton(
                icon: Icons.info_outline_rounded,
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
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _remainingDistanceMeters == null
                          ? 'Calculando distancia...'
                          : '${GeoUtils.formatDistance(_remainingDistanceMeters!)} restantes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      route == null
                          ? widget.destination.name
                          : 'GPS ±${accuracy?.toStringAsFixed(0) ?? '--'} m · Punto ${math.min(_currentWaypointIndex + 1, route.nodes.length)}/${route.nodes.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              _RoundActionButton(
                icon: Icons.refresh_rounded,
                onPressed: _recalculateRoute,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrivalOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xff0b8f4b).withValues(alpha: 0.76),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _GlassButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.30),
                        blurRadius: 42,
                        spreadRadius: 7,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.meeting_room_rounded,
                    color: Color(0xff0b8f4b),
                    size: 104,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '¡Has llegado!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  widget.destination.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.destination.locationHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff0b8f4b),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text(
                      'Finalizar navegación',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        padding: const EdgeInsets.all(26),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orangeAccent, size: 72),
              const SizedBox(height: 16),
              const Text(
                'No se pudo iniciar la guía',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Error desconocido.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _startServices,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationBeacon extends StatefulWidget {
  final String destinationName;
  final double distanceMeters;
  final double? relativeAngle;

  const _DestinationBeacon({
    required this.destinationName,
    required this.distanceMeters,
    required this.relativeAngle,
  });

  @override
  State<_DestinationBeacon> createState() => _DestinationBeaconState();
}

class _DestinationBeaconState extends State<_DestinationBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signed = widget.relativeAngle == null
        ? 0.0
        : GeoUtils.normalizeSignedAngle(widget.relativeAngle!);
    final x = (signed.clamp(-90.0, 90.0) / 90 * 0.72).toDouble();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = 0.82 + _controller.value * 0.18;
          return Align(
            alignment: Alignment(x, -0.20),
            child: Transform.scale(
              scale: pulse,
              child: SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 48,
                      child: Container(
                        width: 24,
                        height: 125,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xff53e8ff)
                                  .withValues(alpha: 0.78),
                              const Color(0xff36b8ff)
                                  .withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 188),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.60),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xff68dcff)
                              .withValues(alpha: 0.75),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: Color(0xff68dcff), size: 28),
                          Text(
                            widget.destinationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            GeoUtils.formatDistance(widget.distanceMeters),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 3,
                      child: Container(
                        width: 80,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xff68dcff)
                                  .withValues(alpha: 0.50),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CameraPreviewCover extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewCover({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const _CameraPlaceholder();

    final previewAspectRatio = previewSize.height / previewSize.width;
    final screenAspectRatio = size.width / size.height;
    final scale = previewAspectRatio / screenAspectRatio;
    return Transform.scale(
      scale: scale < 1 ? 1 / scale : scale,
      child: Center(child: CameraPreview(controller)),
    );
  }
}

class _CameraReadabilityGradient extends StatelessWidget {
  const _CameraReadabilityGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x66000000), Color(0x00000000), Color(0xaa000000)],
          stops: [0, 0.48, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xff202936),
      child: Center(
        child: Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 84),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final FutureOr<void> Function() onPressed;
  final bool active;

  const _GlassButton({
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: () => onPressed(),
      style: IconButton.styleFrom(
        backgroundColor: active
            ? const Color(0xff168cff).withValues(alpha: 0.82)
            : Colors.black.withValues(alpha: 0.44),
        foregroundColor: Colors.white,
        fixedSize: const Size(48, 48),
        side: const BorderSide(color: Colors.white24),
      ),
      icon: Icon(icon),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final FutureOr<void> Function() onPressed;

  const _RoundActionButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: () => onPressed(),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        fixedSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xff36b8ff)),
              SizedBox(height: 16),
              Text(
                'Iniciando cámara, GPS, brújula y voz...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
