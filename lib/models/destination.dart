class Destination {
  final String id;
  final String name;
  final String category;
  final String shortDescription;
  final String fullDescription;
  final String locationHint;
  final String schedule;
  final double latitude;
  final double longitude;
  final List<String> features;
  final String? imageAsset;

  const Destination({
    required this.id,
    required this.name,
    required this.category,
    required this.shortDescription,
    required this.fullDescription,
    required this.locationHint,
    required this.schedule,
    required this.latitude,
    required this.longitude,
    required this.features,
    this.imageAsset,
  });
}
