/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Synapse hardened defaults.
//
// These are defaults, not the Blackout contract. The distribution policy
// locks the no-telemetry/no-studies floor while allowing normal users to
// relax compatibility-sensitive browser protections if they deliberately
// choose to do so.

// Data collection, experiments, crash submission, and new-tab telemetry.
pref("toolkit.telemetry.enabled", false);
pref("toolkit.telemetry.unified", false);
pref("toolkit.telemetry.archive.enabled", false);
pref("toolkit.telemetry.server", "");
pref("toolkit.telemetry.newProfilePing.enabled", false);
pref("toolkit.telemetry.shutdownPingSender.enabled", false);
pref("toolkit.telemetry.shutdownPingSender.enabledFirstSession", false);
pref("toolkit.telemetry.firstShutdownPing.enabled", false);
pref("toolkit.telemetry.updatePing.enabled", false);
pref("toolkit.telemetry.bhrPing.enabled", false);
pref("datareporting.healthreport.uploadEnabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("datareporting.usage.uploadEnabled", false);
pref("app.normandy.enabled", false);
pref("app.normandy.api_url", "");
pref("app.shield.optoutstudies.enabled", false);
pref("browser.crashReports.unsubmittedCheck.enabled", false);
pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
pref("browser.tabs.crashReporting.sendReport", false);
pref("browser.newtabpage.activity-stream.telemetry", false);
pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
pref("browser.newtabpage.activity-stream.telemetry.privatePing.enabled", false);

// Sponsored and remotely suggested content.
pref("browser.newtabpage.activity-stream.showSponsored", false);
pref("browser.newtabpage.activity-stream.system.showSponsored", false);
pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
pref("browser.urlbar.quicksuggest.enabled", false);
pref("browser.urlbar.quicksuggest.online.enabled", false);
pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
pref("browser.urlbar.suggest.trending", false);
pref("browser.urlbar.suggest.weather", false);
pref("browser.urlbar.suggest.yelp", false);
pref("browser.search.suggest.enabled", false);
pref("browser.urlbar.suggest.searches", false);

// Enhanced Tracking Protection, partitioning, and bounce/query defenses.
pref("browser.contentblocking.category", "strict");
pref("network.cookie.cookieBehavior", 5);
pref("network.cookie.cookieBehavior.pbmode", 5);
pref("privacy.trackingprotection.enabled", true);
pref("privacy.trackingprotection.pbmode.enabled", true);
pref("privacy.trackingprotection.fingerprinting.enabled", true);
pref("privacy.trackingprotection.cryptomining.enabled", true);
pref("privacy.trackingprotection.socialtracking.enabled", true);
pref("privacy.trackingprotection.emailtracking.enabled", true);
pref("privacy.trackingprotection.emailtracking.pbmode.enabled", true);
pref("privacy.fingerprintingProtection", true);
pref("privacy.fingerprintingProtection.pbmode", true);
pref("privacy.partition.serviceWorkers", true);
pref("privacy.partition.network_state.connection_with_proxy", true);
pref("privacy.query_stripping.enabled", true);
pref("privacy.query_stripping.enabled.pbmode", true);
pref("privacy.query_stripping.strip_on_share.enabled", true);
pref("privacy.bounceTrackingProtection.mode", 1);

// Upgrade navigations and mixed content.
pref("dom.security.https_only_mode", true);
pref("dom.security.https_only_mode_pbm", true);
pref("security.mixed_content.block_active_content", true);

// Do not contact destinations before an explicit navigation.
pref("network.dns.disablePrefetch", true);
pref("network.dns.disablePrefetchFromHTTPS", true);
pref("network.prefetch-next", false);
pref("network.http.speculative-parallel-limit", 0);
pref("browser.urlbar.speculativeConnect.enabled", false);
pref("browser.places.speculativeConnect.enabled", false);
pref("network.connectivity-service.enabled", false);
pref("network.captive-portal-service.enabled", false);

// Avoid exposing host addresses through WebRTC while keeping WebRTC usable.
pref("media.peerconnection.ice.default_address_only", true);
pref("media.peerconnection.ice.no_host", true);
pref("media.peerconnection.ice.proxy_only_if_behind_proxy", true);

// Enforce Gecko's Local Network Access checks. Blackout adds stricter values.
pref("network.lna.enabled", true);
pref("network.lna.blocking", true);
pref("network.lna.block_trackers", true);
pref("network.lna.allow_top_level_navigation", false);
pref("network.lna.websocket.enabled", true);
pref("network.lna.skip-domains", "");

// Reduce cross-site referrer detail.
pref("network.http.referer.XOriginTrimmingPolicy", 2);
pref("network.http.referer.disallowCrossSiteRelaxingDefault", true);
pref("network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation", true);

