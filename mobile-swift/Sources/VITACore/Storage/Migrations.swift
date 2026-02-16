import Foundation
import GRDB

/// Database schema migrations for VITA.
/// Each migration is versioned and runs exactly once.
enum Migrations {
    static func run(on dbWriter: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        // Always reset the database in debug builds for development
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // MARK: - v1: Initial Schema

        migrator.registerMigration("v1_create_tables") { db in

            // Physiological samples (HRV, HR, sleep, blood oxygen, etc.)
            try db.create(table: "physiological_samples") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("metricType", .text).notNull()
                t.column("value", .double).notNull()
                t.column("unit", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("source", .text).notNull()
                t.column("metadata", .text) // JSON-encoded
            }

            // Meal events (consumption data from Layer 1)
            // Must be created before glucose_readings due to foreign key constraint.
            try db.create(table: "meal_events") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("source", .text).notNull()
                t.column("eventType", .text).notNull()
                t.column("ingredients", .text).notNull() // JSON-encoded
                t.column("cookingMethod", .text)
                t.column("estimatedGlycemicLoad", .double)
                t.column("bioavailabilityModifier", .double)
                t.column("confidence", .double).notNull().defaults(to: 0.5)
            }

            // Glucose readings (CGM data with classification)
            try db.create(table: "glucose_readings") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("glucoseMgDL", .double).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("trend", .text).notNull().defaults(to: "stable")
                t.column("energyState", .text).notNull().defaults(to: "stable")
                t.column("source", .text).notNull()
                t.column("relatedMealEventID", .integer)
                    .references("meal_events", onDelete: .setNull)
            }

            // Behavioral events (screen time, calendar events from Layer 3)
            try db.create(table: "behavioral_events") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("duration", .double).notNull()
                t.column("category", .text).notNull()
                t.column("appName", .text)
                t.column("dopamineDebtScore", .double)
                t.column("metadata", .text) // JSON-encoded
            }

            // Causal edges (graph connections between nodes)
            try db.create(table: "causal_edges") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sourceNodeID", .text).notNull()
                t.column("targetNodeID", .text).notNull()
                t.column("edgeType", .text).notNull()
                t.column("causalStrength", .double).notNull().defaults(to: 0.0)
                t.column("temporalOffsetSeconds", .double).notNull().defaults(to: 0)
                t.column("confidence", .double).notNull().defaults(to: 0.5)
                t.column("createdAt", .datetime).notNull()
            }

            // Causal patterns (anonymized, cloud-sync eligible)
            try db.create(table: "causal_patterns") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("pattern", .text).notNull()
                t.column("strength", .double).notNull()
                t.column("observationCount", .integer).notNull().defaults(to: 1)
                t.column("demographicBucket", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Sync state (HealthKit anchor persistence for incremental sync)
            try db.create(table: "sync_state") { t in
                t.primaryKey("metricType", .text)
                t.column("anchorData", .blob)
                t.column("lastSyncDate", .datetime).notNull()
            }

            // MARK: Indexes

            try db.create(
                index: "idx_physiological_samples_type_timestamp",
                on: "physiological_samples",
                columns: ["metricType", "timestamp"]
            )

            try db.create(
                index: "idx_glucose_readings_timestamp",
                on: "glucose_readings",
                columns: ["timestamp"]
            )

            try db.create(
                index: "idx_meal_events_timestamp",
                on: "meal_events",
                columns: ["timestamp"]
            )

            try db.create(
                index: "idx_behavioral_events_timestamp",
                on: "behavioral_events",
                columns: ["timestamp"]
            )

            try db.create(
                index: "idx_causal_edges_source",
                on: "causal_edges",
                columns: ["sourceNodeID"]
            )

            try db.create(
                index: "idx_causal_edges_target",
                on: "causal_edges",
                columns: ["targetNodeID"]
            )
        }

        // MARK: - v2: Environmental Conditions

        migrator.registerMigration("v2_environmental_conditions") { db in
            try db.create(table: "environmental_conditions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("temperatureCelsius", .double).notNull()
                t.column("humidity", .double).notNull()
                t.column("aqiUS", .integer).notNull()
                t.column("uvIndex", .double).notNull()
                t.column("pollenIndex", .integer).notNull()
                t.column("condition", .text).notNull()
            }

            try db.create(
                index: "idx_environmental_conditions_timestamp",
                on: "environmental_conditions",
                columns: ["timestamp"]
            )
        }

        try migrator.migrate(dbWriter)
    }
}
