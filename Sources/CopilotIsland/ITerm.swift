import AppKit

enum ITerm {
    /// `sessionID` is the value of $ITERM_SESSION_ID ("w0t0p0:GUID").
    static func focus(sessionID: String?) {
        guard let raw = sessionID, let guid = raw.split(separator: ":").last,
              guid.allSatisfy({ $0.isHexDigit || $0 == "-" }) else {
            activate()
            return
        }
        let script = """
        tell application "iTerm2"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique id of s is "\(guid)" then
                            select w
                            select t
                            select s
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        DispatchQueue.global().async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            try? p.run()
        }
    }

    private static func activate() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
