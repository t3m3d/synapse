// Website edition: one opt-in, signed I2P+ component. This trust root is
// provisioned at release build time, never fetched from the component server.
module synapse_i2p_component

import "head:posix"

func i2pComponentFeed() {
    emit "https://krypton-lang.org/synapse/components/i2p/macos-arm64"
}

func componentQuote(value) {
    let q = fromCharCode(39)
    let escaped = q + fromCharCode(92) + q + q
    emit q + replace(value, q, escaped) + q
}

func componentOk(command) {
    if shellRun("( " + command + " ) >/dev/null 2>&1") == "0" { emit 1 }
    emit 0
}

func componentFail(message) {
    printErr("I2P+ component: " + message + "\n")
    emit 0
}

func componentDigits(value, maxWidth) {
    if len(value) == 0 || len(value) > maxWidth { emit 0 }
    if value[0] == "0" { emit 0 }
    let i = 0
    while i < len(value) {
        if contains("0123456789", value[i]) != 1 { emit 0 }
        i += 1
    }
    emit 1
}

func componentHashText(value) {
    if len(value) != 64 { emit 0 }
    let i = 0
    while i < len(value) {
        if contains("0123456789abcdef", value[i]) != 1 { emit 0 }
        i += 1
    }
    emit 1
}

func componentFileSize(path) {
    emit getLine(exec("/usr/bin/stat -f %z " + componentQuote(path) + " 2>/dev/null"), 0)
}

func componentVerifyMetadata(key, manifest, signature) {
    let size = componentFileSize(manifest)
    let sigSize = componentFileSize(signature)
    if componentDigits(size, 4) != 1 || toInt(size) > 4096 ||
       componentDigits(sigSize, 4) != 1 || toInt(sigSize) > 1024 {
        componentFail("invalid manifest or signature size")
        emit ""
    }
    if componentOk("/usr/bin/openssl dgst -sha256 -verify " + componentQuote(key) +
        " -signature " + componentQuote(signature) + " " + componentQuote(manifest)) != 1 {
        componentFail("manifest signature verification failed")
        emit ""
    }
    let data = readFile(manifest)
    if lineCount(data) != 5 || getLine(data, 0) != "synapse-i2p-macos-arm64-v1" {
        componentFail("unexpected manifest format or platform")
        emit ""
    }
    let sequence = getLine(data, 1)
    let expiry = getLine(data, 2)
    let hash = getLine(data, 3)
    let bytes = getLine(data, 4)
    if componentDigits(sequence, 9) != 1 || componentDigits(expiry, 10) != 1 ||
        len(expiry) != 10 || componentHashText(hash) != 1 ||
        componentDigits(bytes, 9) != 1 || toInt(bytes) > 268435456 {
        componentFail("invalid manifest fields")
        emit ""
    }
    // Date arithmetic stays in macOS's 64-bit shell. Metadata must be fresh
    // and short lived even when the server replays a correctly signed file.
    let now = getLine(exec("/bin/date -u +%s"), 0)
    if componentDigits(now, 10) != 1 ||
       componentOk("test " + expiry + " -gt " + now +
        " && test " + expiry + " -le $((" + now + " + 1209600))") != 1 {
        componentFail("manifest expired or valid for more than 14 days")
        emit ""
    }
    emit data
}

func componentCurrent(root) {
    let path = root + "/current"
    let quoted = componentQuote(path)
    if componentOk("test -f " + quoted + " && test ! -L " + quoted) != 1 { emit "" }
    emit getLine(readFile(path), 0)
}

func componentHasSelection(root) {
    let path = componentQuote(root + "/current")
    emit componentOk("test -e " + path + " || test -L " + path)
}

func componentRouterApp(root, sequence) {
    emit root + "/versions/" + sequence + "/SynapseI2PRouter.app"
}

func componentRouterTool(root, sequence) {
    emit componentRouterApp(root, sequence) + "/Contents/MacOS/i2p-router"
}

func componentCheckApp(app) {
    let tool = app + "/Contents/MacOS/i2p-router"
    if componentOk("test -x " + componentQuote(tool)) != 1 { emit 0 }
    emit componentOk("/usr/bin/codesign --verify --deep --strict " + componentQuote(app))
}

func componentRouterExit(root, action) {
    let sequence = componentCurrent(root)
    if componentDigits(sequence, 9) != 1 {
        componentFail("invalid active router selection")
        emit "2"
    }
    if componentCheckApp(componentRouterApp(root, sequence)) != 1 {
        componentFail("active router bundle is missing or its signature is invalid")
        emit "2"
    }
    // Fixed action names only. The bundle owns its process, readiness checks
    // and state directory; never substitute an unrelated listening proxy.
    if action != "status" && action != "start" && action != "stop" && action != "ready" {
        componentFail("unsupported router action")
        emit "2"
    }
    emit shellRun(componentQuote(componentRouterTool(root, sequence)) + " " + action +
        " " + componentQuote(root + "/router-data"))
}

func componentRouterCommand(root, action) {
    if componentRouterExit(root, action) == "0" { emit 1 }
    emit 0
}

func componentChangeRouter(root, action) {
    let lock = componentLock(root)
    if lock < 0 { emit 0 }
    let ok = componentRouterCommand(root, action)
    close(lock)
    emit ok
}

func componentMayInstall(root, data) {
    let seq = getLine(data, 1)
    if componentHasSelection(root) != 1 { emit 1 }
    let current = componentCurrent(root)
    if componentDigits(current, 9) != 1 { emit componentFail("invalid active router selection") }
    if toInt(seq) < toInt(current) { emit componentFail("downgrade rejected") }
    if seq == current {
        let receipt = root + "/versions/" + seq + "/manifest.v1"
        if componentOk("test -f " + componentQuote(receipt)) != 1 {
            emit componentFail("active router receipt is missing")
        }
        if getLine(readFile(receipt), 3) != getLine(data, 3) {
            emit componentFail("same version has a different package hash")
        }
        if componentCheckApp(componentRouterApp(root, seq)) != 1 {
            emit componentFail("active router bundle is damaged")
        }
        print("I2P+ component is current (sequence " + seq + ").")
        emit 2
    }
    // Only a verified managed runner can say that it is stopped. Exit 3 is
    // the package protocol's explicit stopped status, not a generic failure.
    let status = componentRouterExit(root, "status")
    if status != "3" { emit componentFail("stop the managed router before updating") }
    emit 1
}

func componentApplyArchive(root, stage, data, archive) {
    let seq = getLine(data, 1)
    let expected = getLine(data, 3)
    if componentFileSize(archive) != getLine(data, 4) { emit componentFail("package size mismatch") }
    let actual = getLine(exec("/usr/bin/shasum -a 256 " + componentQuote(archive)), 0)
    if len(actual) < 64 || substring(actual, 0, 64) != expected { emit componentFail("package hash mismatch") }

    let content = stage + "/content"
    if componentOk("/bin/mkdir " + componentQuote(content)) != 1 {
        emit componentFail("could not create extraction directory")
    }
    // macOS libarchive defaults reject dot-dot paths and symlink traversal.
    // No -P, no owner/permission restoration. Archive bytes are already
    // authenticated before extraction; only the expected app is activated.
    if componentOk("/usr/bin/tar --no-same-owner --no-same-permissions -xzf " +
        componentQuote(archive) + " -C " + componentQuote(content)) != 1 {
        emit componentFail("package extraction failed")
    }
    if componentOk("test -z \"$(/usr/bin/find " + componentQuote(content) +
        " ! -type f ! -type d -print -quit)\" && test -z \"$(/usr/bin/find " + componentQuote(content) +
        " -mindepth 1 -maxdepth 1 ! -name SynapseI2PRouter.app -print -quit)\"") != 1 {
        emit componentFail("unexpected package layout")
    }
    if componentCheckApp(content + "/SynapseI2PRouter.app") != 1 {
        emit componentFail("router bundle signature verification failed")
    }
    writeFile(content + "/manifest.v1", data)
    writeFile(stage + "/current", seq + "\n")
    if readFile(content + "/manifest.v1") != data || componentCurrent(stage) != seq {
        emit componentFail("could not write component receipt")
    }

    let target = root + "/versions/" + seq
    // A crash between the two renames can leave this version staged. It
    // was never active and may be replaced with the newly verified copy.
    if componentOk("/bin/rm -rf " + componentQuote(target) +
        " && /bin/mv " + componentQuote(content) + " " + componentQuote(target)) != 1 {
        emit componentFail("could not stage the version; active router unchanged")
    }
    if componentOk("/bin/mv -f " + componentQuote(stage + "/current") +
        " " + componentQuote(root + "/current")) != 1 {
        emit componentFail("could not activate the version; active router unchanged")
    }
    print("Verified I2P+ component installed (sequence " + seq + "). Start the router when ready.")
    emit 1
}

func componentCurl(url, target, limit, seconds) {
    // Ignore ~/.curlrc and do not follow redirects to another origin.
    emit componentOk("/usr/bin/curl -q --proto '=https' --tlsv1.2 --fail --silent --show-error" +
        " --connect-timeout 10 --max-time " + seconds + " --max-filesize " + limit +
        " --output " + componentQuote(target) + " " + componentQuote(url))
}

func componentFetch(root, stage, key) {
    let base = i2pComponentFeed()
    let manifest = stage + "/manifest.v1"
    let signature = stage + "/manifest.sig"
    let archive = stage + "/router.tar.gz"
    if componentCurl(base + "/manifest.v1", manifest, "4096", "25") != 1 ||
       componentCurl(base + "/manifest.sig", signature, "1024", "25") != 1 {
        emit componentFail("release feed unavailable; active router unchanged")
    }
    let data = componentVerifyMetadata(key, manifest, signature)
    if len(data) == 0 { emit 0 }
    let allowed = componentMayInstall(root, data)
    if allowed == 2 { emit 1 }
    if allowed != 1 { emit 0 }
    if componentCurl(base + "/i2p-" + getLine(data, 1) + ".tar.gz", archive,
        getLine(data, 4), "240") != 1 {
        emit componentFail("package download failed; active router unchanged")
    }
    emit componentApplyArchive(root, stage, data, archive)
}

// An advisory Darwin lock belongs to this file descriptor. macOS releases
// it on process exit, including a crash. Keep the file to preserve its inode.
func componentLock(root) {
    let path = root + "/.operation.lock"
    if componentOk("umask 077 && /bin/mkdir -p " + componentQuote(root + "/versions") +
        " && /bin/chmod 700 " + componentQuote(root) + " && /usr/bin/touch " + componentQuote(path)) != 1 {
        componentFail("component directory unavailable")
        emit -1
    }
    let closeOnExec = 16777216
    let noFollow = 256
    let exclusiveLock = 32
    let nonBlocking = 4
    let fd = open(path, closeOnExec + noFollow + exclusiveLock + nonBlocking)
    // Reject -1 in either its signed or zero-extended Darwin int form.
    if fd < 0 || fd == 65535 * 65537 {
        componentFail("router or update command already running, or lock unavailable")
        emit -1
    }
    emit fd
}

func componentInstall(root, key) {
    if componentOk("test -f " + componentQuote(key)) != 1 {
        emit componentFail("this build has no release verification key")
    }
    let lock = componentLock(root)
    if lock < 0 { emit 0 }
    let stage = getLine(exec("/usr/bin/mktemp -d " +
        componentQuote(root + "/.update.XXXXXXXX")), 0)
    let ok = 0
    if startsWith(stage, root + "/.update.") == 1 {
        ok = componentFetch(root, stage, key)
        shellRun("/bin/rm -rf " + componentQuote(stage))
    } else {
        componentFail("could not create private staging directory")
    }
    close(lock)
    emit ok
}
