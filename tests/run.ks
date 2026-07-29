#!/usr/bin/env kr

import "../src/core/privacy.k"
import "../src/core/navigation.k"
import "../src/core/extensions.k"
import "../src/bridge/protocol.k"

func expect(actual, expected, name) {
    if actual != expected {
        printErr("FAIL " + name + ": expected " + expected + ", got " + actual)
        exit(1)
    }
    emit "1"
}

just run {
    print("Running privacy contracts...")
    let shield = privacyPolicy("shield")
    expect(privacyPolicyValue(shield, "route"), "direct", "shield route")
    expect(privacyPolicyValue(shield, "telemetry"), "deny", "telemetry disabled")
    expect(privacyPolicyValue(shield, "partitionStorage"), "1", "storage partitioned")

    let tor = privacyPolicy("tor")
    expect(privacyPolicyValue(tor, "route"), "tor", "tor route")
    expect(privacyPolicyValue(tor, "routeFallback"), "deny", "tor fallback denied")
    expect(privacyPolicyValue(tor, "persistent"), "0", "tor ephemeral")

    let i2p = privacyPolicy("i2p")
    expect(privacyPolicyValue(i2p, "clearnet"), "deny", "i2p clearnet denied")

    let blackout = privacyPolicy("blackout")
    expect(privacyPolicyValue(blackout, "route"), "tor", "blackout route")
    expect(privacyPolicyValue(blackout, "clipboard"), "deny", "blackout clipboard")
    expect(privacyPolicyValue(blackout, "extensionAccess"), "deny", "blackout extensions")
    expect(privacyPolicyValue(blackout, "downloads"), "quarantine", "blackout downloads")
    expect(privacyIsCertified("blackout"), "0", "no false certification")

    print("Running navigation contracts...")
    expect(normalizeNavigation("example.com"), "https://example.com", "host normalization")
    expect(normalizeNavigation("javascript:alert(1)"), "synapse://blocked", "unsafe scheme")
    expect(normalizeNavigation("private search"), "synapse://search?q=private search", "search")

    print("Running extension contracts...")
    expect(extensionFamily("privacy.xpi"), "webextension", "Firefox extension")
    expect(extensionFamily("notes.sxp"), "unsupported", "future Synapse extension")
    expect(
        extensionInstallDecision("webextension", "0", "0"),
        "deny:signature-required",
        "unsigned release extension"
    )
    expect(
        extensionInstallDecision("webextension", "0", "1"),
        "allow:isolated-developer-profile",
        "developer extension"
    )
    expect(synapseExtensionRuntimeAvailable(), "0", "Synapse runtime deferred")

    print("Running bridge contracts...")
    let command = bridgeNavigate("req-1", "tab-1", "https://example.com")
    if !contains(command, "\"type\":\"tab.navigate\"") {
        printErr("FAIL bridge navigate command")
        exit(1)
    }

    print("Synapse core contracts passed")
}
