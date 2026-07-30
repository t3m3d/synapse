module synapse_browser_spawn_windows

import "k:base64"
import "head:windows"

func _synapseSpawnQuote(value) {
    emit fromCharCode(34) + value + fromCharCode(34)
}

func _synapseSpawnDirectory(path) {
    let index = len(path) - 1
    while index >= 0 {
        if path[index] == "\\" || path[index] == "/" {
            emit substring(path, 0, index)
        }
        index -= 1
    }
    emit ""
}

// Keep the outer command ASCII-only, carry every dynamic UTF-8 value as
// base64, then let .NET use the Unicode Windows shell API.
func windowsStartDetached(executable, arguments, workingDirectory) {
    if len(executable) == 0 || len(workingDirectory) == 0 { emit "0" }

    let executable64 = b64Encode(executable)
    let arguments64 = b64Encode(arguments)
    let workingDirectory64 = b64Encode(workingDirectory)
    let sentinel = "__SYNAPSE_BROWSER_STARTED__"

    let script = "$utf8=[Text.Encoding]::UTF8;"
    script = script + "$exe=$utf8.GetString([Convert]::FromBase64String('" + executable64 + "'));"
    script = script + "$arguments=$utf8.GetString([Convert]::FromBase64String('" + arguments64 + "'));"
    script = script + "$cwd=$utf8.GetString([Convert]::FromBase64String('" + workingDirectory64 + "'));"
    script = script + "$psi=[Diagnostics.ProcessStartInfo]::new();"
    script = script + "$psi.FileName=$exe;"
    script = script + "$psi.Arguments=$arguments;"
    script = script + "$psi.WorkingDirectory=$cwd;"
    script = script + "$psi.UseShellExecute=$true;"
    script = script + "$process=[Diagnostics.Process]::Start($psi);"
    script = script + "if ($null -ne $process) {[Console]::Out.Write('__SYNAPSE_BROWSER_'+'STARTED__')}"

    let powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    let command = powershell + " -NoLogo -NoProfile -NonInteractive -Command "
    command = command + _synapseSpawnQuote(script)
    if contains(exec(command), sentinel) { emit "1" }
    emit "0"
}

// Run a bounded command-line helper without cmd.exe parsing dynamic values.
// The returned text includes stdout/stderr followed by a private exit marker.
func windowsRunCapture(executable, arguments, workingDirectory) {
    if len(executable) == 0 || len(workingDirectory) == 0 { emit "" }

    let executable64 = b64Encode(executable)
    let arguments64 = b64Encode(arguments)
    let workingDirectory64 = b64Encode(workingDirectory)

    let script = "$utf8=[Text.Encoding]::UTF8;"
    script = script + "$exe=$utf8.GetString([Convert]::FromBase64String('" + executable64 + "'));"
    script = script + "$arguments=$utf8.GetString([Convert]::FromBase64String('" + arguments64 + "'));"
    script = script + "$cwd=$utf8.GetString([Convert]::FromBase64String('" + workingDirectory64 + "'));"
    script = script + "$psi=[Diagnostics.ProcessStartInfo]::new();"
    script = script + "$psi.FileName=$exe;"
    script = script + "$psi.Arguments=$arguments;"
    script = script + "$psi.WorkingDirectory=$cwd;"
    script = script + "$psi.UseShellExecute=$false;"
    script = script + "$psi.CreateNoWindow=$true;"
    script = script + "$psi.RedirectStandardOutput=$true;"
    script = script + "$psi.RedirectStandardError=$true;"
    script = script + "$process=[Diagnostics.Process]::Start($psi);"
    script = script + "$stdout=$process.StandardOutput.ReadToEnd();"
    script = script + "$stderr=$process.StandardError.ReadToEnd();"
    script = script + "$process.WaitForExit();"
    script = script + "[Console]::Out.Write($stdout+$stderr+'__SYNAPSE_PROCESS_EXIT__'+$process.ExitCode)"

    let powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    let command = powershell + " -NoLogo -NoProfile -NonInteractive -Command "
    command = command + _synapseSpawnQuote(script)
    emit exec(command)
}

func windowsRunSucceeded(output) {
    emit contains(output, "__SYNAPSE_PROCESS_EXIT__0")
}

func startSynapseBrowser(browser, profile, mode) {
    let arguments = "-no-remote -profile " + _synapseSpawnQuote(profile)
    if mode == "i2p" { arguments = arguments + " about:blank" }

    SetEnvironmentVariableA("MOZ_CRASHREPORTER_NO_REPORT", "1")
    emit windowsStartDetached(browser, arguments, _synapseSpawnDirectory(browser))
}
