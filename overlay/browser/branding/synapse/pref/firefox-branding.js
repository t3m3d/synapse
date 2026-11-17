// SPDX-License-Identifier: MPL-2.0

// Synapse never falls back to another vendor's update, welcome, or support
// service. Update endpoints stay empty until a signed Synapse service exists.
pref("startup.homepage_override_url", "");
pref("startup.homepage_welcome_url", "");
pref("startup.homepage_welcome_url.additional", "");
pref("app.update.url.manual", "");
pref("app.update.url.details", "");
pref("app.update.auto", false);
pref("app.update.interval", 86400);
pref("app.update.promptWaitTime", 86400);
pref("app.update.checkInstallTime.days", 2);
pref("app.update.badgeWaitTime", 0);
pref("devtools.selfxss.count", 5);

// Gecko loads this file after firefox.js, so the Synapse homepage takes
// precedence over the upstream default while remaining user-configurable.
pref("browser.startup.page", 1);
pref("browser.startup.homepage", "https://krypton-lang.org/s.html");
pref("browser.startup.firstrunSkipsHomepage", false);
