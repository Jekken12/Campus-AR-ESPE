import 'dart:math' as math;

class GeoUtils {
  static double degreesToRadians(double degrees) => degrees * math.pi / 180.0;

  static double radiansToDegrees(double radians) => radians * 180.0 / math.pi;

  static double normalizeAngle(double angle) {
    final normalized = angle % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  /// Normaliza un ángulo al intervalo -180..180.
  static double normalizeSignedAngle(double angle) {
    final normalized = normalizeAngle(angle);
    return normalized > 180 ? normalized - 360 : normalized;
  }

  /// Suaviza ángulos sin saltar al cruzar de 359° a 0°.
  static double smoothAngle({
    required double previous,
    required double current,
    double alpha = 0.18,
  }) {
    final difference = normalizeSignedAngle(current - previous);
    return normalizeAngle(previous + difference * alpha);
  }

  /// Devuelve el rumbo desde la ubicación actual hasta el destino.
  /// 0 = norte, 90 = este, 180 = sur, 270 = oeste.
  static double bearingBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final lat1 = degreesToRadians(startLatitude);
    final lat2 = degreesToRadians(endLatitude);
    final deltaLongitude = degreesToRadians(endLongitude - startLongitude);

    final y = math.sin(deltaLongitude) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLongitude);

    final bearing = radiansToDegrees(math.atan2(y, x));
    return normalizeAngle(bearing);
  }

  /// Rumbo en un plano local donde X crece hacia el este y Y hacia el norte.
  static double planarBearing({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
  }) {
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    return normalizeAngle(radiansToDegrees(math.atan2(deltaX, deltaY)));
  }

  static double planarDistance({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
  }) {
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    return math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }

  /// Convierte el rumbo del destino y el rumbo del celular en una rotación relativa.
  /// 0 = destino al frente del celular, 90 = a la derecha, 180 = atrás.
  static double relativeDirection({
    required double destinationBearing,
    required double phoneHeading,
  }) {
    return normalizeAngle(destinationBearing - phoneHeading);
  }

  static String humanDirection(double relativeAngle) {
    if (relativeAngle >= 337.5 || relativeAngle < 22.5) return 'Sigue recto';
    if (relativeAngle >= 22.5 && relativeAngle < 67.5) return 'Gira un poco a la derecha';
    if (relativeAngle >= 67.5 && relativeAngle < 112.5) return 'Gira a la derecha';
    if (relativeAngle >= 112.5 && relativeAngle < 157.5) return 'Destino atrás a la derecha';
    if (relativeAngle >= 157.5 && relativeAngle < 202.5) return 'Da la vuelta';
    if (relativeAngle >= 202.5 && relativeAngle < 247.5) return 'Destino atrás a la izquierda';
    if (relativeAngle >= 247.5 && relativeAngle < 292.5) return 'Gira a la izquierda';
    return 'Gira un poco a la izquierda';
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
}
