import AppKit

enum ITerm {
    struct Info { let name: String; let path: String }

    private static func guid(from sessionID: String?) -> String? {
        guard let raw = sessionID, let guid = raw.split(separator: ":").last,
              guid.allSatisfy({ $0.isHexDigit || $0 == "-" }) else { return nil }
        return String(guid)
    }

    /// Reads the tab/session title and current directory of the iTerm2 session.
    static func info(sessionID: String?, completion: @escaping @MainActor (Info?) -> Void) {
        guard let guid = guid(from: sessionID) else { return }
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if unique id of s is "\(guid)" then
                            tell s to return (name) & linefeed & (variable named "path")
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        DispatchQueue.global().async {
            let p = Process()
            let pipe = Pipe()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            p.standardOutput = pipe
            p.standardError = Pipe()
            guard (try? p.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let parts = (String(data: data, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            let info = parts.count == 2 ? Info(name: String(parts[0]), path: String(parts[1])) : nil
            Task { @MainActor in completion(info) }
        }
    }

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
