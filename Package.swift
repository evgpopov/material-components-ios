// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Material Components iOS",
    platforms: [ .iOS(.v10) ],
    products: [
        .library(name: "MaterialComponents", targets: ["MaterialTextFields"]),
    ],
    dependencies:[
        .package(url:"https://github.com/evgpopov/material-text-accessibility-ios", from: "2.0.0"),
        .package(url:"https://github.com/evgpopov/material-internationalization-ios", from: "3.0.0")
    ],
    targets: [
        .target(name: "AvailabilityT",
                dependencies:[],
                path: "components/AvailabilityT"),
        .target(name: "MaterialTextFields",
                dependencies:[
                    .target(name:"AvailabilityT"),
                    .target(name:"AnimationTiming"),
                    .target(name:"Buttons"),
                    .target(name:"Elevation"),
                    .target(name:"Typography"),
                    .target(name:"Math"),
                    .target(name:"Palettes"),
                    .target(name:"ContainerScheme"),
                    .target(name:"ShapeScheme"),
                    .target(name:"TypographyScheme"),
                    .target(name:"ColorScheme"),
                    "MDFInternationalization"
            ],
                path: "components/TextFields/",
                exclude:[
                    "src/ColorThemer",
                    "src/Theming",
                    "src/private/MDCTextField+Testing.h"
            ],
                sources: [
                    "src"
            ]),
        .target(name: "AnimationTiming",
                path: "components/AnimationTiming/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "ContainerScheme", 
                dependencies:[
                    .target(name:"ColorScheme"),
                    .target(name:"ShapeScheme"),
                    .target(name:"TypographyScheme"),
                    .target(name:"TypographySchemeBasicFontScheme")
            ],
                path: "components/schemes/Container/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "ShapeScheme", 
                dependencies:[
                    .target(name:"Shapes"),
                    .target(name:"ShapeLibrary")
            ],
                path: "components/schemes/Shape/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "ShapeLibrary",
                dependencies:[
                    .target(name:"Shapes")
            ],
                path: "components/ShapeLibrary/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "ColorScheme", 
                dependencies:[
                    .target(name:"Color")
            ],
                path: "components/schemes/Color/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "TypographyScheme", 
                dependencies:[
                    .target(name:"Typography"),
                    .target(name:"TypographySchemeScheming"),
                    .target(name:"TypographySchemeBasicFontScheme")
            ],
                path: "components/schemes/Typography/",
                exclude:[
                    "src/Scheming",
                    "src/BasicFontScheme"
            ],
                sources: [
                    "src",
        ],
                publicHeadersPath:"src"),
        .target(name: "TypographySchemeScheming",
                path: "components/schemes/Typography/src/Scheming/"
                ),
        .target(name: "TypographySchemeBasicFontScheme",
                path: "components/schemes/Typography/src/BasicFontScheme/"),
        .target(name: "Buttons",
                dependencies: [
                    "MDFInternationalization",
                    "MDFTextAccessibility",
                    .target(name:"Elevation"),
                    .target(name:"Ink"),
                    .target(name:"Ripple"),
                    .target(name:"ShadowElevations"),
                    .target(name:"ShadowLayer"),
                    .target(name:"Shapes"),
                    .target(name:"Typography"),
                    .target(name:"ShapeScheme"),
                    .target(name:"ContainerScheme"),
                    .target(name:"TypographyScheme"),
                    .target(name:"ColorScheme"),
                    .target(name:"Math")
            ],
                path: "components/Buttons/",
                exclude: [
                "src/ButtonThemer",
                "src/ColorThemer",
                "src/ShapeThemer",
                "src/Theming",
                "src/TypographyThemer",
            ],
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Elevation",
                dependencies: [
                    .target(name:"AvailabilityT"),
                    .target(name:"Color"),
                    .target(name:"Math")
            ],
                path: "components/Elevation/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Typography",
                dependencies: [
                    .target(name: "Application"),
                    .target(name: "Math")
            ],
                path: "components/Typography/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Math", 
                path: "components/private/Math/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Palettes", 
                path: "components/Palettes/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Ink",
                dependencies: [
                    .target(name: "AvailabilityT"),
                    .target(name: "Color"),
                    .target(name: "Math")
            ],
                path: "components/Ink/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Ripple",
                dependencies:[
                    .target(name:"AnimationTiming"),
                    .target(name:"AvailabilityT"),
                    .target(name:"Color"),
                    .target(name:"Math")
            ],
                path: "components/Ripple/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "ShadowElevations", 
                path: "components/ShadowElevations/",
                sources: [
                    "src",
            ],
                publicHeadersPath:"src"),
        .target(name: "ShadowLayer", 
                dependencies: [
                    .target(name:"ShadowElevations")
            ],
                path: "components/ShadowLayer/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Shapes",
                dependencies:[
                    .target(name:"ShadowLayer"),
                    .target(name:"Color"),
                    .target(name:"Math")
            ],
                path: "components/Shapes/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Color",
                dependencies: [
                    .target(name:"AvailabilityT")
            ],
                path: "components/private/Color/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src"),
        .target(name: "Application", 
                path: "components/private/Application/",
                sources: [
                    "src"
            ],
                publicHeadersPath:"src")
    ]
)
