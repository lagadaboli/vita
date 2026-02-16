import SwiftUI
import VITADesignSystem

struct CausalChainFlowView: View {
    let nodes: [CausalChainNode]

    var body: some View {
        CausalChainView(nodes: nodes)
    }
}
