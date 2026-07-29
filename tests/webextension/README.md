# Firefox WebExtension compatibility probe

This deliberately ordinary Manifest V3 Firefox WebExtension exercises the
existing Gecko extension runtime, a toolbar action, background script,
message passing, popup UI, and local extension storage.

It is a test fixture, not a privileged Synapse component. Load it temporarily
from `about:debugging#/runtime/this-firefox` during manual checks. Automated
engine checks run Mozilla's own browser-extension tests against the Synapse
build.
