import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../models/campus_edge.dart';
import '../models/campus_node.dart';
import '../models/campus_route.dart';
import 'campus_graph_repository.dart';

class RouteEngine {
  const RouteEngine._();

  static CampusGraphRepository get _graph => CampusGraphRepository.instance;

  static List<CampusNode> get nodes => _graph.nodes;
  static List<CampusEdge> get edges => _graph.edges;

  static bool supportsDestination(String destinationId) {
    return nodes.any((node) => node.id == destinationId);
  }

  static CampusNode? nodeById(String nodeId) => _graph.nodeById(nodeId);

  static CampusNode closestNode({
    required double latitude,
    required double longitude,
    int? preferredFloor,
  }) {
    final candidates = preferredFloor == null
        ? nodes
        : nodes.where((node) => node.floor == preferredFloor).toList();
    final safeCandidates = candidates.isEmpty ? nodes : candidates;

    CampusNode bestNode = safeCandidates.first;
    double bestDistance = double.infinity;

    for (final node in safeCandidates) {
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        node.latitude,
        node.longitude,
      );

      if (distance < bestDistance) {
        bestDistance = distance;
        bestNode = node;
      }
    }

    return bestNode;
  }

  static CampusRoute? calculateRoute({
    required double currentLatitude,
    required double currentLongitude,
    required String destinationId,
    String? forcedStartNodeId,
    int? preferredFloor,
    bool accessibleOnly = false,
  }) {
    final startNode = forcedStartNodeId == null
        ? closestNode(
            latitude: currentLatitude,
            longitude: currentLongitude,
            preferredFloor: preferredFloor,
          )
        : nodeById(forcedStartNodeId);

    if (startNode == null) return null;

    final route = calculateRouteFromNode(
      startNodeId: startNode.id,
      destinationId: destinationId,
      accessibleOnly: accessibleOnly,
    );
    if (route == null) return null;

    final distanceFromUserToStart = forcedStartNodeId == null
        ? Geolocator.distanceBetween(
            currentLatitude,
            currentLongitude,
            startNode.latitude,
            startNode.longitude,
          )
        : 0.0;

    return CampusRoute(
      startNode: route.startNode,
      destinationNode: route.destinationNode,
      nodes: route.nodes,
      totalDistanceMeters: distanceFromUserToStart + route.totalDistanceMeters,
    );
  }

  static CampusRoute? calculateRouteFromNode({
    required String startNodeId,
    required String destinationId,
    bool accessibleOnly = false,
  }) {
    final startNode = nodeById(startNodeId);
    final destinationNode = nodeById(destinationId);
    if (startNode == null || destinationNode == null) return null;

    final pathIds = _shortestPath(
      startNode.id,
      destinationNode.id,
      accessibleOnly: accessibleOnly,
    );
    if (pathIds.isEmpty) return null;

    final routeNodes = pathIds
        .map(nodeById)
        .whereType<CampusNode>()
        .toList(growable: false);

    return CampusRoute(
      startNode: startNode,
      destinationNode: destinationNode,
      nodes: routeNodes,
      totalDistanceMeters: pathDistance(routeNodes),
    );
  }

  static double pathDistance(List<CampusNode> routeNodes, {int fromIndex = 0}) {
    if (routeNodes.length <= 1) return 0;

    double total = 0;
    final safeStart = math.max(0, math.min(fromIndex, routeNodes.length - 1));

    for (int index = safeStart; index < routeNodes.length - 1; index++) {
      total += edgeDistanceBetween(
            routeNodes[index].id,
            routeNodes[index + 1].id,
          ) ??
          Geolocator.distanceBetween(
            routeNodes[index].latitude,
            routeNodes[index].longitude,
            routeNodes[index + 1].latitude,
            routeNodes[index + 1].longitude,
          );
    }

    return total;
  }

  static CampusEdge? edgeBetween(String from, String to) {
    for (final edge in edges) {
      if (edge.from == from && edge.to == to) return edge;
      if (edge.bidirectional && edge.from == to && edge.to == from) return edge;
    }
    return null;
  }

  static double? edgeDistanceBetween(String from, String to) {
    return edgeBetween(from, to)?.distanceMeters;
  }

  static List<String> _shortestPath(
    String startId,
    String destinationId, {
    required bool accessibleOnly,
  }) {
    final nodeIds = nodes.map((node) => node.id).toSet();
    final distances = <String, double>{
      for (final id in nodeIds) id: double.infinity,
    };
    final previous = <String, String?>{
      for (final id in nodeIds) id: null,
    };
    final open = <String>{startId};

    distances[startId] = 0;

    while (open.isNotEmpty) {
      String? current;
      double bestScore = double.infinity;

      for (final id in open) {
        final score = (distances[id] ?? double.infinity) +
            _heuristic(id, destinationId);
        if (score < bestScore) {
          bestScore = score;
          current = id;
        }
      }

      if (current == null) break;
      if (current == destinationId) break;
      open.remove(current);

      final currentDistance = distances[current] ?? double.infinity;
      if (currentDistance == double.infinity) continue;

      for (final neighbor in _neighbors(
        current,
        accessibleOnly: accessibleOnly,
      )) {
        final alternative = currentDistance + neighbor.edge.distanceMeters;
        if (alternative < (distances[neighbor.nodeId] ?? double.infinity)) {
          distances[neighbor.nodeId] = alternative;
          previous[neighbor.nodeId] = current;
          open.add(neighbor.nodeId);
        }
      }
    }

    if (startId == destinationId) return [startId];
    if (previous[destinationId] == null) return const [];

    final path = <String>[];
    String? current = destinationId;

    while (current != null) {
      path.insert(0, current);
      if (current == startId) break;
      current = previous[current];
    }

    return path.isNotEmpty && path.first == startId ? path : const [];
  }

  static double _heuristic(String fromId, String destinationId) {
    final from = nodeById(fromId);
    final destination = nodeById(destinationId);
    if (from == null || destination == null) return 0;

    final sameCoordinateSystem = from.building == destination.building &&
        from.hasLocalCoordinates &&
        destination.hasLocalCoordinates;
    final horizontal = sameCoordinateSystem
        ? math.sqrt(
            math.pow(destination.localX! - from.localX!, 2) +
                math.pow(destination.localY! - from.localY!, 2),
          )
        : Geolocator.distanceBetween(
            from.latitude,
            from.longitude,
            destination.latitude,
            destination.longitude,
          );
    final floorPenalty = (from.floor - destination.floor).abs() * 12.0;
    return horizontal + floorPenalty;
  }

  static List<_Neighbor> _neighbors(
    String nodeId, {
    required bool accessibleOnly,
  }) {
    final neighbors = <_Neighbor>[];

    for (final edge in edges) {
      if (accessibleOnly && !edge.accessible) continue;

      if (edge.from == nodeId) {
        neighbors.add(_Neighbor(edge.to, edge));
      }
      if (edge.bidirectional && edge.to == nodeId) {
        neighbors.add(_Neighbor(edge.from, edge));
      }
    }

    return neighbors;
  }
}

class _Neighbor {
  final String nodeId;
  final CampusEdge edge;

  const _Neighbor(this.nodeId, this.edge);
}
