import Foundation

/// Резолвер DoH (DNS over HTTPS) через защищённый шлюз Cloudflare (cloudflare-dns.com).
/// Используется в качестве эталонного незагрязнённого резолвера для детекции DNS-спуфинга.
public enum DoHResolver {
    private struct DoHResponse: Decodable {
        let Status: Int?
        let Answer: [DoHAnswer]?
    }
    
    private struct DoHAnswer: Decodable {
        let name: String?
        let type: Int?
        let TTL: Int?
        let data: String?
    }
    
    public static func resolve(host: String, timeout: TimeInterval = 3.0) async -> String? {
        guard let url = URL(string: "https://cloudflare-dns.com/dns-query?name=\(host)&type=A") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoded = try JSONDecoder().decode(DoHResponse.self, from: data)
            if let answers = decoded.Answer {
                for answer in answers where answer.type == 1 { // Type 1 = A record (IPv4)
                    if let ip = answer.data, !ip.isEmpty {
                        return ip
                    }
                }
            }
            return nil
        } catch {
            return nil
        }
    }
}
