import Foundation

/// The engine's maturity phase determines which reasoning tiers are active.
/// Progresses as data accumulates and causal edge confidence grows.
public enum MaturityPhase: String, Sendable, Codable {
    case passive       // Week 1-2: Only collect data, use bio-rules
    case correlation   // Week 3-4: Start computing correlations, still rule-primary
    case causal        // Week 5-8: Edge weights have enough data, use ReAct agent
    case active        // Week 9+: Full agent with counterfactuals and LLM narratives
}

/// Configuration for the current maturity phase.
public struct PhaseConfig: Sendable {
    public let useReAct: Bool
    public let useRules: Bool
    public let useLLM: Bool
    public let maxTools: Int

    public init(useReAct: Bool, useRules: Bool, useLLM: Bool, maxTools: Int) {
        self.useReAct = useReAct
        self.useRules = useRules
        self.useLLM = useLLM
        self.maxTools = maxTools
    }
}
