// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "RevenueCat",
  platforms: [.iOS(.v13)],
  products: [
    .library(
      name: "RevenueCat",
      targets: [
        "RevenueCat",
      ]
    ),
  ],

  targets: [
    .binaryTarget(
      name: "RevenueCat",
      url: "https://github.com/exception7601/RevenueCat/releases/download/5.39.3/revenuecat-6dae70a807776e19.zip",
      checksum: "6473a2ae34b4c3a481fbd1d67183c0b5d320b463bbce671cf463e87673720d7f"
    )
  ]
)
