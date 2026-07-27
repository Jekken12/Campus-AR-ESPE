import 'campus_node.dart';

class CampusRoute {
  final CampusNode startNode;
  final CampusNode destinationNode;
  final List<CampusNode> nodes;
  final double totalDistanceMeters;

  const CampusRoute({
    required this.startNode,
    required this.destinationNode,
    required this.nodes,
    required this.totalDistanceMeters,
  });

  int get segmentsCount => nodes.length <= 1 ? 0 : nodes.length - 1;
}
