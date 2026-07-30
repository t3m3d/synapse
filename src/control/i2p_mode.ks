#!/usr/bin/env kr
// Small I2P-only OKUI surface kept separate while the large-window compiler
// access violation is tracked in the Krypton repository.

import "k:okui"
import "k:proc_ex"
import "../platform/windows/browser_spawn.k"

func i2pModeDirectory(path) {
    let index = len(path) - 1
    while index >= 0 {
        if path[index] == "\\" || path[index] == "/" {
            emit substring(path, 0, index)
        }
        index -= 1
    }
    emit ""
}

func i2pModeTool() {
    let image = processImagePath(GetCurrentProcessId())
    if len(image) == 0 { emit "" }
    emit i2pModeDirectory(image) + "\\synapse-tool.exe"
}

func i2pModeIdentity(label) {
    if label == "Personal" { emit "personal" }
    if label == "Work" { emit "work" }
    if label == "School" { emit "school" }
    if label == "Creator" { emit "creator" }
    if label == "Second account" { emit "second-account" }
    emit "personal"
}

func i2pModeBind(control, identity, status) {
    doSet(control, "identity", identity)
    doSet(control, "status", status)
    emit done()
}

func onI2pModeOpen(self, cmd, sender) {
    let tool = i2pModeTool()
    let identity = i2pModeIdentity(choice(get(sender, "identity")))
    let status = get(sender, "status")
    let output = windowsRunCapture(
        tool, "i2p-open " + identity, i2pModeDirectory(tool)
    )
    if windowsRunSucceeded(output) == "1" && contains(output, "started through") {
        doText(status, "I2P " + identity + " opened through 127.0.0.1:4444")
    } else {
        doText(status, "Open failed; run synapse-tool i2p-check for details")
    }
    emit done()
}

func onI2pModeRouter(self, cmd, sender) {
    let status = get(sender, "status")
    let launcher = "C:\\Program Files\\i2p\\docs\\startconsole.html"
    let directory = i2pModeDirectory(launcher)
    if windowsStartDetached(launcher, "", directory) == "1" {
        doText(status, "I2P+ Router Console opened at 127.0.0.1:7657")
    } else {
        doText(status, "Router launcher missing: " + launcher)
    }
    emit done()
}

just run {
    app("Synapse I2P Mode")
    let win = window("Synapse I2P Mode", 560, 270)
    minSize(win, 520, 250)
    doTransparentTitlebar(win)
    // Literal until every installed Krypton release carries the corrected
    // Windows rgb() helper; avoids the old unresolved chr() call target.
    doWindowBackground(win, "0x08110E")

    let brand = title(win, "Synapse · I2P+", area(26, 214, 250, 30))
    doFont(brand, fontFamily(mono(16), "Segoe UI Semibold"))
    label(win, "Proxy 127.0.0.1:4444 · Router 127.0.0.1:7657", area(26, 184, 460, 24))

    label(win, "Identity", area(26, 137, 90, 24))
    let identity = choices(win, area(110, 132, 180, 150))
    doAddChoice(identity, "Personal")
    doAddChoice(identity, "Work")
    doAddChoice(identity, "School")
    doAddChoice(identity, "Creator")
    doAddChoice(identity, "Second account")
    doChoose(identity, 0)

    let open = button(win, "Open I2P Browser", area(26, 78, 180, 36))
    let router = button(win, "I2P+ Router", area(220, 78, 160, 36))
    let status = label(win, "Ready — numeric loopback bypass only", area(26, 34, 490, 24))

    i2pModeBind(open, identity, status)
    i2pModeBind(router, identity, status)
    doClick(open, "synapse.i2p.open", funcptr(onI2pModeOpen))
    doClick(router, "synapse.i2p.router", funcptr(onI2pModeRouter))

    doShow(win)
    doRun()
}
