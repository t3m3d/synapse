# Synapse engine workspace

First milestone uses a normal Firefox Desktop application build. This preserves
working Gecko integration, multiprocess sandboxing, accessibility, media, and
Firefox WebExtensions while Synapse branding and privacy policy are added.

`C:\mozilla-source\firefox` is the local upstream checkout. It stays separate
from this overlay repository so Mozilla history and build artifacts do not
swamp Synapse-owned code.

Later milestones add the versioned adapter declared in
`bridge/include/synapse_gecko.h`, then move suitable product services into
Krypton. Engine code remains C++/Rust where Gecko requires it.

No Firefox branding, Mozilla service credentials, telemetry identifiers, or
official update endpoints may ship in a Synapse release.
