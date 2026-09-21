import Foundation

/// Главный диагностический сетевой движок.
/// Реализует четырёхуровневую цепочку анализа (DNS/DoH -> TCP 443 -> TLS SNI -> HTTP 451/Stub)
/// и запрос сведений о внешнем IP/провайдере.
public enum NetworkDiagnosticsEngine {
    
    // MARK: - Определение внешнего IP и ISP
    
    public static func fetchIpAndProvider() async -> IpInfo? {
        // Попытка 1: ipinfo.io
        if let info = await fetchFromIpInfo() {
            return info
        }
        // Попытка 2 (Fallback): ipwho.is
        if let info = await fetchFromIpWhoIs() {
            return info
        }
        return nil
    }
    
    private static func fetchFromIpInfo() async -> IpInfo? {
        guard let url = URL(string: "https://ipinfo.io/json") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            let ip = json["ip"] as? String ?? "Unknown"
            let isp = json["org"] as? String ?? "Unknown"
            let city = json["city"] as? String ?? ""
            let region = json["region"] as? String ?? ""
            let country = json["country"] as? String ?? ""
            let locParts = [city, region, country].filter { !$0.isEmpty }
            let location = locParts.isEmpty ? "Unknown" : locParts.joined(separator: ", ")
            
            return IpInfo(ip: ip, isp: isp, location: location)
        } catch {
            return nil
        }
    }
    
    private static func fetchFromIpWhoIs() async -> IpInfo? {
        guard let url = URL(string: "https://ipwho.is/") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["success"] as? Bool) == true else {
                return nil
            }
            
            let ip = json["ip"] as? String ?? "Unknown"
            let connection = json["connection"] as? [String: Any]
            let isp = connection?["isp"] as? String ?? connection?["org"] as? String ?? "Unknown"
            let city = json["city"] as? String ?? ""
            let region = json["region"] as? String ?? ""
            let country = json["country_code"] as? String ?? ""
            let locParts = [city, region, country].filter { !$0.isEmpty }
            let location = locParts.isEmpty ? "Unknown" : locParts.joined(separator: ", ")
            
            return IpInfo(ip: ip, isp: isp, location: location)
        } catch {
            return nil
        }
    }
    
    // MARK: - Диагностика ресурса (4 уровня)
    
    public static func checkTarget(_ target: TargetItem) async -> CheckResult {
        var res = CheckResult(target: target)
        let host = target.host
        
        // 1. DNS (Системный резолвер против Cloudflare DoH)
        async let sysIpTask = SystemDNSResolver.resolve(host: host)
        async let dohIpTask = DoHResolver.resolve(host: host)
        let (sysIp, dohIp) = await (sysIpTask, dohIpTask)
        
        res.sysIp = sysIp
        res.dohIp = dohIp
        
        if res.sysIp == nil && res.dohIp != nil {
            res.verdict = .dnsBlock
            res.notes.append("System DNS failed, DoH resolved — DNS poisoning signature")
            return res
        }
        
        if res.sysIp == nil && res.dohIp == nil {
            res.verdict = .down
            res.notes.append("Domain does not resolve via System DNS or DoH")
            return res
        }
        
        if let s = res.sysIp, let d = res.dohIp, s != d {
            res.dnsMismatch = true
            res.notes.append("DNS Mismatch: System=\(s) vs DoH=\(d) (Transparent DNS rewriting)")
        }
        
        // 2. TCP (порт 443)
        let tcpRes = await TCPProber.probe(host: host, port: 443, timeoutMs: 4000)
        res.tcpOk = tcpRes.ok
        res.tcpTimeMs = tcpRes.timeMs
        res.tcpError = tcpRes.error
        
        if !res.tcpOk {
            let errLower = (res.tcpError ?? "").lowercased()
            if errLower.contains("timeout") {
                res.verdict = .timeout
                res.notes.append("TCP Timeout on port 443 — IP block or route drop")
            } else if errLower.contains("reset") || errLower.contains("rst") || errLower.contains("refused") {
                res.verdict = .tcpReset
                res.notes.append("TCP RST received — Middlebox injection signature")
            } else {
                res.verdict = .down
                res.notes.append("TCP connection failed: \(res.tcpError ?? "unknown")")
            }
            return res
        }
        
        // 3. TLS (рукопожатие с явным SNI)
        let tlsRes = await TLSProber.probe(host: host, port: 443, timeoutMs: 4000)
        res.tlsOk = tlsRes.ok
        res.tlsTimeMs = tlsRes.timeMs
        res.tlsError = tlsRes.error
        
        if !res.tlsOk {
            let errLower = (res.tlsError ?? "").lowercased()
            if errLower.contains("reset") || errLower.contains("rst") || errLower.contains("connection reset") {
                res.verdict = .tlsBlock
                res.notes.append("TLS reset right after ClientHello — SNI-based DPI filtering signature")
            } else if errLower.contains("timeout") {
                res.verdict = .tlsBlock
                res.notes.append("TLS handshake silently dropped — DPI ClientHello filtering signature")
            } else {
                res.verdict = .tlsBlock
                res.notes.append("TLS Handshake error: \(res.tlsError ?? "unknown")")
            }
            return res
        }
        
        // 4. HTTP (проверка кода 451 и тела ответа на заглушки провайдеров)
        let httpRes = await HTTPProber.probe(urlStr: target.url, timeoutMs: 5000)
        res.statusCode = httpRes.statusCode
        res.pltMs = httpRes.pltMs
        res.httpError = httpRes.error
        
        if httpRes.timedOut {
            res.verdict = .timeout
            return res
        }
        
        if httpRes.error != nil {
            res.verdict = .down
            return res
        }
        
        if res.statusCode == 451 {
            res.verdict = .httpStub
            res.notes.append("HTTP 451 — Unavailable For Legal Reasons (Explicit RKN notice)")
            return res
        }
        
        if httpRes.isStub {
            res.verdict = .httpStub
            res.notes.append("Response body matches ISP block stub-page marker")
            return res
        }
        
        res.verdict = .ok
        return res
    }
}
