#!/usr/bin/env kr
// Synapse macOS source/build controller.
//
// Ported from tools/synapse-macos.sh. Same commands, same preconditions, same
// ordering and same messages. Build orchestration is KryptScript; `mach` and
// its Python remain external tools this controller drives, because the Mozilla
// build system is not ours to replace.
//
// Two behaviors carried over from the bash controller deliberately:
//   - The Krypton compiler is resolved by its version banner, because macOS
//     ships a Kerberos tool named `kcc` in /usr/bin that shadows it.
//   - `mach` is started as ./mach from the Firefox source root, because its
//     Python bootstrap re-executes itself as a relative path.
//
// Comparison rules this file relies on (verified against kcc 2.4.8):
//   - Builtins like contains()/startsWith()/len() return numbers, so they are
//     compared with numeric literals (== 1), never with "1".
//   - getLine()/substring() return text, so exit codes read that way are
//     compared with text ("0").
import "k:sh"

// ── shell plumbing ───────────────────────────────────────────────────
// exec() returns stdout only, so commands that matter append an exit marker.
func chomp(value) {
    let lo = 0
    let hi = len(value)
    while lo < hi {
        let c = toInt(charCode(value[lo]))
        if c == 32 || c == 9 || c == 10 || c == 13 { lo += 1 } else { break }
    }
    while hi > lo {
        let c = toInt(charCode(value[hi - 1]))
        if c == 32 || c == 9 || c == 10 || c == 13 { hi -= 1 } else { break }
    }
    emit substring(value, lo, hi)
}

func quote(value) { emit "\"" + value + "\"" }

// okCmd: 1 when the command exits 0, else 0. Output is discarded.
func okCmd(command) {
    emit contains(
        exec("( " + command + " ) >/dev/null 2>&1 && echo __SYNAPSE_YES__ || echo __SYNAPSE_NO__"),
        "__SYNAPSE_YES__")
}

func exists(path) { emit okCmd("test -e " + quote(path)) }
func isFile(path) { emit okCmd("test -f " + quote(path)) }
func isDir(path) { emit okCmd("test -d " + quote(path)) }

// runMarked: "code\noutput" — first line is the exit code, the rest is stdout
// and stderr merged. One shell invocation, so a failing step is never repeated.
// Mirror shell command substitution, which drops trailing newlines: callers add
// exactly one newline when they print, so any extra would show up as a blank line.
func trimTrailingNewlines(value) {
    let hi = len(value)
    while hi > 0 {
        let c = toInt(charCode(substring(value, hi - 1, hi)))
        if c == 10 || c == 13 { hi -= 1 } else { break }
    }
    emit substring(value, 0, hi)
}

// shellRun waits for the child and hands back its real exit status, so the code
// no longer has to be smuggled through stdout as a sentinel. The child's stdout
// and stderr go to a temporary file that is read and removed here: one
// execution, real status, captured body.
func runMarked(command) {
    let log = getLine(exec("mktemp -t synapse-run"), 0)
    if len(log) == 0 { emit "127\n" }
    let code = shellRun("{ " + command + "; } > " + quote(log) + " 2>&1")
    let output = exec("cat " + quote(log))
    exec("rm -f " + quote(log))
    emit code + "\n" + trimTrailingNewlines(output)
}

func runCode(command) { emit getLine(runMarked(command), 0) }

func runBody(command) {
    let raw = runMarked(command)
    let first = getLine(raw, 0)
    emit substring(raw, len(first) + 1, len(raw))
}

func envValue(name) { emit chomp(exec("printenv " + quote(name) + " 2>/dev/null")) }

func fail(message) {
    printErr("Synapse: " + message)
    exit(1)
}

func needCommand(name) {
    if which(name) == "" { fail("required command is missing: " + name) }
}

// ── roots ────────────────────────────────────────────────────────────
func joinPath(base, child) {
    if len(base) == 0 { emit child }
    if base[len(base) - 1] == "/" { emit base + child }
    emit base + "/" + child
}

func isWorkspaceRoot(path) {
    if exists(joinPath(joinPath(path, "tools"), "synapse.ks")) != 1 { emit 0 }
    if isDir(joinPath(joinPath(path, "overlay"), "browser")) != 1 { emit 0 }
    if isFile(joinPath(joinPath(path, "config"), "mozconfig.in")) != 1 { emit 0 }
    emit 1
}

// workspaceRoot: the repository containing this controller, found from the
// current directory upward, so `kr tools/synapse-macos.ks ...` works anywhere
// inside the checkout.
func workspaceRoot() {
    let configured = envValue("SYNAPSE_WORKSPACE_ROOT")
    if len(configured) > 0 { emit configured }

    let candidate = chomp(exec("pwd"))
    let depth = 0
    while depth < 6 && len(candidate) > 1 {
        if isWorkspaceRoot(candidate) == 1 { emit candidate }
        let parent = chomp(exec("cd " + quote(candidate) + " && cd .. && pwd"))
        if parent == candidate || len(parent) == 0 { break }
        candidate = parent
        depth += 1
    }
    emit ""
}

func workspace() {
    let root = workspaceRoot()
    if len(root) == 0 {
        fail("workspace is not a Synapse repository; run from the checkout or set SYNAPSE_WORKSPACE_ROOT")
    }
    emit root
}

func firefoxRoot() {
    let configured = envValue("SYNAPSE_FIREFOX_ROOT")
    if len(configured) > 0 { emit configured }
    emit joinPath(envValue("HOME"), "mozilla-source/firefox")
}

func buildStateRoot() { emit joinPath(workspace(), ".synapse-build") }
func objRoot() { emit joinPath(buildStateRoot(), "obj-synapse") }
func mozbuildStateRoot() { emit joinPath(buildStateRoot(), "mozbuild") }

func checkRoots() {
    if isFile(joinPath(workspace(), "tools/synapse.ks")) != 1 {
        fail("workspace is not a Synapse repository: " + workspace())
    }
    if isFile(joinPath(firefoxRoot(), "mach")) != 1 {
        fail("Firefox source is missing: " + firefoxRoot())
    }
    if workspace() == firefoxRoot() {
        fail("Synapse and Firefox roots must be separate")
    }
}

// ── toolchain ────────────────────────────────────────────────────────
// macOS ships a Kerberos credential-cache tool named kcc in /usr/bin, which can
// shadow the Krypton compiler when /usr/local/bin is later in PATH. Resolve the
// compiler by its version banner instead of by name alone.
func kryptonKccCandidates() {
    let list = envValue("SYNAPSE_KCC") + "\n" + chomp(exec("command -v kcc 2>/dev/null"))
    list = list + "\n/usr/local/bin/kcc\n/opt/homebrew/bin/kcc"
    emit list
}

func isKryptonKcc(path) {
    if len(path) == 0 { emit 0 }
    if okCmd("test -x " + quote(path)) != 1 { emit 0 }
    let banner = getLine(runBody(quote(path) + " --version 2>/dev/null"), 0)
    if startsWith(chomp(banner), "kcc version ") == 1 { emit 1 }
    emit 0
}

func findKryptonKcc() {
    let candidates = kryptonKccCandidates()
    let count = lineCount(candidates)
    let i = 0
    while i < count {
        let candidate = chomp(getLine(candidates, i))
        if isKryptonKcc(candidate) == 1 { emit candidate }
        i += 1
    }
    emit ""
}

func requireKcc() {
    let kcc = findKryptonKcc()
    if len(kcc) == 0 {
        fail("Krypton compiler is missing (install Krypton 2.4+ or set SYNAPSE_KCC)")
    }
    emit kcc
}

// ── doctor ───────────────────────────────────────────────────────────
func doctor() {
    let failures = 0
    print("Workspace root: " + workspaceRoot())
    print("Firefox root: " + firefoxRoot())
    print("Host: macOS " + chomp(exec("sw_vers -productVersion 2>/dev/null")) +
        " (" + chomp(exec("uname -m 2>/dev/null")) + ")")

    let tools = "git\nrsync\npython3"
    let i = 0
    while i < lineCount(tools) {
        let name = chomp(getLine(tools, i))
        if which(name) != "" {
            print(name + ": ok")
        } else {
            print(name + ": missing")
            failures += 1
        }
        i += 1
    }

    let kcc = findKryptonKcc()
    if len(kcc) > 0 {
        print("Krypton compiler: ok (" + kcc + ", " + chomp(getLine(runBody(quote(kcc) + " --version"), 0)) + ")")
    } else {
        print("Krypton compiler: missing (install Krypton 2.4+ or set SYNAPSE_KCC)")
        failures += 1
    }

    if isFile(joinPath(firefoxRoot(), "mach")) == 1 {
        print("Firefox source: ok")
    } else {
        print("Firefox source: missing (" + firefoxRoot() + ")")
        failures += 1
    }

    if failures > 0 { fail(failures + " required check(s) failed") }
    print("Doctor: ready")
}

// ── mozconfig and overlay patches ────────────────────────────────────
func installMozconfig() {
    let template = joinPath(joinPath(workspace(), "config"), "mozconfig.in")
    let target = joinPath(firefoxRoot(), "mozconfig")

    if isFile(template) != 1 { fail("missing mozconfig template: " + template) }

    if isFile(target) == 1 && !contains(readFile(target), "# Generated by Synapse") {
        if exists(target + ".pre-synapse") != 1 {
            exec("cp -p " + quote(target) + " " + quote(target + ".pre-synapse"))
        }
    }

    let rendered = replace(readFile(template), "@SYNAPSE_WORKSPACE_NATIVE@", workspace())
    rendered = replace(rendered, "@SYNAPSE_WORKSPACE_MSYS@", workspace())
    writeFile(target, rendered)
    if contains(readFile(target), "@SYNAPSE_WORKSPACE_") { fail("mozconfig has unresolved placeholders") }
    print("Installed Synapse mozconfig: " + target)
}

// applyPatch: apply once, tolerate an already-applied tree, fail on drift.
func applyPatch(patch, description) {
    if isFile(patch) != 1 { fail("missing " + description + " patch: " + patch) }
    let root = firefoxRoot()
    if okCmd("git -C " + quote(root) + " apply --check " + quote(patch)) == 1 {
        let applied = runMarked("git -C " + quote(root) + " apply " + quote(patch))
        let code = getLine(applied, 0)
        let body = substring(applied, len(code) + 1, len(applied))
        if code == "0" {
            print("Applied Synapse " + description + " patch.")
            emit 1
        }
        if len(body) > 0 { print(body) }
        fail(description + " patch failed while applying")
    }
    if okCmd("git -C " + quote(root) + " apply --reverse --check " + quote(patch)) == 1 {
        print("Synapse " + description + " patch is already applied.")
        emit 1
    }
    fail(description + " patch no longer applies cleanly")
}

func overlayPatch(name) {
    emit joinPath(joinPath(joinPath(workspace(), "overlay"), "privacy"), name)
}

func applyOverlay() {
    checkRoots()
    needCommand("rsync")
    if isDir(joinPath(joinPath(workspace(), "overlay"), "browser")) != 1 {
        fail("missing browser overlay: " + joinPath(joinPath(workspace(), "overlay"), "browser"))
    }

    print("Applying Synapse browser overlay without deleting upstream files...")
    let copied = runMarked("rsync -a " +
        quote(joinPath(joinPath(workspace(), "overlay"), "browser") + "/") + " " +
        quote(joinPath(firefoxRoot(), "browser") + "/"))
    if getLine(copied, 0) != "0" {
        let code = getLine(copied, 0)
        let body = substring(copied, len(code) + 1, len(copied))
        if len(body) > 0 { print(body) }
        fail("overlay copy failed")
    }

    if isFile(joinPath(firefoxRoot(), "browser/branding/synapse/configure.sh")) != 1 {
        fail("branding overlay verification failed")
    }
    if isFile(joinPath(firefoxRoot(), "browser/app/profile/synapse.js")) != 1 {
        fail("privacy preferences verification failed")
    }

    applyPatch(overlayPatch("privacy-loader.patch"), "privacy loader")
    applyPatch(overlayPatch("synapse-theme.patch"), "browser theme")
    applyPatch(overlayPatch("synapse-newtaburl.patch"), "new tab URL")
    applyPatch(overlayPatch("synapse-startpage-label.patch"), "start page label")
    applyPatch(overlayPatch("synapse-session-recovery.patch"), "session recovery popup")
    installMozconfig()
    print("Apply: complete")
}

// ── mach ─────────────────────────────────────────────────────────────
func tailLog(path, count) {
    if isFile(path) != 1 { emit "" }
    emit exec("tail -n " + count + " " + quote(path) + " 2>/dev/null")
}

func runMach(label, args) {
    doctor()
    applyOverlay()
    let buildRoot = buildStateRoot()
    let mozbuildRoot = mozbuildStateRoot()
    exec("mkdir -p " + quote(buildRoot) + " " + quote(mozbuildRoot))

    let log = joinPath(buildRoot, "mach-" + label + ".log")
    print("Running: mach " + args)
    print("Source root: " + firefoxRoot())
    print("Log: " + log)

    // mach's Python bootstrap re-executes itself as a relative `mach` path, so
    // it must be started as ./mach from the Firefox source root.
    let code = runCode("cd " + quote(firefoxRoot()) +
        " && MOZBUILD_STATE_PATH=" + quote(mozbuildRoot) +
        " ./mach " + args + " >" + quote(log) + " 2>&1")
    if code == "0" {
        print("Mach " + label + ": complete")
        emit 1
    }
    printErr(tailLog(log, 80))
    fail("mach " + label + " failed")
}

// ── Krypton build and tests ──────────────────────────────────────────
func buildKrypton(source, output, description) {
    let kcc = requireKcc()
    exec("mkdir -p " + quote(buildStateRoot()))
    print("Krypton compiler: " + kcc)
    let code = runCode(quote(kcc) + " " + quote(source) + " -o " + quote(output))
    if code != "0" { fail("Krypton build failed: " + description) }
    emit output
}

func runCoreTests() {
    let binary = buildKrypton(joinPath(workspace(), "tests/run.ks"),
        joinPath(buildStateRoot(), "synapse-tests"), "core contracts")
    let result = runMarked(quote(binary))
    let code = getLine(result, 0)
    let output = substring(result, len(code) + 1, len(result))
    if len(output) > 0 { print(chomp(output)) }
    if code != "0" { fail("Krypton core contracts failed") }
}

// ── Objective-K app bundle ───────────────────────────────────────────
// The settings app imports k:okui, which routes to Objective-K over Choc and
// AppKit on macOS. kcc emits a bare Mach-O for that, and macOS treats a bare
// binary as a command-line process: no Info.plist, no bundle identity, and the
// menu bar names the executable path instead of the app. Krypton's own toolchain
// wraps okui apps in a .app (scripts/build-objk-app.ks), so the same layout is
// assembled here into Synapse's build state rather than inside the Krypton tree.
func objkPlist(name, executable, bundleId) {
    let q = fromCharCode(34)
    let version = "1.0"
    emit "<?xml version=" + q + "1.0" + q + " encoding=" + q + "UTF-8" + q + "?>\n" +
        "<!DOCTYPE plist PUBLIC " + q + "-//Apple//DTD PLIST 1.0//EN" + q + " " +
        q + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + q + ">\n" +
        "<plist version=" + q + "1.0" + q + "><dict>\n" +
        "  <key>CFBundleName</key><string>" + name + "</string>\n" +
        "  <key>CFBundleDisplayName</key><string>" + name + "</string>\n" +
        "  <key>CFBundleExecutable</key><string>" + executable + "</string>\n" +
        "  <key>CFBundleIdentifier</key><string>" + bundleId + "</string>\n" +
        "  <key>CFBundlePackageType</key><string>APPL</string>\n" +
        "  <key>CFBundleShortVersionString</key><string>" + version + "</string>\n" +
        "  <key>CFBundleVersion</key><string>" + version + "</string>\n" +
        "  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>\n" +
        "  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>\n" +
        "  <key>LSMinimumSystemVersion</key><string>14.0</string>\n" +
        "  <key>NSHighResolutionCapable</key><true/>\n" +
        "</dict></plist>\n"
}

func buildObjkApp(source, appName, executable, bundleId, description) {
    let bundle = joinPath(buildStateRoot(), appName + ".app")
    let macos = joinPath(bundle, "Contents/MacOS")
    let target = joinPath(macos, executable)
    let plist = joinPath(bundle, "Contents/Info.plist")

    exec("mkdir -p " + quote(macos))
    buildKrypton(source, target, description)
    exec("chmod +x " + quote(target))
    writeFile(plist, objkPlist(appName, executable, bundleId))
    if okCmd("plutil -lint " + quote(plist)) != 1 {
        fail("Info.plist for " + appName + " did not validate")
    }
    // The Mach-O is already ad-hoc signed by kcc; signing the wrapper keeps the
    // bundle valid once the plist and executable are sealed together.
    if okCmd("command -v codesign") == 1 {
        exec("codesign -s - -f --deep " + quote(bundle) + " >/dev/null 2>&1")
    }
    print("Objective-K app bundle: " + bundle)
    emit bundle
}

func buildI2pSettings() {
    emit buildObjkApp(joinPath(workspace(), "src/control/i2p_settings.ks"),
        "Synapse I2P Settings", "synapse-i2p-settings", "org.synapse.settings",
        "I2P settings app")
}

func i2pSettings() {
    let bundle = buildI2pSettings()
    let binary = joinPath(joinPath(bundle, "Contents/MacOS"), "synapse-i2p-settings")
    print("Launching I2P settings app: " + bundle)
    // Executed from inside the bundle, not handed to `open`: the app resolves its
    // workspace from SYNAPSE_WORKSPACE_ROOT, which `open` does not forward.
    let result = runMarked("cd " + quote(workspace()) +
        " && SYNAPSE_WORKSPACE_ROOT=" + quote(workspace()) + " " + quote(binary))
    let code = getLine(result, 0)
    let output = substring(result, len(code) + 1, len(result))
    if len(output) > 0 { print(chomp(output)) }
}

// ── I2P+ router and profiles ─────────────────────────────────────────
func i2pIdentity(value) {
    if value == "personal" || value == "work" || value == "school" ||
        value == "creator" || value == "second-account" {
        emit value
    }
    fail("unknown I2P identity: " + value + " (choose personal, work, school, creator, or second-account)")
}

func i2pProxyReady() {
    // Bash and Python are already required by this controller; keeping the
    // documented Python probe preserves the tested readiness semantics.
    emit okCmd("python3 -c 'import socket; s=socket.socket(); s.settimeout(1.5); " +
        "rc=s.connect_ex((\"127.0.0.1\",4444)); s.close(); " +
        "raise SystemExit(0 if rc == 0 else 1)'")
}

func i2pCheck() {
    print("I2P+ HTTP/HTTPS proxy: 127.0.0.1:4444")
    if i2pProxyReady() == 1 {
        print("I2P+ endpoint check: TCP listener available (not authenticated)")
        emit 1
    }
    printErr("I2P+ readiness: unavailable; start I2P+ and wait for its HTTP proxy")
    emit 0
}

func i2pRouterScript() {
    let configured = envValue("SYNAPSE_I2P_ROUTER_DIR")
    if len(configured) > 0 {
        if isFile(joinPath(configured, "i2prouter")) != 1 {
            fail("I2P+ router script not found in SYNAPSE_I2P_ROUTER_DIR: " + configured)
        }
        emit joinPath(configured, "i2prouter")
    }

    let candidates = "/Applications/i2p\n" + joinPath(envValue("HOME"), "i2p")
    let i = 0
    while i < lineCount(candidates) {
        let dir = chomp(getLine(candidates, i))
        if isFile(joinPath(dir, "i2prouter")) == 1 { emit joinPath(dir, "i2prouter") }
        i += 1
    }
    fail("I2P+ installation not found; set SYNAPSE_I2P_ROUTER_DIR to its install directory")
}

func i2pRouterDir() {
    let script = i2pRouterScript()
    emit chomp(exec("dirname " + quote(script)))
}

func i2pSetupCheck() {
    if which("java") != "" && okCmd("java -version") == 1 {
        print("Java runtime: available")
        print(chomp(getLine(runBody("java -version"), 0)))
    } else {
        print("Java runtime: missing (I2P+ universal installer requires Java 8 or later)")
    }

    let script = ""
    if len(envValue("SYNAPSE_I2P_ROUTER_DIR")) > 0 {
        script = i2pRouterScript()
    } else if isFile("/Applications/i2p/i2prouter") == 1 {
        script = "/Applications/i2p/i2prouter"
    } else if isFile(joinPath(envValue("HOME"), "i2p/i2prouter")) == 1 {
        script = joinPath(envValue("HOME"), "i2p/i2prouter")
    }
    if len(script) > 0 {
        print("I2P+ router script: " + script)
    } else {
        print("I2P+ router script: not found in /Applications/i2p or ~/i2p")
        print("For a custom install path, set SYNAPSE_I2P_ROUTER_DIR.")
    }

    if i2pProxyReady() == 1 {
        print("I2P+ HTTP proxy: listening at 127.0.0.1:4444 (TCP only; bootstrap not verified)")
    } else {
        print("I2P+ HTTP proxy: not listening at 127.0.0.1:4444")
    }
}

func i2pInstallGuide() {
    exec("open " + quote("https://i2pplus.github.io/download.html"))
    print("Opened the official I2P+ downloads page. Install Java 8+ first if needed.")
}

func i2pRouterStatus() {
    let dir = i2pRouterDir()
    print("I2P+ router command status:")
    let result = runMarked("cd " + quote(dir) + " && sh ./i2prouter status")
    let status = getLine(result, 0)
    let output = substring(result, len(status) + 1, len(result))
    if len(output) > 0 { print(output) }
    if i2pProxyReady() == 1 {
        print("Proxy endpoint: listening at 127.0.0.1:4444 (TCP only; bootstrap not verified)")
    } else {
        print("Proxy endpoint: not listening at 127.0.0.1:4444")
    }
    emit status
}

func i2pRouterStart() {
    let dir = i2pRouterDir()
    if i2pProxyReady() == 1 {
        print("I2P+ proxy is already listening at 127.0.0.1:4444")
        emit 1
    }
    let started = runMarked("cd " + quote(dir) + " && sh ./i2prouter start")
    let startCode = getLine(started, 0)
    let startOutput = substring(started, len(startCode) + 1, len(started))
    if len(startOutput) > 0 { print(chomp(startOutput)) }
    if startCode != "0" {
        fail("I2P+ router start command failed")
    }
    print("I2P+ start requested. Synapse I2P browsing remains blocked until the proxy listens at 127.0.0.1:4444.")
    emit 1
}

func i2pRouterStop() {
    let dir = i2pRouterDir()
    let stopped = runMarked("cd " + quote(dir) + " && sh ./i2prouter graceful")
    let stopCode = getLine(stopped, 0)
    let stopOutput = substring(stopped, len(stopCode) + 1, len(stopped))
    if len(stopOutput) > 0 { print(chomp(stopOutput)) }
    if stopCode != "0" {
        fail("I2P+ graceful shutdown command failed")
    }
    print("I2P+ graceful shutdown requested.")
    emit 1
}

// i2pPrefs: the dedicated I2P+ profile preferences, byte-for-byte the set the
// bash controller wrote. DIRECT fallbacks stay disabled; the proxy is the only
// path out.
func i2pPrefs() {
    let sb = sbNew()
    sb = sbAppend(sb, "// Generated by Synapse. Dedicated I2P+ profile.\n")
    sb = sbAppend(sb, "// Proxy: 127.0.0.1:4444. DIRECT fallback prefs disabled.\n")
    sb = sbAppend(sb, "\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.type\", 1);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.http\", \"127.0.0.1\");\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.http_port\", 4444);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.ssl\", \"127.0.0.1\");\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.ssl_port\", 4444);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.socks\", \"\");\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.socks_port\", 0);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.socks_version\", 5);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.share_proxy_settings\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.no_proxies_on\", \"127.0.0.1\");\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.allow_hijacking_localhost\", true);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.testing_localhost_is_secure_when_hijacked\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.failover_direct\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.allow_bypass\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.system_wpad\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.system_wpad.allowed\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.proxy.autoconfig_url\", \"\");\n")
    sb = sbAppend(sb, "user_pref(\"network.trr.mode\", 5);\n")
    sb = sbAppend(sb, "user_pref(\"network.dns.disabled\", true);\n")
    sb = sbAppend(sb, "user_pref(\"network.dns.disablePrefetch\", true);\n")
    sb = sbAppend(sb, "user_pref(\"network.dns.disablePrefetchFromHTTPS\", true);\n")
    sb = sbAppend(sb, "user_pref(\"network.dns.prefetch_via_proxy\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.prefetch-next\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.http.speculative-parallel-limit\", 0);\n")
    sb = sbAppend(sb, "user_pref(\"network.http.http3.enable\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.webtransport.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.webtransport.redirect.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.connectivity-service.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.captive-portal-service.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"browser.urlbar.speculativeConnect.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"browser.places.speculativeConnect.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"media.peerconnection.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"media.peerconnection.ice.proxy_only\", true);\n")
    sb = sbAppend(sb, "user_pref(\"media.navigator.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"geo.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.protocol-handler.external-default\", false);\n")
    sb = sbAppend(sb, "user_pref(\"network.protocol-handler.warn-external-default\", true);\n")
    sb = sbAppend(sb, "user_pref(\"network.protocol-handler.external.mailto\", false);\n")
    sb = sbAppend(sb, "user_pref(\"dom.security.https_only_mode\", false);\n")
    sb = sbAppend(sb, "user_pref(\"dom.security.https_only_mode_pbm\", false);\n")
    sb = sbAppend(sb, "user_pref(\"keyword.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"browser.fixup.domainsuffixwhitelist.i2p\", true);\n")
    sb = sbAppend(sb, "user_pref(\"browser.search.suggest.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"browser.urlbar.suggest.searches\", false);\n")
    sb = sbAppend(sb, "user_pref(\"browser.startup.homepage\", \"http://127.0.0.1:7657\");\n")
    sb = sbAppend(sb, "user_pref(\"browser.newtabpage.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"privacy.resistFingerprinting\", true);\n")
    sb = sbAppend(sb, "user_pref(\"privacy.resistFingerprinting.letterboxing\", true);\n")
    sb = sbAppend(sb, "user_pref(\"xpinstall.enabled\", false);\n")
    sb = sbAppend(sb, "user_pref(\"extensions.getAddons.showPane\", false);\n")
    sb = sbAppend(sb, "user_pref(\"extensions.htmlaboutaddons.recommendations.enabled\", false);\n")
    emit sbToString(sb)
}

func writeI2pProfilePrefs(profile) {
    let target = joinPath(profile, "user.js")
    let generated = i2pPrefs()
    let ownedMarker = "// Generated by Synapse. Dedicated I2P+ profile."

    if exists(target) == 1 {
        if !contains(readFile(target), ownedMarker) {
            fail("refusing to replace a user-owned I2P profile preference file: " + target)
        }
        if readFile(target) == generated { emit 1 }
    }

    let staged = joinPath(profile, ".user.js.synapse-tmp")
    writeFile(staged, generated)
    exec("chmod 600 " + quote(staged))
    exec("mv -f " + quote(staged) + " " + quote(target))
    emit 1
}

func i2pOpen(identityValue, destination) {
    let identity = i2pIdentity(identityValue)
    let startUrl = ""
    if destination == "home" {
        startUrl = "http://127.0.0.1:7657"
    } else if destination == "subscriptions" {
        startUrl = "http://127.0.0.1:7657/susidns/subscriptions"
    } else {
        fail("unknown I2P destination: " + destination + " (choose home or subscriptions)")
    }
    if i2pCheck() != 1 { emit 0 }

    let app = joinPath(objRoot(), "dist/Synapse.app")
    if isDir(app) != 1 || okCmd("test -x " + quote(joinPath(app, "Contents/MacOS/synapse"))) != 1 {
        fail("Synapse macOS app is missing; run tools/synapse-macos.ks build first")
    }

    let profile = joinPath(envValue("HOME"),
        "Library/Application Support/Synapse/Profiles/synapse-i2p-" + identity)
    exec("mkdir -p " + quote(profile))
    exec("chmod 700 " + quote(profile))
    writeI2pProfilePrefs(profile)

    print("Launching I2P " + identity + " with its isolated profile: " + profile)
    exec("open -n " + quote(app) + " --args -no-remote -profile " + quote(profile) + " " + quote(startUrl))
    emit 1
}

// ── usage and dispatch ───────────────────────────────────────────────
func usage() {
    print("Synapse macOS controller")
    print("  tools/synapse-macos.ks doctor")
    print("  tools/synapse-macos.ks i2p-settings")
    print("  tools/synapse-macos.ks i2p-check")
    print("  tools/synapse-macos.ks i2p-setup-check")
    print("  tools/synapse-macos.ks i2p-install-guide")
    print("  tools/synapse-macos.ks i2p-router-status")
    print("  tools/synapse-macos.ks i2p-router-start")
    print("  tools/synapse-macos.ks i2p-router-stop")
    print("  tools/synapse-macos.ks i2p-open [personal|work|school|creator|second-account] [home|subscriptions]")
    print("  tools/synapse-macos.ks apply")
    print("  tools/synapse-macos.ks build")
    print("  tools/synapse-macos.ks faster")
    print("  tools/synapse-macos.ks run")
    print("  tools/synapse-macos.ks package")
    print("  tools/synapse-macos.ks test-extension")
    print("  tools/synapse-macos.ks test-core")
    print("")
    print("Optional environment:")
    print("  SYNAPSE_FIREFOX_ROOT  Firefox source checkout (default: ~/mozilla-source/firefox)")
    print("  SYNAPSE_I2P_ROUTER_DIR I2P+ install directory (default: /Applications/i2p or ~/i2p)")
    print("  SYNAPSE_KCC           Krypton compiler binary (default: first kcc reporting a")
    print("                        Krypton version; /usr/bin/kcc is macOS Kerberos)")
}

func commandAt(index) {
    if toInt(argCount()) > index { emit arg(index) }
    emit ""
}

func main() {
    let command = commandAt(0)
    if command == "doctor" { doctor() }
    else if command == "i2p-settings" { i2pSettings() }
    else if command == "apply" { applyOverlay() }
    else if command == "build" { runMach("build", "build") }
    else if command == "faster" { runMach("faster", "build faster") }
    else if command == "run" { runMach("run", "run --no-remote") }
    else if command == "i2p-check" {
        if i2pCheck() != 1 { exit(1) }
    }
    else if command == "i2p-setup-check" { i2pSetupCheck() }
    else if command == "i2p-install-guide" { i2pInstallGuide() }
    else if command == "i2p-router-status" {
        if i2pRouterStatus() != "0" { exit(1) }
    }
    else if command == "i2p-router-start" { i2pRouterStart() }
    else if command == "i2p-router-stop" { i2pRouterStop() }
    else if command == "i2p-open" {
        let identity = commandAt(1)
        if len(identity) == 0 { identity = "personal" }
        let destination = commandAt(2)
        if len(destination) == 0 { destination = "home" }
        if i2pOpen(identity, destination) != 1 { exit(1) }
    }
    else if command == "package" {
        // Rebuild the repackaged chrome quickly, then produce the .app bundle.
        runMach("buildfaster", "build faster")
        runMach("package", "package")
    }
    else if command == "test-extension" {
        runMach("test-extension",
            "test browser/components/extensions/test/browser/browser_ext_browserAction_simple.js" +
            " --setpref dom.security.https_only_mode=false" +
            " --setpref dom.security.https_only_mode_pbm=false" +
            " --setpref network.lna.enabled=false" +
            " --setpref network.lna.blocking=false")
    }
    else if command == "test-core" { runCoreTests() }
    else if command == "-h" || command == "--help" || command == "" { usage() }
    else {
        usage()
        fail("unknown command: " + command)
    }
}

// `just run` keeps this file runnable under `kr` (which passes it straight
// through) and compilable with `kcc ... -o` (which needs an entry block).
just run {
    main()
}
