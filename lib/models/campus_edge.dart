class CampusEdge {
  final String from;
  final String to;
  final double distanceMeters;
  final bool bidirectional;
  final String type;
  final bool accessible;
  final String validationStatus;
  final String notes;

  const CampusEdge({
    required this.from,
    required this.to,
    required this.distanceMeters,
    this.bidirectional = true,
    this.type = 'outdoor_path',
    this.accessible = true,
    this.validationStatus = 'por_validar',
    this.notes = '',
  });

  bool get isVerticalTransition => type == 'stairs' || type == 'elevator';
}
