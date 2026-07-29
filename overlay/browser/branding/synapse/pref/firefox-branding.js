// SPDX-License-Identifier: MPL-2.0

// Synapse never falls back to another vendor's update, welcome, or support
// service. Update endpoints stay empty until a signed Synapse service exists.
pref("startup.homepage_override_url", "");
pref("startup.homepage_welcome_url", "");
pref("startup.homepage_welcome_url.additional", "");
pref("app.update.url.manual", "");
pref("app.update.url.details", "");
pref("app.update.interval", 86400);
pref("app.update.promptWaitTime", 86400);
pref("app.update.checkInstallTime.days", 2);
pref("app.update.badgeWaitTime", 0);
pref("devtools.selfxss.count", 5);
