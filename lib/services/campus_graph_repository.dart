import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../models/campus_edge.dart';
import '../models/campus_node.dart';

class CampusGraphRepository {
  CampusGraphRepository._();

  static final CampusGraphRepository instance = CampusGraphRepository._();

  List<CampusNode> _nodes = const [];
  List<CampusEdge> _edges = const [];
  bool _loaded = false;

  List<CampusNode> get nodes => List.unmodifiable(_nodes);
  List<CampusEdge> get edges => List.unmodifiable(_edges);
  bool get isLoaded => _loaded;

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;

    final nodesText = await rootBundle.loadString('assets/data/campus_nodes.csv');
    final edgesText = await rootBundle.loadString('assets/data/campus_edges.csv');

    _nodes = _parseNodes(nodesText);
    _edges = _parseEdges(edgesText);

    if (_nodes.isEmpty) {
      throw StateError('El archivo campus_nodes.csv no contiene nodos válidos.');
    }

    _loaded = true;
  }

  CampusNode? nodeById(String nodeId) {
    for (final node in _nodes) {
      if (node.id == nodeId) return node;
    }
    return null;
  }

  List<CampusNode> _parseNodes(String source) {
    final rows = csv.decode(source);
    if (rows.isEmpty) return const [];

    final header = _headerMap(rows.first);
    final nodes = <CampusNode>[];

    for (final row in rows.skip(1)) {
      final id = _text(row, header, 'id');
      final latitude = double.tryParse(_text(row, header, 'latitude'));
      final longitude = double.tryParse(_text(row, header, 'longitude'));
      if (id.isEmpty || latitude == null || longitude == null) continue;

      nodes.add(
        CampusNode(
          id: id,
          name: _text(row, header, 'name', fallback: id),
          latitude: latitude,
          longitude: longitude,
          localX: double.tryParse(_text(row, header, 'local_x_m')),
          localY: double.tryParse(_text(row, header, 'local_y_m')),
          building: _text(row, header, 'building', fallback: 'Exterior'),
          floor: int.tryParse(_text(row, header, 'floor')) ?? 0,
          type: _text(row, header, 'type', fallback: 'waypoint'),
          isDestination: _bool(row, header, 'is_destination'),
          isDecisionPoint: _bool(row, header, 'is_decision_point'),
          qrCode: _nullableText(row, header, 'qr_code'),
          referenceHeading:
              double.tryParse(_text(row, header, 'reference_heading')),
          validationStatus:
              _text(row, header, 'validation_status', fallback: 'por_validar'),
          notes: _text(row, header, 'notes'),
        ),
      );
    }

    return nodes;
  }

  List<CampusEdge> _parseEdges(String source) {
    final rows = csv.decode(source);
    if (rows.isEmpty) return const [];

    final header = _headerMap(rows.first);
    final edges = <CampusEdge>[];

    for (final row in rows.skip(1)) {
      final from = _text(row, header, 'from');
      final to = _text(row, header, 'to');
      final distance = double.tryParse(_text(row, header, 'distance_meters'));
      if (from.isEmpty || to.isEmpty || distance == null) continue;

      edges.add(
        CampusEdge(
          from: from,
          to: to,
          distanceMeters: distance,
          bidirectional: _bool(
            row,
            header,
            'bidirectional',
            fallback: true,
          ),
          type: _text(row, header, 'type', fallback: 'outdoor_path'),
          accessible: _bool(row, header, 'accessible', fallback: true),
          validationStatus:
              _text(row, header, 'validation_status', fallback: 'por_validar'),
          notes: _text(row, header, 'notes'),
        ),
      );
    }

    return edges;
  }

  Map<String, int> _headerMap(List<dynamic> row) {
    final result = <String, int>{};
    for (var index = 0; index < row.length; index++) {
      final key = row[index]
          .toString()
          .replaceFirst('\ufeff', '')
          .trim()
          .toLowerCase();
      result[key] = index;
    }
    return result;
  }

  String _text(
    List<dynamic> row,
    Map<String, int> header,
    String key, {
    String fallback = '',
  }) {
    final index = header[key];
    if (index == null || index >= row.length) return fallback;
    final value = row[index]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String? _nullableText(
    List<dynamic> row,
    Map<String, int> header,
    String key,
  ) {
    final value = _text(row, header, key);
    return value.isEmpty ? null : value;
  }

  bool _bool(
    List<dynamic> row,
    Map<String, int> header,
    String key, {
    bool fallback = false,
  }) {
    final value = _text(row, header, key).toLowerCase();
    if (value.isEmpty) return fallback;
    return value == 'true' || value == '1' || value == 'yes' || value == 'si';
  }
}
