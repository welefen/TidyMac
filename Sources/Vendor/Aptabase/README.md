# Aptabase Swift SDK (vendored)

Unmodified source files from the official Aptabase Swift SDK:

- Repository: https://github.com/aptabase/aptabase-swift
- Version: 0.4.0 (`sdkVersion` reported by the SDK)
- License: MIT (see `LICENSE`)

Only the SDK's `Sources/Aptabase/` Swift sources are vendored so the plain
`swiftc` build script can compile them without a Swift Package Manager setup.
They must stay identical to upstream. App-specific integration lives in
`Sources/Core/AptabaseAnalyticsProvider.swift`.
