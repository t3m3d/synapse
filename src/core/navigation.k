module synapse_navigation

func navigationHasScheme(value) {
    emit startsWith(value, "https://") ||
         startsWith(value, "http://") ||
         startsWith(value, "synapse://") ||
         startsWith(value, "about:")
}

func navigationIsUnsafe(value) {
    emit startsWith(value, "javascript:") ||
         startsWith(value, "data:") ||
         startsWith(value, "chrome:") ||
         startsWith(value, "resource:") ||
         startsWith(value, "file:")
}

func navigationLooksLikeHost(value) {
    emit contains(value, ".") && !contains(value, " ")
}

func normalizeNavigation(raw) {
    let value = trim(raw)
    if len(value) == 0 { emit "synapse://newtab" }
    if navigationIsUnsafe(value) { emit "synapse://blocked" }
    if navigationHasScheme(value) { emit value }
    if navigationLooksLikeHost(value) { emit "https://" + value }
    emit "synapse://search?q=" + value
}

func navigationAllowedInBlackout(url) {
    emit startsWith(url, "https://") || startsWith(url, "synapse://")
}
