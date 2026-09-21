import Foundation

/// Резолвер системного DNS через POSIX getaddrinfo.
/// Позволяет получить реальный IP, возвращаемый локальным DNS-сервером системы/провайдера.
public enum SystemDNSResolver {
    public static func resolve(host: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: 0,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                
                var res: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, nil, &hints, &res)
                defer {
                    if let res = res {
                        freeaddrinfo(res)
                    }
                }
                
                guard status == 0, let first = res else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var ptr: UnsafeMutablePointer<addrinfo>? = first
                while let current = ptr {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let nameInfoStatus = getnameinfo(
                        current.pointee.ai_addr,
                        current.pointee.ai_addrlen,
                        &hostBuffer,
                        socklen_t(hostBuffer.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    
                    if nameInfoStatus == 0 {
                        let ipString = String(cString: hostBuffer)
                        continuation.resume(returning: ipString)
                        return
                    }
                    ptr = current.pointee.ai_next
                }
                
                continuation.resume(returning: nil)
            }
        }
    }
}
