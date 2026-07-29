module synapse_privacy

func privacyModeFromLabel(label) {
    if label == "Private" { emit "private" }
    if label == "Tor" { emit "tor" }
    if label == "I2P" { emit "i2p" }
    if label == "Blackout" { emit "blackout" }
    emit "shield"
}

func privacyModeLabel(mode) {
    if mode == "private" { emit "Private" }
    if mode == "tor" { emit "Tor" }
    if mode == "i2p" { emit "I2P" }
    if mode == "blackout" { emit "Blackout" }
    emit "Shield"
}

func privacyPolicy(mode) {
    let policy = envNew()
    policy = envSet(policy, "mode", mode)
    policy = envSet(policy, "route", "direct")
    policy = envSet(policy, "persistent", "1")
    policy = envSet(policy, "anonymity", "none")
    policy = envSet(policy, "telemetry", "deny")
    policy = envSet(policy, "crashContent", "deny")
    policy = envSet(policy, "partitionCookies", "1")
    policy = envSet(policy, "partitionStorage", "1")
    policy = envSet(policy, "partitionCache", "1")
    policy = envSet(policy, "trackingProtection", "strict")
    policy = envSet(policy, "httpsOnly", "1")
    policy = envSet(policy, "dnsPrefetch", "deny")
    policy = envSet(policy, "linkPrefetch", "deny")
    policy = envSet(policy, "speculativeConnect", "deny")
    policy = envSet(policy, "extensionAccess", "prompt")
    policy = envSet(policy, "routeFallback", "deny")
    policy = envSet(policy, "clipboard", "allow")
    policy = envSet(policy, "screenCapture", "prompt")
    policy = envSet(policy, "externalProtocols", "prompt")
    policy = envSet(policy, "localNetwork", "prompt")
    policy = envSet(policy, "downloads", "allow")
    policy = envSet(policy, "printing", "allow")

    if mode == "private" {
        policy = envSet(policy, "persistent", "0")
        policy = envSet(policy, "extensionAccess", "deny")
    }

    if mode == "tor" {
        policy = envSet(policy, "route", "tor")
        policy = envSet(policy, "persistent", "0")
        policy = envSet(policy, "anonymity", "tor-context")
        policy = envSet(policy, "extensionAccess", "deny")
        policy = envSet(policy, "localNetwork", "deny")
        policy = envSet(policy, "externalProtocols", "deny")
    }

    if mode == "i2p" {
        policy = envSet(policy, "route", "i2p")
        policy = envSet(policy, "persistent", "0")
        policy = envSet(policy, "anonymity", "i2p-context")
        policy = envSet(policy, "extensionAccess", "deny")
        policy = envSet(policy, "localNetwork", "deny")
        policy = envSet(policy, "clearnet", "deny")
        policy = envSet(policy, "externalProtocols", "deny")
    }

    if mode == "blackout" {
        policy = envSet(policy, "route", "tor")
        policy = envSet(policy, "persistent", "0")
        policy = envSet(policy, "anonymity", "maximum-isolation-goal")
        policy = envSet(policy, "extensionAccess", "deny")
        policy = envSet(policy, "localNetwork", "deny")
        policy = envSet(policy, "externalProtocols", "deny")
        policy = envSet(policy, "clipboard", "deny")
        policy = envSet(policy, "screenCapture", "deny")
        policy = envSet(policy, "downloads", "quarantine")
        policy = envSet(policy, "printing", "deny")
        policy = envSet(policy, "history", "deny")
        policy = envSet(policy, "passwordStorage", "deny")
        policy = envSet(policy, "formAutofill", "deny")
        policy = envSet(policy, "webrtc", "deny")
    }

    emit policy
}

func privacySummary(mode) {
    if mode == "blackout" {
        emit "Tor-only route | ephemeral profile | extensions and data egress denied"
    }
    if mode == "tor" {
        emit "Tor route | ephemeral isolated state | no direct fallback"
    }
    if mode == "i2p" {
        emit "I2P route | isolated state | clearnet blocked"
    }
    if mode == "private" {
        emit "Direct route | ephemeral partitioned state | no anonymity claim"
    }
    emit "Direct route | partitioned state | strict tracking protection"
}

func privacyAllowsFallback(mode) {
    emit envGet(privacyPolicy(mode), "routeFallback") != "deny"
}

func privacyIsCertified(mode) {
    // Product modes are engineering policies, never government certification.
    emit "0"
}
