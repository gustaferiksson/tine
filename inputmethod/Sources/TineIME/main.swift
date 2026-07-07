import Cocoa
import InputMethodKit

// Connection name must match InputMethodConnectionName in Info.plist.
let kConnectionName = "TineIME_1_Connection"

let server = IMKServer(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server // retain for the process lifetime
NSApplication.shared.run()
