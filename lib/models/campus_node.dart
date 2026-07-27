class CampusNode {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double? localX;
  final double? localY;
  final String building;
  final int floor;
  final String type;
  final bool isDestination;
  final bool isDecisionPoint;
  final String? qrCode;
  final double? referenceHeading;
  final String validationStatus;
  final String notes;

  const CampusNode({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.localX,
    this.localY,
    this.building = 'Exterior',
    this.floor = 0,
    this.type = 'waypoint',
    this.isDestination = false,
    this.isDecisionPoint = false,
    this.qrCode,
    this.referenceHeading,
    this.validationStatus = 'por_validar',
    this.notes = '',
  });

  bool get isIndoor => building.toLowerCase() != 'exterior';

  bool get hasLocalCoordinates => localX != null && localY != null;

  bool get isVerticalTransition => type == 'stairs' || type == 'elevator';

  String get floorLabel => floor <= 0 ? 'Planta baja' : 'Piso $floor';
}
