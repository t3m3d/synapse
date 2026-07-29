#!/usr/bin/env kr
// Objective-K Synapse launcher and privacy-context control surface.

import "k:okui"
import "../core/privacy.k"

func bind(control, mode, details, status) {
    doSet(control, "mode", mode)
    doSet(control, "details", details)
    doSet(control, "status", status)
    emit done()
}

func showMode(sender) {
    let modeControl = get(sender, "mode")
    let details = get(sender, "details")
    let status = get(sender, "status")
    let mode = privacyModeFromLabel(choice(modeControl))

    doTextBox(details, privacyModeLabel(mode) + "\r\n\r\n" + privacySummary(mode))
    if mode == "shield" {
        doText(status, "Shield policy integration in progress")
        emit done()
    }
    doText(status, "Fail closed: this context is not engine-enforced yet")
    emit done()
}

func onDescribe(self, cmd, sender) {
    emit showMode(sender)
}

func onLaunch(self, cmd, sender) {
    let modeControl = get(sender, "mode")
    let status = get(sender, "status")
    let mode = privacyModeFromLabel(choice(modeControl))

    // Never pretend an isolation mode is active before its engine checks land.
    if mode != "shield" {
        doText(status, "Launch blocked: " + privacyModeLabel(mode) + " is not enforced yet")
        emit done()
    }

    let browser = "C:\\mozilla-source\\firefox\\obj-synapse\\dist\\bin\\firefox.exe"
    let profile = "C:\\mozilla-source\\profiles\\synapse-dev"
    exec("if not exist \"C:\\mozilla-source\\profiles\" mkdir \"C:\\mozilla-source\\profiles\"")
    exec("if not exist \"" + profile + "\" mkdir \"" + profile + "\"")

    let launch = "start \"\" \"" + browser + "\" -no-remote -profile \"" + profile + "\""
    exec(launch)
    doText(status, "Synapse development profile launched")
    emit done()
}

func onBuild(self, cmd, sender) {
    let status = get(sender, "status")
    doText(status, "Build started in background")
    exec("start \"Synapse build\" dist\\synapse-tool.exe build")
    emit done()
}

just run {
    app("Synapse Control")
    let win = window("Synapse Control", 720, 470)
    minSize(win, 660, 430)
    doTransparentTitlebar(win)
    doWindowBackground(win, rgb(244, 247, 251))

    let brand = title(win, "Synapse", area(28, 414, 220, 30))
    doFont(brand, fontFamily(mono(16), "Segoe UI Semibold"))
    label(win, "Private by design. Honest by default.", area(220, 417, 350, 24))

    label(win, "Privacy context", area(28, 356, 150, 24))
    let mode = choices(win, area(174, 352, 220, 160))
    doAddChoice(mode, "Shield")
    doAddChoice(mode, "Private")
    doAddChoice(mode, "Tor")
    doAddChoice(mode, "I2P")
    doAddChoice(mode, "Blackout")
    doChoose(mode, 0)

    let describe = button(win, "Review policy", area(414, 352, 126, 32))
    let launch = button(win, "Launch", area(552, 352, 126, 32))

    let details = textBox(win, area(28, 102, 650, 224))
    doEditable(details, 0)
    doTextBox(details, "Shield\r\n\r\n" + privacySummary("shield"))

    let build = button(win, "Build Synapse", area(28, 50, 142, 32))
    let status = label(win, "Firefox source baseline", area(188, 55, 490, 24))

    bind(describe, mode, details, status)
    bind(launch, mode, details, status)
    doSet(build, "status", status)

    doClick(describe, "synapse.describe", funcptr(onDescribe))
    doClick(launch, "synapse.launch", funcptr(onLaunch))
    doClick(build, "synapse.build", funcptr(onBuild))

    doShow(win)
    doRun()
}
