import Foundation
import Network

/// A tiny HTTP server on 127.0.0.1 that Claude Code's hooks post to. It understands just
/// enough HTTP/1.1 for `curl`: one POST per connection, a JSON body, a JSON reply.
final class AgentServer: @unchecked Sendable {
    static let port: UInt16 = 47823

    /// Called on the main queue with the request path and body. Call `reply` exactly once,
    /// whenever the answer is ready; holding it is how approvals wait for you.
    var onRequest: (_ path: String, _ body: Data, _ reply: @escaping @Sendable (Data) -> Void) -> Void = { _, _, reply in reply(Data("{}".utf8)) }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "islet.agent-server")

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .init(rawValue: Self.port)!)
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
        self.listener = listener
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        read(connection, buffer: Data())
    }

    private func read(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, done, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let (path, body) = Self.parse(buffer) {
                DispatchQueue.main.async {
                    self.onRequest(path, body) { reply in Self.respond(connection, body: reply) }
                }
            } else if done || error != nil || buffer.count > 4 << 20 {
                connection.cancel()
            } else {
                self.read(connection, buffer: buffer)
            }
        }
    }

    /// The path and body of a complete request, or nil while more bytes are due.
    private static func parse(_ data: Data) -> (String, Data)? {
        guard let split = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<split.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count >= 2 else { return nil }
        let length = lines.dropFirst()
            .first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        let body = data[split.upperBound...]
        guard body.count >= length else { return nil }
        return (String(parts[1]), Data(body.prefix(length)))
    }

    private static func respond(_ connection: NWConnection, body: Data) {
        let head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }
}
