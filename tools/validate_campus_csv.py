#!/usr/bin/env python3
"""Valida el grafo CSV del campus sin dependencias externas."""

from __future__ import annotations

import csv
import math
import sys
from collections import Counter, defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NODES_FILE = ROOT / "assets" / "data" / "campus_nodes.csv"
EDGES_FILE = ROOT / "assets" / "data" / "campus_edges.csv"
LONG_EDGE_METERS = 35.0


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as file:
        return list(csv.DictReader(file))


def main() -> int:
    nodes = read_csv(NODES_FILE)
    edges = read_csv(EDGES_FILE)
    errors: list[str] = []
    warnings: list[str] = []

    ids = [row.get("id", "").strip() for row in nodes]
    id_set = set(ids)
    duplicates = [node_id for node_id, count in Counter(ids).items() if count > 1]
    if duplicates:
        errors.append(f"IDs duplicados: {', '.join(duplicates)}")

    adjacency: dict[str, set[str]] = defaultdict(set)
    for index, edge in enumerate(edges, start=2):
        from_id = edge.get("from", "").strip()
        to_id = edge.get("to", "").strip()
        if from_id not in id_set:
            errors.append(f"Fila {index}: nodo from inexistente: {from_id}")
        if to_id not in id_set:
            errors.append(f"Fila {index}: nodo to inexistente: {to_id}")

        try:
            distance = float(edge.get("distance_meters", ""))
            if not math.isfinite(distance) or distance <= 0:
                errors.append(f"Fila {index}: distancia inválida: {distance}")
            elif distance > LONG_EDGE_METERS:
                warnings.append(
                    f"Tramo largo por revisar ({distance:.1f} m): {from_id} -> {to_id}"
                )
        except ValueError:
            errors.append(f"Fila {index}: distancia no numérica")

        adjacency[from_id].add(to_id)
        if edge.get("bidirectional", "").strip().lower() in {"true", "1", "yes", "si"}:
            adjacency[to_id].add(from_id)

    if ids:
        visited = {ids[0]}
        queue = deque([ids[0]])
        while queue:
            current = queue.popleft()
            for neighbor in adjacency[current]:
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)
        disconnected = sorted(id_set - visited)
        if disconnected:
            warnings.append(
                "Nodos desconectados del componente principal: " + ", ".join(disconnected)
            )

    qr_count = 0
    for index, node in enumerate(nodes, start=2):
        qr = node.get("qr_code", "").strip()
        if not qr:
            continue
        qr_count += 1
        parts = qr.split("|")
        if len(parts) < 3 or parts[0] != "ESPE":
            errors.append(f"Fila {index}: QR con formato inválido: {qr}")
        elif parts[1] != node.get("id", "").strip():
            errors.append(f"Fila {index}: el QR no coincide con el id del nodo")
        elif parts[2] != node.get("floor", "").strip():
            errors.append(f"Fila {index}: el piso del QR no coincide con el nodo")

    print(f"Nodos: {len(nodes)}")
    print(f"Conexiones: {len(edges)}")
    print(f"Destinos: {sum(row.get('is_destination', '').lower() == 'true' for row in nodes)}")
    print(f"QR: {qr_count}")

    if warnings:
        print("\nADVERTENCIAS")
        for warning in warnings:
            print(f"- {warning}")

    if errors:
        print("\nERRORES")
        for error in errors:
            print(f"- {error}")
        return 1

    print("\nValidación estructural correcta.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
