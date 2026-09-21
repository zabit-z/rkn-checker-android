import Foundation
import Network
import Security

public struct TlsCheckResult: Sendable {
    public let ok: Bool
    public let timeMs: Int64?
    public let error: String?
    
    public init(ok: Bool, timeMs: Int64?, error: String?) {
        self.ok = ok
        self.timeMs = timeMs
        self.error = error
    }
}

/// Проверка TLS-рукопожатия с передачей явного SNI через Apple Network.framework.
/// Детектирует специфическую сигнатуру фильтрации ТСПУ/РКН:
/// сброс TCP RST сразу после передачи SNI в ClientHello либо тихое отбрасывание пакетов (blackhole).
public enum TLSProber {
    public static func probe(host: String, port: Int = 443, timeoutMs: Int = 4000) async -> TlsCheckResult {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.rknchecker.tlsprober.\(host)")
            let start = DispatchTime.now()
            
            // Настройка параметров TLS с явным SNI
            let tlsOptions = NWProtocolTLS.Options()
            sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, host)
            
            // Отключаем строгую валидацию сертификатов для изоляции проверки сетевого рукопожатия от проблем с CA/сроком действия
            sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { (_, _, completion) in
                completion(true)
            }, queue)
            
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.connectionTimeout = Int(timeoutMs / 1000)
            
            let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
            
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                continuation.resume(returning: TlsCheckResult(ok: false, timeMs: nil, error: "invalid port"))
                return
            }
            
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
            let connection = NWConnection(to: endpoint, using: params)
            
            final class CompletionBox: @unchecked Sendable {
                private let lock = NSLock()
                private var didComplete = false
                func executeIfFirst(action: () -> Void) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !didComplete else { return }
                    didComplete = true
                    action()
                }
            }
            
            let box = CompletionBox()
            
            @Sendable
            func finish(ok: Bool, timeMs: Int64?, error: String?) {
                box.executeIfFirst {
                    connection.cancel()
                    continuation.resume(returning: TlsCheckResult(ok: ok, timeMs: timeMs, error: error))
                }
            }
            
            // Таймер ограничения времени рукопожатия
            let timeoutWorkItem = DispatchWorkItem {
                finish(ok: false, timeMs: nil, error: "timeout")
            }
            queue.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: timeoutWorkItem)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeoutWorkItem.cancel()
                    let end = DispatchTime.now()
                    let elapsedMs = Int64((end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
                    finish(ok: true, timeMs: elapsedMs, error: nil)
                    
                case .failed(let error):
                    timeoutWorkItem.cancel()
                    let desc = error.localizedDescription.lowercased()
                    let normalizedError: String
                    if desc.contains("reset") || desc.contains("rst") || error == .posix(.ECONNRESET) {
                        normalizedError = "connection reset"
                    } else if desc.contains("timeout") || error == .posix(.ETIMEDOUT) {
                        normalizedError = "timeout"
                    } else {
                        normalizedError = error.localizedDescription
                    }
                    finish(ok: false, timeMs: nil, error: normalizedError)
                    
                case .cancelled:
                    break
                    
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
        }
    }
}
