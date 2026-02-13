import Foundation
import Network

/// Lightweight HTTP server on localhost:8080 for programmatic access to the simulator.
///
/// Endpoints:
///   POST /command   — body = raw command text, returns dispatcher response (text/plain)
///   GET  /state     — full ReactorState snapshot as JSON (application/json)
///   GET  /display   — terminal texture as PNG (image/png)
final class AdminServer {

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.reactor.admin-server")
    private let port: UInt16

    /// Called with a command string; returns the response text.
    /// The implementation must be thread-safe (called from background queue).
    var onCommand: ((String) -> String)?

    /// Returns a JSON-encodable dictionary.
    /// The implementation must be thread-safe (called from background queue).
    var onStateSnapshot: (() -> [String: Any])?

    /// Returns PNG data of the terminal texture.
    /// The implementation must be thread-safe (called from background queue).
    var onDisplayCapture: (() -> Data?)?

    init(port: UInt16 = 8080) {
        self.port = port
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[AdminServer] Failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[AdminServer] Listening on port \(self.port)")
            case .failed(let error):
                print("[AdminServer] Listener failed: \(error)")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        // Read up to 1 MB for the HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            let request = String(data: data, encoding: .utf8) ?? ""
            let (method, path, body) = self.parseHTTPRequest(request)

            self.route(method: method, path: path, body: body) { statusCode, contentType, responseBody in
                let response = self.buildHTTPResponse(statusCode: statusCode, contentType: contentType, body: responseBody)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    // MARK: - HTTP Parsing

    private func parseHTTPRequest(_ raw: String) -> (method: String, path: String, body: String) {
        let lines = raw.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else {
            return ("GET", "/", "")
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        let method = parts.count > 0 ? String(parts[0]) : "GET"
        let path = parts.count > 1 ? String(parts[1]) : "/"

        // Find body after blank line
        var body = ""
        var foundBlank = false
        for line in lines.dropFirst() {
            if foundBlank {
                if !body.isEmpty { body += "\r\n" }
                body += line
            } else if line.isEmpty {
                foundBlank = true
            }
        }

        return (method, path, body)
    }

    // MARK: - Routing

    private func route(method: String, path: String, body: String, completion: @escaping (Int, String, Data) -> Void) {
        switch (method.uppercased(), path) {

        case ("POST", "/command"):
            let commandText = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !commandText.isEmpty else {
                let msg = "No command provided".data(using: .utf8)!
                completion(400, "text/plain", msg)
                return
            }

            // Block quit/exit over HTTP
            let lower = commandText.lowercased().trimmingCharacters(in: .whitespaces)
            if lower == "quit" || lower == "exit" {
                let msg = "quit/exit blocked over HTTP".data(using: .utf8)!
                completion(403, "text/plain", msg)
                return
            }

            let response = self.onCommand?(commandText) ?? "No command handler"
            let data = response.data(using: .utf8)!
            completion(200, "text/plain", data)

        case ("GET", "/state"):
            let snapshot = self.onStateSnapshot?() ?? [:]
            let data: Data
            do {
                data = try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys])
            } catch {
                let msg = "JSON serialization error: \(error)".data(using: .utf8)!
                completion(500, "text/plain", msg)
                return
            }
            completion(200, "application/json", data)

        case ("GET", "/display"):
            guard let pngData = self.onDisplayCapture?() else {
                let msg = "Display capture unavailable".data(using: .utf8)!
                completion(503, "text/plain", msg)
                return
            }
            completion(200, "image/png", pngData)

        default:
            let msg = "Not Found: \(method) \(path)\nAvailable: POST /command, GET /state, GET /display".data(using: .utf8)!
            completion(404, "text/plain", msg)
        }
    }

    // MARK: - HTTP Response Building

    private func buildHTTPResponse(statusCode: Int, contentType: String, body: Data) -> Data {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 403: statusText = "Forbidden"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        case 503: statusText = "Service Unavailable"
        default: statusText = "Unknown"
        }

        var header = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        header += "Access-Control-Allow-Headers: Content-Type\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"

        var response = header.data(using: .utf8)!
        response.append(body)
        return response
    }
}
