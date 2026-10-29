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
    var updated = Date()

    var project: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "Copilot" : name
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published var hovering = false

    var needsAttention: Bool { sessions.contains { $0.state == .needsInput || $0.state == .done } }
    var expanded: Bool { hovering }
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

        if s.state != previous {
            if s.state == .needsInput { NSSound(named: "Ping")?.play() }
            if s.state == .done { NSSound(named: "Glass")?.play() }
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
