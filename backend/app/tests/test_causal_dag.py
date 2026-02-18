"""Tests for CausalDAG — topological ordering and hard constraints."""

import pytest

from app.services.causal.dag import (
    CausalDAG,
    DAGEdge,
    EdgeType,
    NodeType,
    TOPOLOGICAL_ORDER,
    node_type_from_id,
)


class TestNodeTypeFromId:
    def test_meal(self):
        assert node_type_from_id("meal_42") == NodeType.meal

    def test_glucose(self):
        assert node_type_from_id("glucose_7") == NodeType.glucose

    def test_behavioral(self):
        assert node_type_from_id("behavioral_1") == NodeType.behavioral

    def test_environment(self):
        assert node_type_from_id("environment_3") == NodeType.environmental

    def test_physiological(self):
        assert node_type_from_id("physio_5") == NodeType.physiological

    def test_symptom(self):
        assert node_type_from_id("symptom_1") == NodeType.symptom

    def test_unknown_prefix(self):
        assert node_type_from_id("unknown_99") is None


class TestTopologicalOrder:
    def test_order(self):
        expected = [
            NodeType.meal,
            NodeType.environmental,
            NodeType.behavioral,
            NodeType.glucose,
            NodeType.physiological,
            NodeType.symptom,
        ]
        assert TOPOLOGICAL_ORDER == expected

    def test_meal_before_glucose(self):
        assert TOPOLOGICAL_ORDER.index(NodeType.meal) < TOPOLOGICAL_ORDER.index(NodeType.glucose)

    def test_glucose_before_symptom(self):
        assert TOPOLOGICAL_ORDER.index(NodeType.glucose) < TOPOLOGICAL_ORDER.index(NodeType.symptom)


class TestCausalDAG:
    def test_add_valid_edge(self):
        dag = CausalDAG()
        edge = DAGEdge("meal_1", "glucose_1", EdgeType.meal_to_glucose, 0.8)
        assert dag.add_edge(edge) is True
        assert len(dag.neighbors("meal_1")) == 1

    def test_forbidden_behavioral_to_glucose(self):
        """Behavioral CANNOT cause Glucose."""
        dag = CausalDAG()
        edge = DAGEdge("behavioral_1", "glucose_1", EdgeType.causal, 0.5)
        assert dag.add_edge(edge) is False
        assert len(dag.neighbors("behavioral_1")) == 0

    def test_forbidden_symptom_to_meal(self):
        """Symptom CANNOT cause Meal."""
        dag = CausalDAG()
        edge = DAGEdge("symptom_1", "meal_1", EdgeType.causal, 0.5)
        assert dag.add_edge(edge) is False

    def test_forbidden_environmental_to_behavioral(self):
        """Environmental CANNOT cause Behavioral."""
        dag = CausalDAG()
        edge = DAGEdge("environment_1", "behavioral_1", EdgeType.causal, 0.5)
        assert dag.add_edge(edge) is False

    def test_reverse_topological_rejected(self):
        """Later nodes cannot cause earlier nodes."""
        dag = CausalDAG()
        edge = DAGEdge("symptom_1", "glucose_1", EdgeType.causal, 0.5)
        assert dag.add_edge(edge) is False

    def test_same_level_allowed(self):
        """Same topological level is allowed."""
        dag = CausalDAG()
        edge = DAGEdge("meal_1", "meal_2", EdgeType.temporal, 0.5)
        assert dag.add_edge(edge) is True

    def test_unknown_prefix_rejected(self):
        dag = CausalDAG()
        edge = DAGEdge("unknown_1", "glucose_1", EdgeType.causal, 0.5)
        assert dag.add_edge(edge) is False

    def test_trace_paths_simple(self):
        dag = CausalDAG()
        dag.add_edge(DAGEdge("meal_1", "glucose_1", EdgeType.meal_to_glucose, 0.8))
        dag.add_edge(DAGEdge("glucose_1", "physio_1", EdgeType.glucose_to_hrv, 0.6))

        paths = dag.trace_paths("meal_1", "physio_1")
        assert len(paths) == 1
        assert len(paths[0]) == 2
        assert paths[0][0].source == "meal_1"
        assert paths[0][1].target == "physio_1"

    def test_trace_paths_no_path(self):
        dag = CausalDAG()
        dag.add_edge(DAGEdge("meal_1", "glucose_1", EdgeType.meal_to_glucose, 0.8))
        paths = dag.trace_paths("meal_1", "symptom_1")
        assert len(paths) == 0

    def test_trace_paths_multiple(self):
        dag = CausalDAG()
        dag.add_edge(DAGEdge("meal_1", "glucose_1", EdgeType.meal_to_glucose, 0.8))
        dag.add_edge(DAGEdge("meal_1", "glucose_2", EdgeType.meal_to_glucose, 0.6))
        dag.add_edge(DAGEdge("glucose_1", "physio_1", EdgeType.glucose_to_hrv, 0.5))
        dag.add_edge(DAGEdge("glucose_2", "physio_1", EdgeType.glucose_to_hrv, 0.7))

        paths = dag.trace_paths("meal_1", "physio_1")
        assert len(paths) == 2

    def test_path_strength(self):
        dag = CausalDAG()
        path = [
            DAGEdge("meal_1", "glucose_1", EdgeType.meal_to_glucose, 0.8),
            DAGEdge("glucose_1", "physio_1", EdgeType.glucose_to_hrv, 0.5),
        ]
        assert pytest.approx(dag.path_strength(path), abs=0.001) == 0.4

    def test_is_valid_direction(self):
        dag = CausalDAG()
        assert dag.is_valid_direction(NodeType.meal, NodeType.glucose) is True
        assert dag.is_valid_direction(NodeType.glucose, NodeType.meal) is False
        assert dag.is_valid_direction(NodeType.behavioral, NodeType.glucose) is False

    def test_all_edges(self):
        dag = CausalDAG()
        dag.add_edge(DAGEdge("meal_1", "glucose_1", EdgeType.meal_to_glucose, 0.8))
        dag.add_edge(DAGEdge("glucose_1", "physio_1", EdgeType.glucose_to_hrv, 0.6))
        assert len(dag.all_edges()) == 2

    def test_vita_user_dag_mapping(self):
        """Test the specific VITA user's DAG mapping from the plan."""
        dag = CausalDAG()

        # [Flour_Type] + [Roti_Count] → [Glucose_Response]
        assert dag.add_edge(DAGEdge("meal_1", "glucose_1", EdgeType.meal_to_glucose, 0.8))

        # [Glucose_Response] + [Low_Fiber] → [Metabolic_Debt] (glucose → energy → symptom)
        assert dag.add_edge(DAGEdge("glucose_1", "physio_1", EdgeType.glucose_to_energy, 0.7))

        # [Screen_Time] + [High_Dopamine_App] → [Digital_Debt] (behavior → HRV → symptom)
        assert dag.add_edge(DAGEdge("behavioral_1", "physio_1", EdgeType.behavior_to_hrv, 0.6))

        # Verify all paths from meal to physio
        paths = dag.trace_paths("meal_1", "physio_1")
        assert len(paths) == 1  # meal → glucose → physio
