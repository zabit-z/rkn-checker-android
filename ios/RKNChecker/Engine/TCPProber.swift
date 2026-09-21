import Foundation

public struct TcpCheckResult: Sendable {
    public let ok: Bool
    public let timeMs: Int64?
    public let error: String?
    
    public init(ok: Bool, timeMs: Int64?, error: String?) {
        self.ok = ok
        self.timeMs = timeMs
        self.error = error
    }
}

/// Тестирование TCP-подключения к порту (по умолчанию 443).
/// Измеряет RTT и выявляет TCP RST (инъекция middlebox) и таймауты (блокировка по IP / route drop).
public enum TCPProber {
    public static func probe(host: String, port: Int = 443, timeoutMs: Int = 4000) async -> TcpCheckResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let start = DispatchTime.now()
                
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                
                var servinfo: UnsafeMutablePointer<addrinfo>?
                let portStr = String(port)
                guard getaddrinfo(host, portStr, &hints, &servinfo) == 0, let info = servinfo else {
                    continuation.resume(returning: TcpCheckResult(ok: false, timeMs: nil, error: "DNS resolution failed"))
                    return
                }
                defer { freeaddrinfo(servinfo) }
                
                let sock = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
                guard sock >= 0 else {
                    continuation.resume(returning: TcpCheckResult(ok: false, timeMs: nil, error: "socket creation failed"))
                    return
                }
                defer { close(sock) }
                
                // Переводим сокет в неблокирующий режим
                let flags = fcntl(sock, F_GETFL, 0)
                _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
                
                let res = connect(sock, info.pointee.ai_addr, info.pointee.ai_addrlen)
                if res == 0 {
                    let end = DispatchTime.now()
                    let elapsedMs = Int64((end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
                    continuation.resume(returning: TcpCheckResult(ok: true, timeMs: elapsedMs, error: nil))
                    return
                }
                
                let err = errno
                if err != EINPROGRESS {
                    let errDesc = String(cString: strerror(err))
                    continuation.resume(returning: TcpCheckResult(ok: false, timeMs: nil, error: errDesc))
                    return
                }
                
                // Ожидание готовности сокета через select
                var writeSet = fd_set()
                writeSet.zero()
                writeSet.set(sock)
                
                var tv = timeval(
                    tv_sec: Int(timeoutMs / 1000),
                    tv_usec: Int32((timeoutMs % 1000) * 1000)
                )
                
                let sel = select(sock + 1, nil, &writeSet, nil, &tv)
                if sel == 0 {
                    // Таймаут
                    continuation.resume(returning: TcpCheckResult(ok: false, timeMs: nil, error: "timeout"))
                    return
                } else if sel < 0 {
                    let errDesc = String(cString: strerror(errno))
                    continuation.resume(returning: TcpCheckResult(ok: false, timeMs: nil, error: errDesc))
                    return
                }
                
                // Проверка SO_ERROR сокета
                var socketError: Int32 = 0
                var errorLen = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &socketError, &errorLen)
                
                if socketError == 0 {
                    let end = DispatchTime.now()
                    let elapsedMs = Int64((end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
                    continuation.resume(returning: TcpCheckResult(ok: true, timeMs: elapsedMs, error: nil))
                } else {
                    let errDesc = String(cString: strerror(socketError))
                    continuation.resume(returning: TcpCheckResult(ok: false, timeMs: nil, error: errDesc))
                }
            }
        }
    }
}

private extension fd_set {
    mutating func zero() {
        self = fd_set()
    }
    
    mutating func set(_ fd: Int32) {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask = Int32(1 << bitOffset)
        withUnsafeMutableBytes(of: &self) { rawPtr in
            let ptr = rawPtr.bindMemory(to: Int32.self)
            ptr[intOffset] |= mask
        }
    }
}
