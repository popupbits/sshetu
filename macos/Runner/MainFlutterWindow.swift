import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    #if DEBUG
    // A debug build is its own app, "SSHetu Debug", with its own bundle id
    // and data; the title says so, so a screenshot cannot pass for release.
    // Compiled out of Release and Profile, whose title is untouched.
    self.title = "SSHetu Debug"
    #endif

    super.awakeFromNib()
  }
}
