import AppKit
import SwiftUI

enum SessionState {
    case idle, working, needsInput, done

    var label: String {
        switch self {
        case .idle: return "Inactif"
        case .working: return "Travail en cours…"
        case .needsInput: return "Action requise"
        case .done: return "Terminé"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .working: return .blue
        case .needsInput: return .orange
        case .done: return .green
        }
    }
}

struct Session: Identifiable, Equatable {
    let id: String
    var cwd: String
    var state: SessionState = .idle
    var message: String = ""
    var itermSession: String?
    var tabName: String?
    var tabPath: String?
    var updated = Date()

    var project: String {
        if let tabName, !tabName.isEmpty { return tabName }
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "Copilot" : name
    }

    var displayPath: String {
        let path = (tabPath?.isEmpty == false ? tabPath : cwd) ?? ""
        return (path as NSString).abbreviatingWithTildeInPath
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published var hovering = false {
        didSet { if hovering && !oldValue { sessions.forEach { refreshInfo(id: $0.id) } } }
    }

    var needsAttention: Bool { sessions.contains { $0.state == .needsInput || $0.state == .done } }
    var expanded: Bool { hovering }
    var isWorking: Bool { sessions.contains { $0.state == .working } }
    var attentionColor: Color? {
        if sessions.contains(where: { $0.state == .needsInput }) { return SessionState.needsInput.color }
        if sessions.contains(where: { $0.state == .done }) { return SessionState.done.color }
        return nil
    }

    func handle(_ event: HookEvent) {
        let p = event.payload
        let id = (p["sessionId"] ?? p["session_id"]) as? String ?? "unknown"
        let cwd = p["cwd"] as? String ?? ""

        if event.name == "sessionEnd" {
            sessions.removeAll { $0.id == id }
            return
        }

        var s = sessions.first { $0.id == id } ?? Session(id: id, cwd: cwd)
        if !cwd.isEmpty { s.cwd = cwd }
        if let iterm = event.itermSession { s.itermSession = iterm }
        let previous = s.state

        switch event.name {
        case "sessionStart":
            s.state = .idle
        case "userPromptSubmitted", "postToolUse":
            s.state = .working
            s.message = ""
        case "notification":
            let type = p["notification_type"] as? String ?? ""
            guard type == "permission_prompt" || type == "elicitation_dialog" else { return }
            s.state = .needsInput
            s.message = (p["message"] as? String) ?? (p["title"] as? String) ?? "Copilot attend une réponse"
        case "agentStop":
            s.state = .done
            s.message = "Tâche terminée — cliquez pour revenir au terminal"
        default:
            return
        }

        s.updated = Date()
        if let idx = sessions.firstIndex(where: { $0.id == id }) { sessions[idx] = s } else { sessions.append(s) }
        sessions.sort { $0.updated > $1.updated }

        if s.state != previous || s.tabName == nil { refreshInfo(id: id) }

        if s.state != previous {
            if s.state == .needsInput { NSSound(named: "Ping")?.play() }
            if s.state == .done { NSSound(named: "Glass")?.play() }
        }
    }

    private func refreshInfo(id: String) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        ITerm.info(sessionID: session.itermSession) { [weak self] info in
            guard let self, let info, let idx = self.sessions.firstIndex(where: { $0.id == id }) else { return }
            guard self.sessions[idx].tabName != info.name || self.sessions[idx].tabPath != info.path else { return }
            self.sessions[idx].tabName = info.name
            self.sessions[idx].tabPath = info.path
        }
    }

    func open(_ session: Session) {
        ITerm.focus(sessionID: session.itermSession)
        guard let idx = sessions.firstIndex(of: session) else { return }
        if sessions[idx].state == .done || sessions[idx].state == .needsInput {
            sessions[idx].state = sessions[idx].state == .done ? .idle : .working
            sessions[idx].message = ""
        }
    }

    func dismiss(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
    }
}
