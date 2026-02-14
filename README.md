# VITA — Personal Health Causality Engine

> **V**ital **I**nsights **T**hrough **A**nalysis: An iOS/macOS app that discovers causal relationships between your meals, behavior, and physiological health using real-time data and machine learning.

[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2017%20|%20macOS%2014-lightgrey.svg)](https://developer.apple.com)

## Overview

VITA is a local-first health tracking and causality engine that helps you understand the true impact of your lifestyle choices. Instead of just showing you data, VITA discovers **causal patterns** — revealing not just *what* happened, but *why* it happened and what you can do differently.

**Example insight:**
> *"Your 9pm Rotimatic rotis (white flour, GL 33) caused a glucose spike to 168 then crash to 74. Your HRV dropped 22% overnight. If you'd used whole wheat and eaten at 7pm, your deep sleep would likely improve by ~25 minutes."*

## Key Features

### Causality Discovery
- Uses Causal Graph Neural Networks (CGNN) to identify true cause-effect relationships
- Generates counterfactual scenarios ("What if I had...") with confidence intervals
- Goes beyond correlation to answer *why* patterns emerge

### Multi-Layer Health Tracking

**Layer 1: Consumption Bridge**
- Smart device integration (Rotimatic NEXT, Instant Pot Pro Plus)
- Virtual receipt parsing (Instacart, DoorDash)
- Automatic nutrient and glycemic load calculations

**Layer 2: Physiological Pulse (HealthKit)**
- Real-time Apple Watch integration (HRV, heart rate, sleep stages, blood oxygen)
- Continuous Glucose Monitor (CGM) support (Dexcom G7, Libre 3) with spike/crash feature extraction
- Metabolic state classification based on glucose curves

**Layer 3: Intentionality Tracker (Screen Time)**
- Screen time monitoring via DeviceActivity framework
- Zombie scrolling detection for Shopping & Food apps (10/20/30 min thresholds)
- Dopamine debt scoring to measure passive consumption impact

**Layer 4: Environment Bridge (Open-Meteo)**
- Weather conditions: temperature, humidity, UV index (WMO code mapping)
- Air quality: US EPA AQI
- Pollen indices: grass, birch, ragweed (normalized to 0-12 scale)
- 30-minute polling via CoreLocation (iOS) or static coordinates (macOS)
- No API key required

### Privacy-First Architecture
- **Local-first**: All raw health data stays on your device
- On-device SQLite database with GRDB
- Optional cloud sync with anonymized causality patterns only
- No PII, timestamps, or raw health values ever leave your device

### Advanced Analytics
- Temporal Graph Attention Networks for time-series pattern learning
- Structural Causal Model (SCM) layer with do-calculus interventions
- Digestive debt detection (delayed physiological costs)
- Dopamine debt tracking (behavioral costs)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        VITA Core Runtime                           │
│                    (On-Device / Local-First)                       │
│                                                                     │
│  ┌───────────────┐  ┌───────────────┐  ┌──────────────────────┐    │
│  │  Layer 1       │  │  Layer 2       │  │  Layer 3              │    │
│  │  Consumption   │  │  Physiological │  │  Intentionality       │    │
│  │  Bridge        │  │  Pulse         │  │  Tracker              │    │
│  └───────┬───────┘  └───────┬───────┘  └──────────┬───────────┘    │
│          │                  │                      │                │
│  ┌───────────────┐         │                      │                │
│  │  Layer 4       │         │                      │                │
│  │  Environment   │         │                      │                │
│  │  Bridge        │         │                      │                │
│  └───────┬───────┘         │                      │                │
│          │                  │                      │                │
│          ▼                  ▼                      ▼                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Unified Health Graph (SQLite + GRDB)            │   │
│  └─────────────────────────┬───────────────────────────────────┘   │
│                            │                                        │
│                            ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │         Causality Engine (CGNN + Counterfactual Gen)         │   │
│  └─────────────────────────┬───────────────────────────────────┘   │
│                            │                                        │
│                            ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Query Resolution Interface (NL → Causal)       │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed system design.

## Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Language** | Swift 5.9+ | Native iOS/macOS development |
| **Database** | SQLite + GRDB | On-device health graph storage |
| **ML Runtime** | CoreML + MLX | Apple silicon optimized inference |
| **GNN Framework** | PyTorch Geometric → CoreML | Causal graph neural networks |
| **Security** | iOS Keychain | Encrypted credential storage |
| **Cloud Sync** | CloudKit (optional) | E2E encrypted pattern sharing |
| **Weather API** | Open-Meteo | Free weather/AQI/pollen data |
| **Testing** | Swift Testing | Modern test framework |
| **Platforms** | iOS 17+, macOS 14+ | Modern Apple platforms |

## Project Structure

```
VITA/
├── Sources/
│   ├── VITACore/              # Core data models and health graph
│   │   ├── HealthGraph/       # Graph structure for health data
│   │   ├── Models/            # Domain models (meals, glucose, etc.)
│   │   ├── Storage/           # SQLite + GRDB persistence layer
│   │   └── SampleData/        # Mock data for development
│   │
│   ├── HealthKitBridge/       # HealthKit integration layer
│   │   ├── HealthKitManager   # Central HK coordinator
│   │   ├── HRVCollector       # Heart rate variability (observer query)
│   │   ├── HeartRateCollector  # Resting heart rate
│   │   ├── GlucoseCollector   # CGM data with trend classification
│   │   └── SleepCollector     # Sleep stage tracking
│   │
│   ├── EnvironmentBridge/     # Open-Meteo weather/AQI/pollen
│   │   ├── OpenMeteoClient    # REST API client
│   │   ├── LocationProvider   # CoreLocation / static fallback
│   │   └── EnvironmentBridge  # 30-min polling coordinator
│   │
│   ├── ConsumptionBridge/     # Meal and consumption tracking
│   ├── IntentionalityTracker/ # Screen time and behavior analysis
│   │   ├── IntentionalityTracker  # Behavior classification + dopamine debt
│   │   └── ScreenTimeTracker      # DeviceActivity monitoring (iOS)
│   ├── CausalityEngine/       # CGNN and counterfactual generation
│   └── VITADesignSystem/      # Reusable UI components
│
├── VITA/                      # Main iOS/macOS app
│   ├── App/                   # App entry point and state
│   ├── Views/                 # SwiftUI views
│   └── ViewModels/            # View logic and presentation
│
├── Tests/                     # Unit and integration tests
├── docs/                      # Documentation
│   └── ARCHITECTURE.md        # Detailed architecture guide
└── Package.swift              # Swift Package Manager manifest
```

## Installation

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+
- Apple Developer account (for HealthKit entitlements)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/lagadaboli/vita.git
   cd vita
   ```

2. **Resolve dependencies**
   ```bash
   swift package resolve
   ```

3. **Open in Xcode**
   ```bash
   open Package.swift
   ```

4. **Configure HealthKit entitlements**
   - Add HealthKit capability in Xcode project settings
   - Configure required health data types in `Info.plist`

5. **Build and run**
   - Select target device/simulator
   - Press `Cmd+R` to build and run

## Usage

### First Launch

1. **Grant HealthKit permissions** when prompted
2. **Grant Location permissions** for environment data (weather, AQI, pollen)
3. **Grant Screen Time permissions** for zombie scrolling detection (iOS only)
4. **Wait 1-2 weeks** for passive data collection to build your health graph
5. **Week 3+**: VITA begins showing correlations and patterns
6. **Week 5+**: Causal structure learning begins with tentative counterfactuals
7. **Week 9+**: Active learning mode — VITA suggests experiments to test hypotheses

### Platform Behavior

- **iOS**: Full integration — HealthKit live data, CoreLocation, Screen Time monitoring
- **macOS**: Graceful degradation — sample data for HealthKit/ScreenTime, static location for environment

All platform-specific APIs are guarded:
- HealthKit: `#if canImport(HealthKit)`
- DeviceActivity/FamilyControls: `#if os(iOS)`
- CoreLocation: `#if canImport(CoreLocation)`

### Integrating Smart Devices

**Rotimatic NEXT:**
- Connect to the same WiFi network
- VITA discovers the device via UDP broadcast (port 5353)
- Automatically captures flour type, water ratio, and cooking parameters

**Instant Pot Pro Plus:**
- Enable Bluetooth
- Pair via the Instant Brands app first
- VITA monitors BLE GATT characteristics for cooking events

**Receipt Scanning:**
- Authenticate with Instacart/DoorDash once
- VITA automatically parses new orders and maps to nutritional data

### Understanding Your Data

- **Timeline View**: See all events (meals, sleep, glucose readings) chronologically
- **Insights View**: Discover causal patterns VITA has identified
- **Counterfactuals**: Explore "what if" scenarios with intervention suggestions
- **Integrations View**: Manage connected devices and services

## Development

### Running Tests

```bash
# Run all tests (42 tests)
swift test

# Run specific test target
swift test --filter VITACoreTests
swift test --filter HealthKitBridgeTests
swift test --filter EnvironmentBridgeTests
```

### Building for Release

```bash
swift build -c release
```

### Code Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint for consistent formatting (if configured)
- Document public APIs with Swift DocC comments

## Modules

| Module | Description |
|--------|-------------|
| **VITACore** | Data models, Health Graph, GRDB storage, migrations, sample data |
| **HealthKitBridge** | Apple Watch collectors (HRV, Heart Rate, Glucose, Sleep) using `HKAnchoredObjectQuery` |
| **ConsumptionBridge** | Meal event ingestion and Instacart receipt parsing |
| **EnvironmentBridge** | Open-Meteo client for weather, AQI, and pollen; CoreLocation provider |
| **IntentionalityTracker** | Screen Time monitoring via DeviceActivity, dopamine debt scoring |
| **CausalityEngine** | Causal pattern detection and counterfactual generation |
| **VITADesignSystem** | Shared UI components, colors, and typography |

Each module can be imported independently:

```swift
import VITACore
import HealthKitBridge
import EnvironmentBridge
import CausalityEngine
```

## Privacy & Security

### Data Storage
- All raw health data stored locally in encrypted SQLite database
- iOS Keychain for API credentials and sensitive tokens
- No raw health data transmitted to servers

### Cloud Sync (Optional)
- Only anonymized causality patterns synced to CloudKit
- Differential privacy with ε = 1.0, δ = 10⁻⁵
- No PII, timestamps, or raw glucose/health values shared

### Legal Compliance
- **HIPAA**: Not a covered entity, personal tool only
- **Apple HealthKit Guidelines**: No third-party data sharing
- **GDPR/CCPA**: User is both controller and subject
- **CFAA Safe Harbor**: User explicitly authorizes access to their own data

## Roadmap

- [x] HealthKit integration (HRV, sleep, heart rate)
- [x] SQLite health graph with GRDB
- [x] Mock causality engine
- [x] Environment bridge (Open-Meteo weather, AQI, pollen)
- [x] Screen Time zombie scrolling detection
- [x] Live HealthKit collector wiring in AppState
- [ ] CGM integration (Dexcom G7, Libre 3)
- [ ] Rotimatic NEXT device discovery
- [ ] Instant Pot BLE integration
- [ ] Virtual receipt parser (Instacart, DoorDash)
- [ ] CoreML CGNN model training pipeline
- [ ] Counterfactual generator
- [ ] CloudKit pattern synchronization
- [ ] Natural language query interface

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with clear commit messages
4. Write tests for new functionality
5. Ensure all tests pass (`swift test`)
6. Submit a pull request

## License

This project is currently unlicensed. Please contact the repository owner for licensing information.

## Contact

For questions, feedback, or collaboration:
- GitHub Issues: [lagadaboli/vita/issues](https://github.com/lagadaboli/vita/issues)
