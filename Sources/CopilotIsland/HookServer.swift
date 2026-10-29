import Foundation
import Network

struct HookEvent {
    let name: String
    let payload: [String: Any]
    let itermSession: String?
}

/// Minimal HTTP server bound to 127.0.0.1 that receives events posted by the Copilot CLI hook script.
final class HookServer {
    static let port: UInt16 = 47615

    var onEvent: ((HookEvent) -> Void)?
    private var listener: NWListener?

    func start() throws {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: Self.port)!)
        let l = try NWListener(using: params)
        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            self?.receive(conn, buffer: Data())
        }
        l.start(queue: .main)
        listener = l
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if let event = Self.parse(buf) {
                let reply = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}"
                conn.send(content: reply.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })
                self.onEvent?(event)
            } else if isComplete || error != nil || buf.count > 1_000_000 {
                conn.cancel()
            } else {
                self.receive(conn, buffer: buf)
            }
        }
    }

    private static func parse(_ data: Data) -> HookEvent? {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<sep.lowerBound], encoding: .utf8) else { return nil }
        var headers: [String: String] = [:]
        for line in head.components(separatedBy: "\r\n").dropFirst() {
            guard let idx = line.firstIndex(of: ":") else { continue }
            let key = line[..<idx].lowercased()
            headers[key] = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        let body = data[sep.upperBound...]
        guard body.count >= length else { return nil }
        // The custom header blocks cross-origin browser requests (they would need a CORS preflight).
        guard let name = headers["x-copilot-event"], !name.isEmpty else { return HookEvent(name: "", payload: [:], itermSession: nil) }
        let json = (try? JSONSerialization.jsonObject(with: body.prefix(length))) as? [String: Any] ?? [:]
        let iterm = headers["x-iterm-session"].flatMap { $0.isEmpty ? nil : $0 }
        return HookEvent(name: name, payload: json, itermSession: iterm)
    }
}
