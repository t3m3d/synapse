module synapse_extensions

func extensionFamily(path) {
    if endsWith(path, ".xpi") { emit "webextension" }
    emit "unsupported"
}

func extensionManifestName(family) {
    if family == "webextension" { emit "manifest.json" }
    emit ""
}

func extensionPermissionRisk(manifestText) {
    if contains(manifestText, "nativeMessaging") ||
       contains(manifestText, "\"proxy\"") ||
       contains(manifestText, "<all_urls>") {
        emit "high"
    }
    if contains(manifestText, "\"downloads\"") ||
       contains(manifestText, "\"history\"") ||
       contains(manifestText, "\"cookies\"") {
        emit "elevated"
    }
    emit "normal"
}

func extensionInstallDecision(family, signedPackage, developerProfile) {
    if family != "webextension" { emit "deny:unsupported-package" }
    if signedPackage == "1" { emit "allow:signed-webextension" }
    if developerProfile == "1" { emit "allow:isolated-developer-profile" }
    emit "deny:signature-required"
}

func extensionContextDefault(mode) {
    if mode == "shield" { emit "prompt" }
    emit "deny"
}

func synapseExtensionRuntimeAvailable() {
    // Reserved for later. First releases preserve Firefox WebExtensions.
    emit "0"
}
