// Synapse Blackout profile template.
//
// This template is deliberately offline: SOCKS port 0 is invalid. The launcher
// must materialize a fresh profile, verify Tor and the Blackout policy, replace
// the port with the probed loopback listener, then attest the runtime contract.
// Until that pipeline exists, Synapse must refuse to launch Blackout.

// Permanent private browsing and no durable browsing records.
user_pref("browser.privatebrowsing.autostart", true);
user_pref("places.history.enabled", false);
user_pref("browser.formfill.enable", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.sessionstore.max_tabs_undo", 0);
user_pref("browser.sessionstore.max_windows_undo", 0);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.download.manager.addToRecentDocs", false);
user_pref("browser.download.useDownloadDir", false);
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.history", true);
user_pref("privacy.clearOnShutdown.sessions", true);
user_pref("privacy.clearOnShutdown.siteSettings", true);
user_pref("privacy.clearOnShutdown_v2.cache", true);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", true);
user_pref("privacy.clearOnShutdown_v2.historyFormDataAndDownloads", true);
user_pref("privacy.clearOnShutdown_v2.siteSettings", true);

// Disable credentials, autofill, capture, WebRTC, and printing.
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("media.peerconnection.enabled", false);
user_pref("media.navigator.enabled", false);
user_pref("media.getusermedia.screensharing.enabled", false);
user_pref("print.enabled", false);

// Strong fingerprinting resistance. Expect site breakage.
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);
user_pref("privacy.fingerprintingProtection.remoteOverrides.enabled", false);

// Fail-closed Tor route. Port 0 keeps this template offline by construction.
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 0);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks5_remote_dns", true);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.proxy.no_proxies_on", "");
user_pref("network.proxy.allow_hijacking_localhost", true);
user_pref("network.proxy.allow_bypass", false);
user_pref("network.proxy.system_wpad", false);
user_pref("network.trr.mode", 5);

// Do not probe the network or bypass Local Network Access checks.
user_pref("network.connectivity-service.enabled", false);
user_pref("network.captive-portal-service.enabled", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.dns.disablePrefetchFromHTTPS", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("browser.places.speculativeConnect.enabled", false);
user_pref("network.lna.enabled", true);
user_pref("network.lna.blocking", true);
user_pref("network.lna.block_trackers", true);
user_pref("network.lna.allow_top_level_navigation", false);
user_pref("network.lna.websocket.enabled", true);
user_pref("network.lna.local-network-to-localhost.skip-checks", false);
user_pref("network.lna.defer_https_check", false);
user_pref("network.lna.skip-domains", "");

// Block handoff to system protocol handlers.
user_pref("network.protocol-handler.external-default", false);
user_pref("network.protocol-handler.warn-external-default", true);
user_pref("network.protocol-handler.external.mailto", false);

// HTTPS-only, except HTTP onion services whose authentication is provided by Tor.
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_pbm", true);
user_pref("dom.security.https_only_mode.upgrade_local", true);
user_pref("dom.security.https_only_mode.upgrade_onion", false);

