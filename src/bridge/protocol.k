module synapse_bridge_protocol

func bridgeEscape(value) {
    let escaped = replace(value, "\\", "\\\\")
    escaped = replace(escaped, "\"", "\\\"")
    escaped = replace(escaped, "\r", "\\r")
    escaped = replace(escaped, "\n", "\\n")
    emit escaped
}

func bridgeConfig(profilePath, runtimePath, initialMode) {
    emit "{\"abiVersion\":1,\"protocol\":\"synapse.bridge.v1\"," +
         "\"profilePath\":\"" + bridgeEscape(profilePath) + "\"," +
         "\"runtimePath\":\"" + bridgeEscape(runtimePath) + "\"," +
         "\"initialContext\":\"" + bridgeEscape(initialMode) + "\"}"
}

func bridgeCreateTab(requestId, mode) {
    emit "{\"type\":\"tab.create\",\"requestId\":\"" +
         bridgeEscape(requestId) + "\",\"context\":\"" +
         bridgeEscape(mode) + "\"}"
}

func bridgeNavigate(requestId, tabId, url) {
    emit "{\"type\":\"tab.navigate\",\"requestId\":\"" +
         bridgeEscape(requestId) + "\",\"tabId\":\"" +
         bridgeEscape(tabId) + "\",\"url\":\"" +
         bridgeEscape(url) + "\"}"
}

func bridgeHistory(requestId, tabId, direction) {
    emit "{\"type\":\"tab.history\",\"requestId\":\"" +
         bridgeEscape(requestId) + "\",\"tabId\":\"" +
         bridgeEscape(tabId) + "\",\"direction\":\"" +
         bridgeEscape(direction) + "\"}"
}

func bridgeReload(requestId, tabId) {
    emit "{\"type\":\"tab.reload\",\"requestId\":\"" +
         bridgeEscape(requestId) + "\",\"tabId\":\"" +
         bridgeEscape(tabId) + "\"}"
}

func bridgeSetContext(requestId, tabId, mode) {
    emit "{\"type\":\"tab.context\",\"requestId\":\"" +
         bridgeEscape(requestId) + "\",\"tabId\":\"" +
         bridgeEscape(tabId) + "\",\"context\":\"" +
         bridgeEscape(mode) + "\"}"
}
