#!/usr/bin/env kr
// Synapse's first native I2P settings surface for macOS.
import "k:okui"
import "k:proc_ex"

func settingsShellQuote(value) {
    let singleQuote = fromCharCode(39)
    let escapedQuote = singleQuote + fromCharCode(92) + singleQuote + singleQuote
    emit singleQuote + replace(value, singleQuote, escapedQuote) + singleQuote
}

func settingsIdentity(label) {
    if label == "Work" { emit "work" }
    if label == "School" { emit "school" }
    if label == "Creator" { emit "creator" }
    if label == "Second account" { emit "second-account" }
    emit "personal"
}

func settingsCommand(action, identity) {
    if action == "setup" { emit "i2p-setup-check" }
    if action == "install-guide" { emit "i2p-install-guide" }
    if action == "status" { emit "i2p-router-status" }
    if action == "start" { emit "i2p-router-start" }
    if action == "stop" { emit "i2p-router-stop" }
    if action == "open" {
        emit "i2p-open " + settingsShellQuote(identity) + " 'home'"
    }
    if action == "addressbook" {
        emit "i2p-open " + settingsShellQuote(identity) + " 'subscriptions'"
    }
    emit ""
}

func settingsCommandSucceeded(output) {
    emit contains(output, "__SYNAPSE_EXIT__0")
}

func settingsCommandOutput(output) {
    let marker = indexOf(output, "\n__SYNAPSE_EXIT__")
    if marker >= 0 { emit substring(output, 0, marker) }
    emit output
}

func runSettingsTool(action, identity) {
    let workspace = exec("printf '%s' \"$SYNAPSE_WORKSPACE_ROOT\"")
    if len(workspace) == 0 { emit "Synapse workspace was not provided by its launcher." }
    let command = settingsCommand(action, identity)
    if len(command) == 0 { emit "Unsupported I2P settings action." }
    let script = workspace + "/tools/synapse-macos.sh"
    let invocation = settingsShellQuote(script) + " " + command + " 2>&1; result=$?; echo __SYNAPSE_EXIT__$result"
    emit exec(invocation)
}

func settingsBind(control, identity, details, status) {
    doSet(control, "identity", identity)
    doSet(control, "details", details)
    doSet(control, "status", status)
    emit done()
}

func onSetupCheck(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    doText(status, "Checking Java, I2P+ installation, and proxy…")
    let output = runSettingsTool("setup", "personal")
    doTextBox(details, settingsCommandOutput(output))
    if settingsCommandSucceeded(output) {
        doText(status, "Setup check complete. Install any missing prerequisite, then start and bootstrap I2P+.")
    } else {
        doText(status, "Setup check could not run; inspect the output below.")
    }
    emit done()
}

func onInstallGuide(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    let output = runSettingsTool("install-guide", "personal")
    doTextBox(details, settingsCommandOutput(output))
    if settingsCommandSucceeded(output) {
        doText(status, "Opened official I2P+ downloads. Install Java 8+ first if it is missing.")
    } else {
        doText(status, "Could not open the I2P+ downloads page.")
    }
    emit done()
}

func onRouterRefresh(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    doText(status, "Checking the installed I2P+ router…")
    let output = runSettingsTool("status", "personal")
    doTextBox(details, settingsCommandOutput(output))
    if settingsCommandSucceeded(output) {
        doText(status, "Router command and local proxy status refreshed. A listening proxy does not prove bootstrap.")
    } else {
        doText(status, "Could not query the router; check that I2P+ is installed and its router script is accessible.")
    }
    emit done()
}

func onRouterStart(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    doText(status, "Requesting user-level router start…")
    let output = runSettingsTool("start", "personal")
    doTextBox(details, settingsCommandOutput(output))
    if settingsCommandSucceeded(output) {
        doText(status, "Start requested. I2P browsing stays blocked until the local proxy is listening.")
    } else {
        doText(status, "Router start failed; inspect the command output below.")
    }
    emit done()
}

func onRouterStop(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    doText(status, "Requesting graceful router shutdown…")
    let output = runSettingsTool("stop", "personal")
    doTextBox(details, settingsCommandOutput(output))
    if settingsCommandSucceeded(output) {
        doText(status, "Graceful shutdown requested. Existing I2P browser windows may lose connectivity.")
    } else {
        doText(status, "Graceful shutdown failed; inspect the command output below.")
    }
    emit done()
}

func onOpenI2pBrowser(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    let identity = settingsIdentity(choice(get(sender, "identity")))
    let output = runSettingsTool("open", identity)
    doTextBox(details, settingsCommandOutput(output))
    if settingsCommandSucceeded(output) && contains(output, "started through") {
        doText(status, "I2P browser opened for " + identity + ".")
    } else {
        doText(status, "Could not open I2P browser; check router/proxy status below.")
    }
    emit done()
}

func onOpenAddressBook(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    let identity = settingsIdentity(choice(get(sender, "identity")))
    let output = runSettingsTool("addressbook", identity)
    doTextBox(details, settingsCommandOutput(output))
    if settingsCommandSucceeded(output) && contains(output, "started through") {
        doText(status, "SusiDNS opened. Adding its optional feed is a separate trust decision.")
    } else {
        doText(status, "Could not open SusiDNS; check router/proxy status below.")
    }
    emit done()
}

just run {
    app("Synapse I2P Settings")
    let win = window("Synapse Settings · I2P Network", 680, 470)
    minSize(win, 620, 430)
    doTransparentTitlebar(win)

    let brand = label(win, "I2P Network", area(26, 424, 300, 30))
    doFont(brand, fontFamily(mono(17), "Segoe UI Semibold"))
    label(win, "Manage your local I2P+ router and isolated browser profile.", area(26, 392, 620, 24))

    label(win, "Router", area(26, 350, 100, 24))
    label(win, "I2P+ user router · proxy 127.0.0.1:4444", area(112, 350, 510, 24))
    let setup = button(win, "Setup check", area(26, 306, 120, 34))
    let install = button(win, "Get I2P+", area(158, 306, 100, 34))
    let refresh = button(win, "Refresh status", area(270, 306, 130, 34))
    let start = button(win, "Start router", area(412, 306, 120, 34))
    let stop = button(win, "Graceful stop", area(544, 306, 120, 34))

    label(win, "Automatic startup: Off · router starts only when you choose Start", area(26, 270, 620, 24))
    label(win, "I2P browser profile", area(26, 230, 160, 24))
    let identity = choices(win, area(184, 225, 180, 150))
    doAddChoice(identity, "Personal")
    doAddChoice(identity, "Work")
    doAddChoice(identity, "School")
    doAddChoice(identity, "Creator")
    doAddChoice(identity, "Second account")
    doChoose(identity, 0)
    let open = button(win, "Open I2P Browser", area(380, 222, 150, 34))
    let addressbook = button(win, "Address Book", area(542, 222, 120, 34))

    let details = textBox(win, area(26, 66, 630, 140))
    doEditable(details, 0)
    doTextBox(details, "Router status has not been checked yet.\r\n\r\nStart is a user-level action. Synapse does not install a privileged launchd service or enable login autostart. A TCP listener is not proof that the router has bootstrapped.")
    let status = label(win, "Automatic startup is off.", area(26, 24, 630, 24))

    settingsBind(setup, identity, details, status)
    settingsBind(install, identity, details, status)
    settingsBind(refresh, identity, details, status)
    settingsBind(start, identity, details, status)
    settingsBind(stop, identity, details, status)
    settingsBind(open, identity, details, status)
    settingsBind(addressbook, identity, details, status)
    doClick(setup, "synapse.i2p.settings.setup", funcptr(onSetupCheck))
    doClick(install, "synapse.i2p.settings.install", funcptr(onInstallGuide))
    doClick(refresh, "synapse.i2p.settings.refresh", funcptr(onRouterRefresh))
    doClick(start, "synapse.i2p.settings.start", funcptr(onRouterStart))
    doClick(stop, "synapse.i2p.settings.stop", funcptr(onRouterStop))
    doClick(open, "synapse.i2p.settings.open", funcptr(onOpenI2pBrowser))
    doClick(addressbook, "synapse.i2p.settings.addressbook", funcptr(onOpenAddressBook))

    doShow(win)
    doRun()
}
