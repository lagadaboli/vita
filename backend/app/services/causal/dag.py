"""Deterministic causal DAG — mirrors Swift CausalDAG structure.

Topological order: meal → environmental → behavioral → glucose → physiological → symptom

Hard constraints (forbidden edges):
  - behavioral → glucose
  - symptom → meal
  - environmental → behavioral
"""

from __future__ import annotations

from enum import Enum
from dataclasses import dataclass


class NodeType(str, Enum):
    """Causal graph node types — mirrors Swift HealthGraphNodeType."""

    meal = "meal"
    environmental = "environmental"
    behavioral = "behavioral"
    glucose = "glucose"
    physiological = "physiological"
    symptom = "symptom"


class EdgeType(str, Enum):
    """Edge type labels — mirrors Swift HealthGraphEdge.EdgeType."""

    meal_to_glucose = "meal_to_glucose"
    glucose_to_hrv = "glucose_to_hrv"
    glucose_to_energy = "glucose_to_energy"
    behavior_to_hrv = "behavior_to_hrv"
    meal_to_sleep = "meal_to_sleep"
    behavior_to_sleep = "behavior_to_sleep"
    environment_to_hrv = "environment_to_hrv"
    environment_to_sleep = "environment_to_sleep"
    environment_to_digestion = "environment_to_digestion"
    behavior_to_meal = "behavior_to_meal"
    temporal = "temporal"
    causal = "causal"


# Fixed topological order — earlier indices can cause later indices
TOPOLOGICAL_ORDER: list[NodeType] = [
    NodeType.meal,
    NodeType.environmental,
    NodeType.behavioral,
    NodeType.glucose,
    NodeType.physiological,
    NodeType.symptom,
]

# Hard constraints: (source, target) pairs that are forbidden
FORBIDDEN_EDGES: set[tuple[NodeType, NodeType]] = {
    (NodeType.behavioral, NodeType.glucose),
    (NodeType.symptom, NodeType.meal),
    (NodeType.environmental, NodeType.behavioral),
}

# Node ID prefix → NodeType mapping
_PREFIX_MAP: dict[str, NodeType] = {
    "meal_": NodeType.meal,
    "environment_": NodeType.environmental,
    "behavioral_": NodeType.behavioral,
    "glucose_": NodeType.glucose,
    "physio_": NodeType.physiological,
    "symptom_": NodeType.symptom,
}


def node_type_from_id(node_id: str) -> NodeType | None:
    """Infer NodeType from a node ID prefix."""
    for prefix, ntype in _PREFIX_MAP.items():
        if node_id.startswith(prefix):
            return ntype
    return None


@dataclass
class DAGEdge:
    """A directed edge in the causal DAG."""

    source: str  # node ID
    target: str  # node ID
    edge_type: EdgeType
    weight: float = 0.5  # causal strength


class CausalDAG:
    """Deterministic causal DAG with topological ordering and hard constraints."""

    def __init__(self) -> None:
        self._adjacency: dict[str, list[DAGEdge]] = {}

    def add_edge(self, edge: DAGEdge) -> bool:
        """Add an edge if it respects hard constraints and topological order.

        Returns True if the edge was added, False if it violates constraints.
        """
        src_type = node_type_from_id(edge.source)
        tgt_type = node_type_from_id(edge.target)

        if src_type is None or tgt_type is None:
            return False

        # Check hard constraints
        if (src_type, tgt_type) in FORBIDDEN_EDGES:
            return False

        # Check topological order: source must come before or at same level
        src_idx = TOPOLOGICAL_ORDER.index(src_type)
        tgt_idx = TOPOLOGICAL_ORDER.index(tgt_type)
        if src_idx > tgt_idx:
            return False

        self._adjacency.setdefault(edge.source, []).append(edge)
        return True

    def neighbors(self, node_id: str) -> list[DAGEdge]:
        """Get outgoing edges from a node."""
        return self._adjacency.get(node_id, [])

    def all_edges(self) -> list[DAGEdge]:
        """Get all edges in the DAG."""
        edges = []
        for edge_list in self._adjacency.values():
            edges.extend(edge_list)
        return edges

    def trace_paths(
        self, source: str, target: str, max_depth: int = 6
    ) -> list[list[DAGEdge]]:
        """Find all causal paths from source to target using DFS.

        Returns list of paths, each path is a list of edges.
        """
        paths: list[list[DAGEdge]] = []
        self._dfs(source, target, [], set(), paths, max_depth)
        return paths

    def _dfs(
        self,
        current: str,
        target: str,
        path: list[DAGEdge],
        visited: set[str],
        results: list[list[DAGEdge]],
        max_depth: int,
    ) -> None:
        if len(path) > max_depth:
            return
        if current == target:
            if path:
                results.append(list(path))
            return

        visited.add(current)
        for edge in self.neighbors(current):
            if edge.target not in visited:
                path.append(edge)
                self._dfs(edge.target, target, path, visited, results, max_depth)
                path.pop()
        visited.discard(current)

    def path_strength(self, path: list[DAGEdge]) -> float:
        """Compute path strength as product of edge weights."""
        strength = 1.0
        for edge in path:
            strength *= edge.weight
        return strength

    def is_valid_direction(self, source_type: NodeType, target_type: NodeType) -> bool:
        """Check if a causal direction is valid."""
        if (source_type, target_type) in FORBIDDEN_EDGES:
            return False
        src_idx = TOPOLOGICAL_ORDER.index(source_type)
        tgt_idx = TOPOLOGICAL_ORDER.index(target_type)
        return src_idx <= tgt_idx
