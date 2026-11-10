#!/usr/bin/env kr
// Synapse's first native I2P settings surface for macOS.
import "k:okui"

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

// Strip surrounding line breaks only: controller output is indented, so blank
// space inside the body has to survive.
func settingsTrimLines(value) {
    let lo = 0
    let hi = len(value)
    while lo < hi {
        let c = toInt(charCode(substring(value, lo, lo + 1)))
        if c == 10 || c == 13 { lo += 1 } else { break }
    }
    while hi > lo {
        let c = toInt(charCode(substring(value, hi - 1, hi)))
        if c == 10 || c == 13 { hi -= 1 } else { break }
    }
    emit substring(value, lo, hi)
}

// The bridge hands back "<exit code>\n<output>". The code is the controller's
// real status from shellRun, not a sentinel embedded in its stdout.
func settingsCommandSucceeded(result) {
    emit getLine(result, 0) == "0"
}

func settingsCommandOutput(result) {
    let code = getLine(result, 0)
    emit settingsTrimLines(substring(result, len(code) + 1, len(result)))
}

func settingsController() {
    let binary = bundledExecutable("synapse-macos")
    let key = bundledResource("i2p-component-public.pem")
    if len(binary) > 0 && len(key) > 0 {
        let parent = settingsTrimLines(exec("/usr/bin/dirname " + settingsShellQuote(binary)))
        let browser = settingsTrimLines(exec("cd " + settingsShellQuote(parent + "/../../../../..") +
            " && /bin/pwd -P"))
        if len(browser) == 0 { emit "" }
        emit "SYNAPSE_BROWSER_APP=" + settingsShellQuote(browser) +
            " SYNAPSE_I2P_COMPONENT_KEY=" + settingsShellQuote(key) + " " + settingsShellQuote(binary)
    }
    let workspace = settingsTrimLines(exec("printf '%s' \"$SYNAPSE_WORKSPACE_ROOT\""))
    if len(workspace) == 0 { emit "" }
    emit settingsShellQuote(workspace + "/tools/synapse-macos.sh")
}

func runSettingsTool(action, identity) {
    let controller = settingsController()
    if len(controller) == 0 { emit "1\nSynapse I2P controller is unavailable." }
    let command = settingsCommand(action, identity)
    if len(command) == 0 { emit "1\nUnsupported I2P settings action." }
    // shellRun waits for the controller and returns its real exit status, while
    // stdout and stderr are captured through a temporary file so the window can
    // show them. This keeps one execution and needs no marker parsing.
    let log = settingsTrimLines(exec("mktemp -t synapse-i2p"))
    if len(log) == 0 { emit "1\nCould not create a temporary log for the controller output." }
    let invocation = controller + " " + command
    let code = shellRun("{ " + invocation + "; } > " + settingsShellQuote(log) + " 2>&1")
    let output = exec("cat " + settingsShellQuote(log))
    exec("rm -f " + settingsShellQuote(log))
    emit code + "\n" + output
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

// Download in a child process so the Objective-K event loop stays responsive.
// No automatic download, and the controller serializes installation attempts.
let settingsComponentLog = ""

func onManagedInstall(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    let controller = settingsController()
    if len(controller) == 0 {
        doText(status, "Managed component controller is unavailable.")
        emit done()
    }
    let log = settingsTrimLines(exec("mktemp -t synapse-i2p-download"))
    if len(log) == 0 {
        doText(status, "Could not create download status file.")
        emit done()
    }
    let invocation = controller + " component-install"
    let background = invocation + " </dev/null > " + settingsShellQuote(log) + " 2>&1 &"
    if shellRun(background) != "0" {
        doText(status, "Could not start the component updater.")
        emit done()
    }
    settingsComponentLog = log
    doText(status, "I2P+ update requested. Use Refresh status to check the result.")
    doTextBox(details, "Only signed packages are installed. Existing router stays selected until verification finishes.")
    emit done()
}

func onRouterRefresh(self, cmd, sender) {
    let details = get(sender, "details")
    let status = get(sender, "status")
    doText(status, "Checking the installed I2P+ router…")
    let output = runSettingsTool("status", "personal")
    let detailsText = settingsCommandOutput(output)
    if len(settingsComponentLog) > 0 {
        detailsText = detailsText + "\n\nLatest component update:\n" + readFile(settingsComponentLog)
    }
    doTextBox(details, detailsText)
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
        doText(status, "Start requested. I2P browsing stays blocked until the router check succeeds.")
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
    if settingsCommandSucceeded(output) {
        doText(status, "I2P browser launch requested for " + identity + ".")
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
    if settingsCommandSucceeded(output) {
        doText(status, "SusiDNS launch requested. Adding its optional feed is a separate trust decision.")
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

    let managed = button(win, "Install or update I2P+", area(26, 266, 178, 30))
    label(win, "Router starts only when requested.", area(219, 270, 420, 24))
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

    settingsBind(managed, identity, details, status)
    doClick(managed, "synapse.i2p.settings.managed", funcptr(onManagedInstall))
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
