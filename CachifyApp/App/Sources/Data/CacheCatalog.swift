import SwiftUI

let targetStyles: [String: TargetStyle] = [
    "xcode": TargetStyle(color: .blue, icon: "hammer.fill"),
    "ios-simulator": TargetStyle(color: .cyan, icon: "iphone.gen3"),
    "node": TargetStyle(color: .green, icon: "shippingbox.fill"),
    "python": TargetStyle(color: .orange, icon: "chevron.left.forwardslash.chevron.right"),
    "android-studio": TargetStyle(color: .mint, icon: "ladybug.fill"),
    "build-tools": TargetStyle(color: .pink, icon: "wrench.and.screwdriver.fill"),
    "docker": TargetStyle(color: .teal, icon: "shippingbox.circle.fill"),
    "java-kotlin": TargetStyle(color: .indigo, icon: "cup.and.saucer.fill"),
    "go-rust": TargetStyle(color: .brown, icon: "gearshape.2.fill"),
    "dotnet": TargetStyle(color: .purple, icon: "cube.box.fill"),
    "editors": TargetStyle(color: .yellow, icon: "pencil.and.outline"),
    "design-tools": TargetStyle(color: .red, icon: "paintpalette.fill"),
    "unity": TargetStyle(color: .gray, icon: "gamecontroller.fill"),
    "browsers": TargetStyle(color: .blue, icon: "globe")
]

let allTargets: [CacheTarget] = [
    CacheTarget(
        id: "xcode",
        name: "Xcode build cache",
        details: "DerivedData, module caches, and Xcode temp caches",
        patterns: [
            "~/Library/Developer/Xcode/DerivedData",
            "~/Library/Developer/Xcode/ModuleCache.noindex",
            "~/Library/Caches/com.apple.dt.Xcode"
        ]
    ),
    CacheTarget(
        id: "ios-simulator",
        name: "iOS Simulator cache",
        details: "CoreSimulator caches and per-device runtime caches",
        patterns: [
            "~/Library/Developer/CoreSimulator/Caches",
            "~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches"
        ]
    ),
    CacheTarget(
        id: "node",
        name: "Node.js package managers",
        details: "npm, Yarn, pnpm, and bun caches",
        patterns: [
            "~/.npm/_cacache",
            "~/Library/Caches/npm",
            "~/.cache/npm",
            "~/Library/Caches/Yarn",
            "~/.cache/yarn",
            "~/.pnpm-store",
            "~/.yarn/berry/cache",
            "~/.bun/install/cache"
        ]
    ),
    CacheTarget(
        id: "python",
        name: "Python tooling",
        details: "pip, Poetry, PDM, and uv caches",
        patterns: [
            "~/Library/Caches/pip",
            "~/.cache/pip",
            "~/.cache/pypoetry",
            "~/.cache/pdm",
            "~/.cache/uv"
        ]
    ),
    CacheTarget(
        id: "android-studio",
        name: "Android Studio",
        details: "Android Studio system and cache directories",
        patterns: [
            "~/Library/Caches/Google/AndroidStudio*",
            "~/Library/Logs/Google/AndroidStudio*",
            "~/Library/Application Support/Google/AndroidStudio*/caches",
            "~/Library/Application Support/Google/AndroidStudio*/system"
        ]
    ),
    CacheTarget(
        id: "build-tools",
        name: "General build tools",
        details: "CocoaPods, Carthage, and Homebrew download caches",
        patterns: [
            "~/Library/Caches/CocoaPods",
            "~/Library/Caches/org.carthage.CarthageKit",
            "~/Library/Caches/Homebrew"
        ]
    ),
    CacheTarget(
        id: "docker",
        name: "Docker caches",
        details: "Docker Desktop caches, logs, and temporary build data",
        patterns: [
            "~/Library/Caches/com.docker.docker",
            "~/Library/Containers/com.docker.docker/Data/log",
            "~/Library/Containers/com.docker.docker/Data/cache",
            "~/Library/Group Containers/group.com.docker/cache"
        ]
    ),
    CacheTarget(
        id: "java-kotlin",
        name: "Java/Kotlin build caches",
        details: "Gradle, Maven, Ivy, and Coursier downloaded artifacts",
        patterns: [
            "~/.gradle/caches",
            "~/.gradle/wrapper/dists",
            "~/Library/Caches/gradle",
            "~/.m2/repository",
            "~/.ivy2/cache",
            "~/Library/Caches/Coursier"
        ]
    ),
    CacheTarget(
        id: "go-rust",
        name: "Go and Rust caches",
        details: "Go build/module cache and Cargo registry/git caches",
        patterns: [
            "~/.cache/go-build",
            "~/Library/Caches/go-build",
            "~/go/pkg/mod/cache",
            "~/.cargo/registry/cache",
            "~/.cargo/git/db"
        ]
    ),
    CacheTarget(
        id: "dotnet",
        name: ".NET / NuGet",
        details: "NuGet package and temporary cache folders",
        patterns: [
            "~/.nuget/packages",
            "~/Library/Caches/NuGet",
            "~/Library/Caches/NuGetScratch"
        ]
    ),
    CacheTarget(
        id: "editors",
        name: "Editors and IDEs",
        details: "VS Code, Cursor, and JetBrains cache folders",
        patterns: [
            "~/Library/Application Support/Code/Cache",
            "~/Library/Application Support/Code/CachedData",
            "~/Library/Application Support/Code/Service Worker/CacheStorage",
            "~/Library/Application Support/Cursor/Cache",
            "~/Library/Application Support/Cursor/CachedData",
            "~/Library/Caches/JetBrains",
            "~/Library/Logs/JetBrains",
            "~/Library/Application Support/JetBrains/*/caches"
        ]
    ),
    CacheTarget(
        id: "design-tools",
        name: "Design tools",
        details: "Figma and Adobe media/cache files",
        patterns: [
            "~/Library/Caches/Figma",
            "~/Library/Application Support/Figma/Cache",
            "~/Library/Application Support/Figma/Code Cache",
            "~/Library/Application Support/Figma/GPUCache",
            "~/Library/Application Support/Figma/Service Worker/CacheStorage",
            "~/Library/Caches/Adobe",
            "~/Library/Application Support/Adobe/Common/Media Cache",
            "~/Library/Application Support/Adobe/Common/Media Cache Files"
        ]
    ),
    CacheTarget(
        id: "unity",
        name: "Unity",
        details: "Unity editor caches and package cache folders",
        patterns: [
            "~/Library/Unity/cache",
            "~/Library/Caches/com.unity3d.UnityEditor",
            "~/Library/Application Support/Unity/Asset Store-5.x"
        ]
    ),
    CacheTarget(
        id: "browsers",
        name: "Browser caches",
        details: "Chrome and Firefox cache paths used by local web/dev workflows",
        patterns: [
            "~/Library/Caches/Google/Chrome",
            "~/Library/Application Support/Google/Chrome/Default/Code Cache",
            "~/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage",
            "~/Library/Caches/Firefox",
            "~/Library/Caches/Mozilla"
        ]
    )
]
