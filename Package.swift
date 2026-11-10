// swift-tools-version: 6.2
import PackageDescription

// Reglas puras compartidas con el target iOS. No requiere SwiftUI ni SwiftData.
let package = Package(
    name: "MiMiConfianza",
    products: [.library(name: "ConfianzaCore", targets: ["ConfianzaCore"])],
    targets: [
        .target(name: "ConfianzaCore", path: "IOSLAB-9Nov/Confianza/Core"),
        .testTarget(name: "ConfianzaCoreTests", dependencies: ["ConfianzaCore"],
                    path: "IOSLAB-9NovTests",
                    exclude: ["AvisosTests.swift", "MapeoTests.swift", "PlanTests.swift", "VerificacionTests.swift", "ConfianzaPersistenciaTests.swift"],
                    sources: ["ConfianzaTests.swift"])
    ]
)
