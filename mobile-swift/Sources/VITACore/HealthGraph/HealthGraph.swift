import Foundation
import GRDB

/// The unified Health Graph — central data structure connecting all layers.
/// Provides temporal queries, node/edge management, and feeds into the Causality Engine.
public final class HealthGraph: Sendable {
    private let database: VITADatabase

    public init(database: VITADatabase) {
        self.database = database
    }

    // MARK: - Node Operations

    /// Add a physiological sample as a node in the graph.
    public func ingest(_ sample: inout PhysiologicalSample) throws {
        try database.write { db in
            try sample.save(db)
        }
    }

    /// Add a glucose reading as a node in the graph.
    public func ingest(_ reading: inout GlucoseReading) throws {
        try database.write { db in
            try reading.save(db)
        }
    }

    /// Add a meal event as a node in the graph.
    public func ingest(_ meal: inout MealEvent) throws {
        try database.write { db in
            try meal.save(db)
        }
    }

    /// Add a behavioral event as a node in the graph.
    public func ingest(_ event: inout BehavioralEvent) throws {
        try database.write { db in
            try event.save(db)
        }
    }

    /// Add an environmental condition as a node in the graph.
    public func ingest(_ condition: inout EnvironmentalCondition) throws {
        try database.write { db in
            try condition.save(db)
        }
    }

    // MARK: - Edge Operations

    /// Add a causal edge between two nodes.
    public func addEdge(_ edge: inout HealthGraphEdge) throws {
        try database.write { db in
            try edge.save(db)
        }
    }

    // MARK: - Temporal Queries

    /// Query all physiological samples within a time window.
    public func querySamples(
        type: PhysiologicalSample.MetricType,
        from startDate: Date,
        to endDate: Date
    ) throws -> [PhysiologicalSample] {
        try database.read { db in
            try PhysiologicalSample
                .filter(PhysiologicalSample.Columns.metricType == type.rawValue)
                .filter(PhysiologicalSample.Columns.timestamp >= startDate)
                .filter(PhysiologicalSample.Columns.timestamp <= endDate)
                .order(PhysiologicalSample.Columns.timestamp)
                .fetchAll(db)
        }
    }

    /// Query glucose readings within a time window.
    public func queryGlucose(
        from startDate: Date,
        to endDate: Date
    ) throws -> [GlucoseReading] {
        try database.read { db in
            try GlucoseReading
                .filter(GlucoseReading.Columns.timestamp >= startDate)
                .filter(GlucoseReading.Columns.timestamp <= endDate)
                .order(GlucoseReading.Columns.timestamp)
                .fetchAll(db)
        }
    }

    /// Query meal events within a time window.
    public func queryMeals(
        from startDate: Date,
        to endDate: Date
    ) throws -> [MealEvent] {
        try database.read { db in
            try MealEvent
                .filter(MealEvent.Columns.timestamp >= startDate)
                .filter(MealEvent.Columns.timestamp <= endDate)
                .order(MealEvent.Columns.timestamp)
                .fetchAll(db)
        }
    }

    /// Query edges originating from a specific node.
    public func queryEdges(from sourceNodeID: String) throws -> [HealthGraphEdge] {
        try database.read { db in
            try HealthGraphEdge
                .filter(HealthGraphEdge.Columns.sourceNodeID == sourceNodeID)
                .order(HealthGraphEdge.Columns.createdAt)
                .fetchAll(db)
        }
    }

    /// Find causal edges within a temporal window for a given edge type.
    public func queryEdges(
        type: HealthGraphEdge.EdgeType,
        from startDate: Date,
        to endDate: Date
    ) throws -> [HealthGraphEdge] {
        try database.read { db in
            try HealthGraphEdge
                .filter(HealthGraphEdge.Columns.edgeType == type.rawValue)
                .filter(HealthGraphEdge.Columns.createdAt >= startDate)
                .filter(HealthGraphEdge.Columns.createdAt <= endDate)
                .order(HealthGraphEdge.Columns.causalStrength.desc)
                .fetchAll(db)
        }
    }

    /// Query environmental conditions within a time window.
    public func queryEnvironment(
        from startDate: Date,
        to endDate: Date
    ) throws -> [EnvironmentalCondition] {
        try database.read { db in
            try EnvironmentalCondition
                .filter(EnvironmentalCondition.Columns.timestamp >= startDate)
                .filter(EnvironmentalCondition.Columns.timestamp <= endDate)
                .order(EnvironmentalCondition.Columns.timestamp)
                .fetchAll(db)
        }
    }

    /// Query behavioral events within a time window.
    public func queryBehaviors(
        from startDate: Date,
        to endDate: Date
    ) throws -> [BehavioralEvent] {
        try database.read { db in
            try BehavioralEvent
                .filter(BehavioralEvent.Columns.timestamp >= startDate)
                .filter(BehavioralEvent.Columns.timestamp <= endDate)
                .order(BehavioralEvent.Columns.timestamp)
                .fetchAll(db)
        }
    }
}
