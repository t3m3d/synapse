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
    if mode == "private" || mode == "tor" || mode == "i2p" || mode == "blackout" {
        emit mode
    }
    emit "shield"
}

// Policies use an explicit accessor instead of Krypton's environment-map
// primitive. Krypton 2.4.5's native macOS backend does not reliably return
// environment maps across function boundaries.
func privacyPolicyValue(policy, key) {
    let mode = privacyPolicy(policy)
    if key == "mode" { emit mode }

    if key == "route" {
        if mode == "tor" || mode == "blackout" { emit "tor" }
        if mode == "i2p" { emit "i2p" }
        emit "direct"
    }
    if key == "persistent" {
        if mode == "shield" { emit "1" }
        emit "0"
    }
    if key == "anonymity" {
        if mode == "tor" { emit "tor-context" }
        if mode == "i2p" { emit "i2p-context" }
        if mode == "blackout" { emit "maximum-isolation-goal" }
        emit "none"
    }
    if key == "telemetry" || key == "crashContent" ||
       key == "dnsPrefetch" || key == "linkPrefetch" ||
       key == "speculativeConnect" || key == "routeFallback" {
        emit "deny"
    }
    if key == "partitionCookies" || key == "partitionStorage" ||
       key == "partitionCache" || key == "httpsOnly" {
        emit "1"
    }
    if key == "trackingProtection" { emit "strict" }
    if key == "extensionAccess" {
        if mode == "shield" { emit "prompt" }
        emit "deny"
    }
    if key == "localNetwork" || key == "externalProtocols" {
        if mode == "tor" || mode == "i2p" || mode == "blackout" { emit "deny" }
        emit "prompt"
    }
    if key == "clearnet" {
        if mode == "i2p" { emit "deny" }
        emit "allow"
    }
    if key == "clipboard" {
        if mode == "blackout" { emit "deny" }
        emit "allow"
    }
    if key == "screenCapture" {
        if mode == "blackout" { emit "deny" }
        emit "prompt"
    }
    if key == "downloads" {
        if mode == "blackout" { emit "quarantine" }
        emit "allow"
    }
    if key == "printing" || key == "history" || key == "passwordStorage" ||
       key == "formAutofill" || key == "webrtc" {
        if mode == "blackout" { emit "deny" }
        emit "allow"
    }
    emit ""
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
    emit privacyPolicyValue(privacyPolicy(mode), "routeFallback") != "deny"
}

func privacyIsCertified(mode) {
    // Product modes are engineering policies, never government certification.
    emit "0"
}
