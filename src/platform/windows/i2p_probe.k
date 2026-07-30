module synapse_i2p_windows

import "../../core/i2p.k"

func i2pProbeQuote(value) {
    emit fromCharCode(34) + value + fromCharCode(34)
}

func i2pProbeTrim(value) {
    let end = len(value)
    while end > 0 {
        let code = charCode(value[end - 1])
        if code == 10 || code == 13 || code == 32 || code == 9 { end -= 1 }
        else { break }
    }
    emit substring(value, 0, end)
}

// Krypton owns the readiness policy; Windows PowerShell supplies only the
// loopback TCP primitive while direct Winsock calls remain unstable in the
// current host. This does not authenticate I2P+ or prove router bootstrap.
func i2pProxyReady() {
    let host = i2pProxyHost()
    let port = i2pProxyPort()
    let sentinel = "__SYNAPSE_I2P_READY__"
    let script = "$client=[Net.Sockets.TcpClient]::new(); try { "
    script = script + "$task=$client.ConnectAsync('" + host + "'," + port + "); "
    script = script + "if ($task.Wait(1500) -and $client.Connected) { "
    script = script + "[Console]::Out.WriteLine('__SYNAPSE_I2P_'+'READY__') } "
    script = script + "} catch {} finally { $client.Dispose() }"
    let powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    let command = powershell + " -NoLogo -NoProfile -NonInteractive -Command "
    command = command + i2pProbeQuote(script)
    let output = i2pProbeTrim(exec(command))
    if contains(output, sentinel) { emit "1" }
    emit "0"
}
