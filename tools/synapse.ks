#!/usr/bin/env kr
// Synapse source/build controller. Product build orchestration stays KryptScript.
// Overlay copy is additive/update-only; no upstream files are deleted.

func quote(value) {
    emit fromCharCode(34) + value + fromCharCode(34)
}

func chomp(value) {
    let end = len(value)
    while end > 0 {
        let c = charCode(value[end - 1])
        if c == 10 || c == 13 || c == 32 || c == 9 { end -= 1 }
        else { break }
    }
    emit substring(value, 0, end)
}

func exists(path) {
    let result = exec("if exist " + quote(path) + " (echo yes) else (echo no)")
    emit contains(result, "yes")
}

func winSlash() { emit fromCharCode(92) }

func joinPath(base, child) {
    emit base + winSlash() + child
}

func envValue(name) {
    let raw = chomp(exec("set " + name))
    let prefix = name + "="
    if indexOf(raw, prefix) == 0 {
        emit substring(raw, len(prefix), len(raw))
    }
    emit ""
}

func isSafeAbsoluteWindowsPath(path) {
    if len(path) < 4 { emit "0" }
    let code = charCode(path[0])
    let isUpper = code >= 65 && code <= 90
    let isLower = code >= 97 && code <= 122
    if !isUpper && !isLower { emit "0" }
    if path[1] != ":" { emit "0" }
    if path[2] != "\\" && path[2] != "/" { emit "0" }

    // Reject characters that can escape cmd.exe or the MSYS shell.
    if contains(path, fromCharCode(34)) { emit "0" }
    if contains(path, "'") { emit "0" }
    if contains(path, "%") { emit "0" }
    if contains(path, "!") { emit "0" }
    if contains(path, "&") { emit "0" }
    if contains(path, "|") { emit "0" }
    if contains(path, "<") { emit "0" }
    if contains(path, ">") { emit "0" }
    if contains(path, fromCharCode(10)) { emit "0" }
    if contains(path, fromCharCode(13)) { emit "0" }
    emit "1"
}

func fullPath(path) {
    if isSafeAbsoluteWindowsPath(path) != "1" { emit "" }
    emit chomp(exec("for %I in (" + quote(path) + ") do @echo %~fI"))
}

func isWorkspaceRoot(path) {
    if !exists(joinPath(joinPath(path, "tools"), "synapse.ks")) { emit "0" }
    if !exists(joinPath(joinPath(path, "overlay"), "browser")) { emit "0" }
    if !exists(joinPath(joinPath(path, "config"), "mozconfig.in")) { emit "0" }
    emit "1"
}

func workspaceRoot() {
    let configured = envValue("SYNAPSE_WORKSPACE_ROOT")
    if len(configured) > 0 { emit fullPath(configured) }

    let candidate = fullPath(chomp(exec("cd")))
    let depth = 0
    while depth < 6 && len(candidate) > 3 {
        if isWorkspaceRoot(candidate) == "1" { emit candidate }
        let parent = fullPath(joinPath(candidate, ".."))
        if parent == candidate || len(parent) == 0 { break }
        candidate = parent
        depth += 1
    }
    emit ""
}

func firefoxRoot() {
    let configured = envValue("SYNAPSE_FIREFOX_ROOT")
    if len(configured) > 0 { emit fullPath(configured) }
    emit fullPath("C:\\mozilla-source\\firefox")
}

func lowerDrive(character) {
    let code = charCode(character)
    if code >= 65 && code <= 90 { emit fromCharCode(code + 32) }
    emit character
}

func msysPath(path) {
    let normalized = replace(path, "\\", "/")
    if len(normalized) > 2 && normalized[1] == ":" {
        emit "/" + lowerDrive(normalized[0]) + substring(normalized, 2, len(normalized))
    }
    emit normalized
}

func bashQuote(value) {
    // Root validation rejects single quotes before this is called.
    emit "'" + value + "'"
}

func buildStateRoot() {
    emit joinPath(workspaceRoot(), ".synapse-build")
}

func makePath() {
    emit joinPath(joinPath(joinPath(buildStateRoot(), "toolchains"), "mozmake"), "mozmake.exe")
}

func printCheck(name, path) {
    let state = "missing"
    if exists(path) { state = "ok" }
    print(name + ": " + state + " (" + path + ")")
    emit state
}

func validateRoots(showDetails) {
    let workspace = workspaceRoot()
    let root = firefoxRoot()
    let failures = 0

    if len(workspace) == 0 || isSafeAbsoluteWindowsPath(workspace) != "1" {
        print("Workspace root is missing or unsafe.")
        print("Run from the Synapse repository or set SYNAPSE_WORKSPACE_ROOT.")
        failures += 1
    } else if isWorkspaceRoot(workspace) != "1" {
        print("Workspace root is not a Synapse repository: " + workspace)
        failures += 1
    }

    if len(root) == 0 || isSafeAbsoluteWindowsPath(root) != "1" {
        print("Firefox root is missing or unsafe.")
        failures += 1
    } else {
        if !exists(joinPath(root, "mach")) {
            print("Firefox source missing mach: " + root)
            failures += 1
        }
        if !exists(joinPath(joinPath(root, "browser"), "branding")) {
            print("Firefox source missing browser\\branding: " + root)
            failures += 1
        }
    }

    if len(workspace) > 0 && len(root) > 0 && workspace == root {
        print("Workspace and Firefox roots must be separate.")
        failures += 1
    }
    if showDetails == "1" {
        print("Workspace root: " + workspace)
        print("Firefox root: " + root)
    }
    if failures > 0 { emit "0" }
    emit "1"
}

func doctor() {
    let workspace = workspaceRoot()
    let root = firefoxRoot()
    let failures = 0

    if validateRoots("1") != "1" { failures += 1 }
    if printCheck("MozillaBuild", "C:\\mozilla-build\\start-shell.bat") != "ok" { failures += 1 }
    if len(workspace) > 0 {
        if printCheck("Synapse overlay", joinPath(joinPath(workspace, "overlay"), "browser")) != "ok" { failures += 1 }
        if printCheck("Synapse mozconfig template", joinPath(joinPath(workspace, "config"), "mozconfig.in")) != "ok" { failures += 1 }
        if printCheck("Synapse make", makePath()) != "ok" { failures += 1 }
        print("Build state: " + buildStateRoot())
        print("Build state (MSYS): " + msysPath(buildStateRoot()))
    }
    if len(root) > 0 {
        if printCheck("Firefox source", joinPath(root, "mach")) != "ok" { failures += 1 }
    }
    if printCheck("Krypton frontend", "C:\\krypton\\kcc-bin.exe") != "ok" { failures += 1 }
    if printCheck("Krypton runtime", "C:\\krypton\\krypton_rt.dll") != "ok" { failures += 1 }

    if failures > 0 {
        print("Doctor: " + failures + " required check(s) failed")
        emit "0"
    }
    print("Doctor: ready")
    emit "1"
}

func copyOverlay(source, destination) {
    let command = "robocopy " + quote(source) + " " + quote(destination)
    command = command + " /E /COPY:DAT /DCOPY:T /R:2 /W:1 /NFL /NDL /NP"
    command = command + " & if errorlevel 8 (echo __SYNAPSE_FAIL__) else (echo __SYNAPSE_OK__)"
    let output = exec(command)
    if len(output) > 0 { print(output) }
    if contains(output, "__SYNAPSE_OK__") { emit "1" }
    print("Overlay copy failed or returned no success marker.")
    emit "0"
}

func backupMozconfig(target) {
    if !exists(target) { emit "1" }
    let current = readFile(target)
    if contains(current, "# Generated by Synapse KryptScript") { emit "1" }

    let backup = target + ".pre-synapse"
    if exists(backup) {
        print("Preserving existing mozconfig backup: " + backup)
        emit "1"
    }

    let command = "copy /Y " + quote(target) + " " + quote(backup)
    command = command + " >nul && echo __SYNAPSE_OK__ || echo __SYNAPSE_FAIL__"
    let output = exec(command)
    if contains(output, "__SYNAPSE_OK__") {
        print("Backed up existing mozconfig: " + backup)
        emit "1"
    }
    print("Could not back up existing mozconfig.")
    emit "0"
}

func installMozconfig(workspace, root) {
    let templatePath = joinPath(joinPath(workspace, "config"), "mozconfig.in")
    let target = joinPath(root, "mozconfig")
    if !exists(templatePath) {
        print("Missing mozconfig template: " + templatePath)
        emit "0"
    }
    if backupMozconfig(target) != "1" { emit "0" }

    let rendered = readFile(templatePath)
    rendered = replace(rendered, "@SYNAPSE_WORKSPACE_MSYS@", msysPath(workspace))
    if contains(rendered, "@SYNAPSE_WORKSPACE_MSYS@") {
        print("mozconfig template still contains unresolved placeholders.")
        emit "0"
    }

    writeFile(target, rendered)
    if !exists(target) || readFile(target) != rendered {
        print("mozconfig write verification failed: " + target)
        emit "0"
    }
    print("Installed Synapse mozconfig: " + target)
    emit "1"
}

func applyPrivacyPatch(workspace, root) {
    let patchPath = joinPath(joinPath(joinPath(workspace, "overlay"), "privacy"), "privacy-loader.patch")
    if !exists(patchPath) {
        print("Missing privacy loader patch: " + patchPath)
        emit "0"
    }

    let check = "git -C " + quote(root) + " apply --check " + quote(patchPath)
    let checkOutput = exec(check + " >nul 2>&1 && echo __SYNAPSE_OK__ || echo __SYNAPSE_NO__")
    if contains(checkOutput, "__SYNAPSE_OK__") {
        let applyOutput = exec("git -C " + quote(root) + " apply " + quote(patchPath) + " 2>&1 && echo __SYNAPSE_OK__ || echo __SYNAPSE_FAIL__")
        if len(applyOutput) > 0 { print(applyOutput) }
        if contains(applyOutput, "__SYNAPSE_OK__") {
            print("Applied Synapse privacy loader patch.")
            emit "1"
        }
        print("Privacy loader patch failed while applying.")
        emit "0"
    }

    let reverse = "git -C " + quote(root) + " apply --reverse --check " + quote(patchPath)
    let reverseOutput = exec(reverse + " >nul 2>&1 && echo __SYNAPSE_OK__ || echo __SYNAPSE_NO__")
    if contains(reverseOutput, "__SYNAPSE_OK__") {
        print("Synapse privacy loader patch is already applied.")
        emit "1"
    }

    print("Privacy loader patch does not apply cleanly in either direction.")
    print("Source may have drifted; inspect: " + patchPath)
    emit "0"
}

func applyOverlay() {
    if validateRoots("0") != "1" { emit "0" }
    let workspace = workspaceRoot()
    let root = firefoxRoot()
    let sourceBrowser = joinPath(joinPath(workspace, "overlay"), "browser")
    let destinationBrowser = joinPath(root, "browser")

    print("Applying Synapse browser overlay without deleting upstream files...")
    if copyOverlay(sourceBrowser, destinationBrowser) != "1" { emit "0" }
    if !exists(joinPath(joinPath(joinPath(joinPath(root, "browser"), "branding"), "synapse"), "configure.sh")) {
        print("Overlay verification failed: Synapse branding is missing.")
        emit "0"
    }
    if !exists(joinPath(joinPath(joinPath(joinPath(root, "browser"), "app"), "profile"), "synapse.js")) {
        print("Overlay verification failed: Synapse privacy preferences are missing.")
        emit "0"
    }
    if applyPrivacyPatch(workspace, root) != "1" { emit "0" }
    if installMozconfig(workspace, root) != "1" { emit "0" }
    print("Apply: complete")
    emit "1"
}

func printLogTail(logPath) {
    if !exists(logPath) {
        print("No mach log was created: " + logPath)
        emit "0"
    }
    let script = "Get-Content -LiteralPath '" + logPath + "' -Tail 80"
    let output = exec("powershell -NoProfile -Command " + quote(script))
    if len(output) > 0 { print(output) }
    emit "1"
}

func runMach(action, label) {
    if doctor() != "1" { emit "0" }
    if applyOverlay() != "1" { emit "0" }

    let state = buildStateRoot()
    let logPath = joinPath(state, "mach-" + label + ".log")
    let inside = "export MOZBUILD_STATE_PATH=" + bashQuote(msysPath(state))
    inside = inside + "; export GMAKE=" + bashQuote(msysPath(makePath()))
    inside = inside + "; cd " + bashQuote(msysPath(firefoxRoot()))
    inside = inside + " && ./mach " + action
    inside = inside + " > " + bashQuote(msysPath(logPath)) + " 2>&1"

    let command = "set USE_MINTTY=0&& call C:\\mozilla-build\\start-shell.bat -c " + quote(inside)
    command = command + " & if errorlevel 1 (echo __SYNAPSE_FAIL__) else (echo __SYNAPSE_OK__)"
    print("Running: mach " + action)
    print("Log: " + logPath)
    let output = exec(command)
    if len(output) > 0 { print(output) }
    if contains(output, "__SYNAPSE_OK__") {
        print("Mach " + label + ": complete")
        emit "1"
    }
    print("Mach " + label + ": failed")
    printLogTail(logPath)
    emit "0"
}

func usage() {
    print("Synapse KryptScript controller")
    print("  synapse-tool doctor")
    print("  synapse-tool apply")
    print("  synapse-tool build")
    print("  synapse-tool faster")
    print("  synapse-tool run")
    print("  synapse-tool package")
    print("")
    print("Optional environment:")
    print("  SYNAPSE_WORKSPACE_ROOT  Synapse overlay repository")
    print("  SYNAPSE_FIREFOX_ROOT    Firefox source checkout")
    emit "1"
}

just run {
    if argCount() == 0 {
        usage()
        exit(0)
    }

    let command = arg(0)
    if command == "doctor" {
        if doctor() == "1" { exit(0) }
        exit(1)
    }
    if command == "apply" {
        if applyOverlay() == "1" { exit(0) }
        exit(1)
    }
    if command == "build" {
        if runMach("build", "build") == "1" { exit(0) }
        exit(1)
    }
    if command == "faster" {
        if runMach("build faster", "faster") == "1" { exit(0) }
        exit(1)
    }
    if command == "run" {
        if runMach("run --no-remote", "run") == "1" { exit(0) }
        exit(1)
    }
    if command == "package" {
        if runMach("package", "package") == "1" { exit(0) }
        exit(1)
    }

    print("Unknown command: " + command)
    usage()
    exit(2)
}
