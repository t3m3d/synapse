// The fixture generator supplies signed metadata and a harmless router bundle.
import "../src/platform/macos/i2p_component.k"

func expectComponent(actual, expected, label) {
    if actual != expected {
        printErr("FAIL " + label + ": expected " + expected + ", got " + actual)
        exit(1)
    }
    emit 1
}

func runComponentTests() {
    print("Testing signed I2P+ fixtures…")
    let fixture = arg(0)
    let key = fixture + "/public.pem"
    let root = fixture + "/installed"
    let manifest = fixture + "/manifest.v1"
    let signature = fixture + "/manifest.sig"
    let archive = fixture + "/router.tar.gz"
    let data = componentVerifyMetadata(key, manifest, signature)
    expectComponent(getLine(data, 1), "2", "valid signed metadata")
    expectComponent(componentVerifyMetadata(fixture + "/wrong.pem", manifest, signature), "", "wrong key")
    expectComponent(componentVerifyMetadata(key, fixture + "/changed.v1", signature), "", "changed metadata")
    expectComponent(componentVerifyMetadata(key, fixture + "/expired.v1", fixture + "/expired.sig"), "", "expired metadata")
    expectComponent(componentInstall(root, fixture + "/missing.pem"), 0, "no unprovisioned download")
    let lock = componentLock(root)
    expectComponent(lock >= 0, 1, "acquire operation lock")
    expectComponent(componentLock(root), -1, "a second operation cannot acquire the lock")
    close(lock)
    let retried = componentLock(root)
    expectComponent(retried >= 0, 1, "retry can acquire a released lock")
    close(retried)
    expectComponent(componentMayInstall(root, data), 1, "first install allowed")
    expectComponent(componentApplyArchive(root, fixture + "/bad-stage", data, fixture + "/changed.tar.gz"),
        0, "modified archive rejected")
    expectComponent(componentHasSelection(root), 0, "no selection after failed install")
    expectComponent(componentApplyArchive(root, fixture + "/stage", data, archive), 1, "valid archive installed")
    expectComponent(componentCurrent(root), "2", "active sequence")
    expectComponent(componentMayInstall(root, data), 2, "identical package is current")
    let prefix = getLine(data, 0) + "\n"
    let expiry = getLine(data, 2)
    let hash = getLine(data, 3)
    let bytes = getLine(data, 4)
    expectComponent(componentMayInstall(root, prefix + "1\n" + expiry + "\n" + hash + "\n" + bytes),
        0, "downgrade rejected")
    expectComponent(componentMayInstall(root, prefix + "2\n" + expiry + "\n" + replace(hash, "a", "z") + "x\n" + bytes),
        0, "different hash at current sequence rejected")
    let next = prefix + "3\n" + expiry + "\n" + hash + "\n" + bytes
    expectComponent(componentMayInstall(root, next), 1, "update allowed while router is stopped")
    expectComponent(componentRouterCommand(root, "ready"), 0, "stopped runner is not ready")
    expectComponent(componentChangeRouter(root, "start"), 1, "managed runner starts")
    expectComponent(componentMayInstall(root, next), 0, "running router blocks replacement")
    expectComponent(componentRouterCommand(root, "ready"), 1, "started runner is ready")
    expectComponent(componentChangeRouter(root, "stop"), 1, "managed runner stops")
    expectComponent(componentApplyArchive(root, fixture + "/next-stage", next, fixture + "/changed.tar.gz"),
        0, "failed update rejected")
    expectComponent(componentCurrent(root), "2", "failed update preserves active version")
    expectComponent(componentApplyArchive(root, fixture + "/next-stage", next, archive), 1, "verified update activated")
    expectComponent(componentCurrent(root), "3", "new active sequence")
    expectComponent(componentOk("/bin/mv " + componentQuote(root + "/current") + " " +
        componentQuote(root + "/saved") + " && /bin/ln -s missing " + componentQuote(root + "/current")),
        1, "create broken selection fixture")
    expectComponent(componentHasSelection(root), 1, "broken selection does not select the manual router")
    expectComponent(componentRouterCommand(root, "ready"), 0, "broken selection blocks managed browsing")
    print("macOS I2P+ component tests passed.")
}

just run { runComponentTests() }
