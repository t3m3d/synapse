# Objective-K / macOS compiler: handoff for fixes

Scope: `krypton` repo. Everything below was reproduced on macOS 27.2 (arm64) with
`/usr/local/bin/kcc` **2.4.8**, repo at `30e8f216`.

Why it matters to Synapse: Synapse's macOS surface is now KryptScript end to end
(`tools/synapse-macos.ks` controller + `src/control/i2p_settings.ks` Objective-K
GUI). Three workarounds exist in Synapse *only* because of the gaps below, and can
be deleted once the compiler/stdlib behaves as documented.

Each item is: symptom, evidence, where, fix, acceptance check. Items marked
**DOC-ONLY** need no compiler change.

---

## P0 — correctness bugs that silently lie

### 1. `exec()` and `shellRun()` are documented with each other's semantics

`docs/spec/functions.md:453` says:

> `exec(cmd)` — execute and return exit code.

It returns **stdout**, and the exit code is discarded. Reproduced:

```krypton
just run {
    let a = exec("printf hi; exit 7")
    kp("exec_returns=[" + a + "]")        // exec_returns=[hi]
}
```

`docs/spec/functions.md:118` says the opposite of what `shellRun` does:

> `### shellRun(cmd) — (C path)` / "Runs `cmd` via the system shell; returns the
> captured stdout."

`shellRun` returns the **exit code as a string** and does **not** capture stdout —
the child inherits the parent's stdout. Reproduced:

```krypton
just run {
    kp("rc7=[" + shellRun("exit 7") + "]")                    // rc7=[7]
    kp("rc1=[" + shellRun("false") + "]")                     // rc1=[1]
    kp("rc3=[" + shellRun("echo CHILD_SAYS_HI; exit 3") + "]")// CHILD_SAYS_HI then rc3=[3]
}
```

Two consequences worth fixing, not just documenting:

- **No single call returns both output and status.** Callers either re-run the
  command or smuggle the code through stdout with a sentinel. Synapse shipped a
  `__SYNAPSE_EXIT__` sentinel for this reason before switching to `shellRun` plus
  a temp file. A `runCaptured(cmd)` returning `"<code>\n<stdout+stderr>"` would
  delete the whole class of workaround.
- **`shellRun` cannot be used for GUI output**: the child writes to the app's
  inherited stdout, which a windowed app does not show.

Acceptance: docs match observed behaviour; if `runCaptured` is added, both facts
above are covered by a test that asserts code *and* body for a command that
prints to stdout and stderr and exits non-zero.

### 2. `stdlib/os.k` `ossystemk()` always reports success

`stdlib/os.k:173-178`:

```krypton
// os.system(cmd) -- run via shell, return exit code (best-effort).
func ossystemk(cmd) {
    exec(cmd)
    emit "0"
}
```

It discards the status and hardcodes `"0"`, so `os.system()` claims success even
when the command fails. Fix: `emit shellRun(cmd)` (verified available on macOS,
Linux, FreeBSD, Windows x64).

Related, lower priority: `stdlib/sh.k:42-44` `shOk()` still uses the
`( cmd ) >/dev/null 2>&1 && echo 1 || echo 0` sentinel; `shellRun` gives the
status directly.

Acceptance: `os.system("false")` returns `"1"`; `os.system("true")` returns `"0"`.

### 3. Missing newlines glue compiler diagnostics onto program output

`compiler/macos_arm64/macho_arm64_self.k:7527` and `:7692` both `printErr(...)`
without a trailing newline:

```text
objk: 9 foreign sym(s) [_objc_getClass _sel_registerName _objc_msgSend ...] across 3 dylib(s)macho_arm64_self: wrote /tmp/bid (49832 bytes, ad-hoc signed)
```

Observed verbatim when compiling any `k:okui` app. It also breaks `diff`-based
comparisons of build output. Fix: append `"\n"` at both sites.

---

## P1 — process API parity (the real reason macOS cannot be "all Krypton")

macOS has **no argv-based spawn with an exit status**. Both `exec` and `shellRun`
are `/bin/sh -c` string commands, so every argument has to be shell-quoted by
hand, and quoting bugs become shell injection.

Evidence:

- `stdlib/proc.k:17-19` imports `head:windows` only — `procSpawn`/`procRead`/
  `procAlive` are Windows-only, despite the platform-neutral name.
- `headers/posix.krh` (whole file) declares `fork`, `execl`, `_exit`, pty helpers —
  but **no `waitpid`**, so `fork`+`execl` cannot yield a status either.
- `stdlib/process_win.k` / `process_win_argv.k` exist for Windows argv building;
  there is no macOS counterpart.
- `stdlib/os.k` itself carries the TODO: "the planned `winRun` CreateProcess-based
  replacement that kills the shell-quoting tax."

Options, smallest first:

1. Add `waitpid`/`WEXITSTATUS` to `headers/posix.krh` — unblocks spawn+wait in
   userland without touching codegen.
2. Port `k:proc` to macOS on top of `fork`/`execve`/`pipe`.
3. Add a native `runArgv(args) -> code` builtin and make `shellRun` a thin
   wrapper over it.

Blocking prerequisite: `spec.md` records that macOS **skips `test_bytes.k` and
`test_process_win_argv.k` because `ptrAdd`/`ptrToInt` are not emitted there**
(confirmed: no `ptrAdd`/`ptrToInt` anywhere in `macho_arm64_self.k`). Pointer
arithmetic has to land on macOS before argv marshalling does.

Acceptance: a macOS program spawns `["/bin/echo", "a b"]` without a shell, gets
`a b` and status 0; a second run against a non-zero exit returns that code; no
`sh` in the process tree (`ps` check in the test).

---

## P2 — app bundling is undocumented and hardcoded to the Krypton tree

`kcc` emits a bare Mach-O. macOS gives a bare binary **no bundle identity**: no
`Info.plist`, no `CFBundleIdentifier`, and the menu bar names the executable
path. Krypton's own Objective-K apps are wrapped by `scripts/build-objk-app.ks`,
but that script cannot be reused by another project:

- `scripts/build-objk-app.ks:18-19` takes only `<source.ks> [appName]`; the repo
  root is `pwd`, and output is hardcoded to `<root>/dist/<name>.app` (`:46`).
- It requires a **source checkout** (`compiler/macos_arm64/kcc-arm64`,
  `macho_host`, `bootstrap/…`, `:21-44`), so it does not work against an
  installed `kcc`. `/usr/local/bin/kcc --help` has no `--bundle`/plist flag at
  all.
- `CFBundleIconFile` is emitted unconditionally (`:88`) while the icon is copied
  only if a file happens to exist (`:96-102`) → dangling icon reference; the
  lookup is magic-path only (`<src dir>/<name>.icns`, else
  `examples/objk/<name>.icns`).
- `codesign` is invoked unguarded and its output discarded (`:104`).
- No `--out`, no `--bundle-id`, no version argument (`CFBundleVersion` comes from
  `kcc --version`).

Suggested fix, in order of payoff:

1. `kcc --bundle <source.ks> --name X --id org.example.x --out <dir>` producing
   `Contents/MacOS/<exec>`, `Contents/Info.plist`, optional icon, ad-hoc seal.
2. Otherwise expose plist generation as a stdlib function so projects do not
   hand-roll XML (Synapse hand-rolled it; see `tools/synapse-macos.ks`,
   `objkPlist`/`buildObjkApp`).
3. Make `build-objk-app.ks` accept `--out`/`--id` and work from any cwd.

Acceptance: a project outside the Krypton tree builds a runnable `.app` with
`kcc` alone; `plutil -lint` passes; `codesign -dv` reports
`Format=app bundle`; launching the bundle's executable shows the display name
from the plist rather than the binary name.

Note for whoever edits `okui` apps: run the bundle's executable **directly**
rather than via `open` if the app reads environment variables — `open` goes
through LaunchServices and does not forward the caller's environment.

---

## P3 — Objective-K language and docs

### 4. Declarations cannot live in imported modules

`docs/objk_runtime_macos.md:44-46`: "Declarations currently belong in executable
entry source; imported modules should use direct APIs."

So `objk protocol`/`objk object` blocks cannot be reused across files, and any
project with more than one GUI/shared module falls back to the `okK*` runtime
calls by hand. This is the single biggest obstacle to reusable Objective-K
libraries.

Acceptance: an imported `.ks` module containing `objk object` compiles and
dispatches when imported by an entry program.

### 5. No id → text helper in `k:objc`

`stdlib/objc.k` provides `nsString(s)` (text → `NSString`) but nothing in the
reverse direction; `stdlib/cocoa.k` handles its own cases with
`msg(s, "UTF8String")`. Concatenating a returned object pointer into a string
yields garbage rather than an error:

```krypton
import "k:objc"
just run {
    let b = msg(cls("NSBundle"), sel("mainBundle"))
    kp("bundleIdentifier=[" + msg(b, sel("bundleIdentifier")) + "]")  // bundleIdentifier=[0]
}
```

The working idiom is `msg(msg(obj, sel("description")), sel("UTF8String"))`. A
documented `nsToStr(obj)` helper, and a doc note that `msg` returns a raw
pointer, would prevent this trap.

### 6. "No libobjc" is true of the object core, not of `okui` apps

`spec.md:73` states "No Cocoa, Foundation, AppKit, UIKit, or libobjc imports
belong to this core", and `docs/objk_runtime_macos.md` opens with "It does not
import Cocoa, UIKit, Foundation, or `libobjc`".

Both are accurate about `stdlib/objk_runtime_macos.k`. But every `k:okui` app
takes the other path — `stdlib/okui.k:5-11` imports `head:objc`, `head:cocoa`,
`k:objc`, `k:choc_macos` — and links dynamically against `libobjc`:

```text
objk: 9 foreign sym(s) [_objc_getClass _sel_registerName _objc_msgSend
_objc_lookUpClass _objc_allocateClassPair _class_addMethod
_objc_registerClassPair _objc_setAssociatedObject _objc_getAssociatedObject]
across 3 dylib(s)
```

Consequence for shipping: a `k:okui` app is **not** static, requires those
dylibs at runtime, and needs (at least) ad-hoc signing. Callers reading "no
libobjc" reasonably assume otherwise. Suggested doc wording: distinguish
"pure-Krypton source, no Objective-C source files" from "no Objective-C
framework linkage", and say which layer an app is on.

---

## Already worked around in Synapse (delete when fixed)

| Workaround in Synapse | Exists because | Delete when |
|---|---|---|
| `objkPlist` + `buildObjkApp` in `tools/synapse-macos.ks` | no `kcc --bundle`, bundler is Krypton-tree-bound (P2) | kcc grows a bundle flag |
| `runMarked`/`runSettingsTool` capture output via `mktemp` + `shellRun` | no call returns output *and* status (P0.1) | `runCaptured`-style builtin lands |
| shell-quoting (`quote`, `settingsShellQuote`) on every path | no argv spawn on macOS (P1) | argv spawn + `ptrAdd` on macOS |
| `__SYNAPSE_EXIT__` sentinel (now removed) | same as P0.1 | already gone |

## Do not regress the following (verified working today)

- `shellRun` on macOS: `exit 7`→`7`, `true`→`0`, `false`→`1`, exit 3→`3`.
- `kcc` ad-hoc signs emitted binaries; compiling an `okui` app succeeds and
  reports the 9 foreign symbols above.
- `k:okui` route `head:objc`/`head:cocoa` → `k:objc`/`k:choc_macos` → AppKit.
- Existing `exec` returns stdout verbatim including the trailing newline.

## Reproduction commands

```sh
# exec vs shellRun semantics (P0.1)
/usr/local/bin/kcc /tmp/exprobe.ks -o /tmp/exprobe && /tmp/exprobe
/usr/local/bin/kcc /tmp/srprobe.ks -o /tmp/srprobe && /tmp/srprobe

# os.system status bug (P0.2)      -> prints 0 for a failing command
printf 'import "k:os"\njust run { kp(ossystemk("false")) }\n' > /tmp/sys.ks
/usr/local/bin/kcc /tmp/sys.ks -o /tmp/sys && /tmp/sys

# bundled vs bare identity (P2)    -> bare binary has no plist to read
/usr/local/bin/kcc src/app.ks -o /tmp/app   # bare: no Info.plist anywhere
```

Bodies for the first two probes are inline in P0.1 above.
