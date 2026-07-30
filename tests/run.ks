#!/usr/bin/env kr

import "../src/core/privacy.k"
import "../src/core/i2p.k"
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
    expect(privacyPolicyValue(i2p, "route"), "i2p", "i2p route")
    expect(privacyPolicyValue(i2p, "routeFallback"), "deny", "i2p fallback denied")
    expect(privacyPolicyValue(i2p, "persistent"), "1", "i2p profile is durable")
    expect(privacyPolicyValue(i2p, "webrtc"), "deny", "i2p WebRTC denied")
    expect(privacyPolicyValue(i2p, "httpsOnly"), "0", "i2p permits HTTP services")
    expect(privacyPolicyValue(i2p, "extensionAccess"), "install-disabled", "i2p installs disabled")
    expect(privacyPolicyValue(i2p, "externalProtocols"), "blocked-by-default", "i2p external protocols")
    expect(
        privacyPolicyValue(i2p, "clearnet"),
        "i2p-outproxy-only",
        "i2p clearnet requires router outproxy"
    )

    print("Running I2P+ profile contracts...")
    expect(i2pProxyHost(), "127.0.0.1", "i2p proxy host")
    expect(i2pProxyPort(), "4444", "i2p proxy port")
    expect(i2pProfileFolder("personal"), "synapse-i2p-personal", "i2p profile folder")
    let i2pPrefs = i2pUserPrefs()
    if !contains(i2pPrefs, "network.proxy.type\", 1") ||
       !contains(i2pPrefs, "network.proxy.http\", \"127.0.0.1\"") ||
       !contains(i2pPrefs, "network.proxy.http_port\", 4444") ||
       !contains(i2pPrefs, "network.proxy.ssl\", \"127.0.0.1\"") ||
       !contains(i2pPrefs, "network.proxy.ssl_port\", 4444") ||
       !contains(i2pPrefs, "network.proxy.socks\", \"\"") ||
       !contains(i2pPrefs, "network.proxy.socks_port\", 0") ||
       !contains(i2pPrefs, "network.proxy.no_proxies_on\", \"127.0.0.1\"") ||
       !contains(i2pPrefs, "network.proxy.allow_hijacking_localhost\", true") ||
       !contains(i2pPrefs, "network.proxy.testing_localhost_is_secure_when_hijacked\", false") ||
       !contains(i2pPrefs, "network.proxy.failover_direct\", false") ||
       !contains(i2pPrefs, "network.proxy.allow_bypass\", false") ||
       !contains(i2pPrefs, "network.dns.disabled\", true") ||
       !contains(i2pPrefs, "network.trr.mode\", 5") ||
       !contains(i2pPrefs, "network.http.http3.enable\", false") ||
       !contains(i2pPrefs, "network.webtransport.enabled\", false") ||
       !contains(i2pPrefs, "media.peerconnection.enabled\", false") ||
       !contains(i2pPrefs, "dom.security.https_only_mode\", false") ||
       !contains(i2pPrefs, "keyword.enabled\", false") ||
       !contains(i2pPrefs, "browser.fixup.domainsuffixwhitelist.i2p\", true") ||
       !contains(i2pPrefs, "network.protocol-handler.external-default\", false") ||
       !contains(i2pPrefs, "xpinstall.enabled\", false") {
        printErr("FAIL I2P+ user.js is missing a fail-closed preference")
        exit(1)
    }

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
