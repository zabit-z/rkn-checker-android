import Foundation

public struct HttpCheckResult: Sendable {
    public let statusCode: Int?
    public let pltMs: Int64?
    public let isStub: Bool
    public let error: String?
    public let timedOut: Bool
    
    public init(statusCode: Int?, pltMs: Int64?, isStub: Bool, error: String?, timedOut: Bool) {
        self.statusCode = statusCode
        self.pltMs = pltMs
        self.isStub = isStub
        self.error = error
        self.timedOut = timedOut
    }
}

/// Сигнатуры страниц-заглушек российских интернет-провайдеров и РКН.
public let STUB_MARKERS: [String] = [
    "доступ ограничен",
    "доступ к запрашиваемому ресурсу",
    "решению роскомнадзора",
    "решением суда",
    "по решению",
    "заблокирован",
    "blocked by",
    "rkn.gov.ru",
    "единый реестр",
    "запрещен"
]

/// Проверка HTTP/HTTPS ответа ресурса без автоматического следования по редиректам.
/// Позволяет обнаружить HTTP 451 (Unavailable For Legal Reasons) и перенаправления на страницы блокировок провайдеров.
public final class HTTPProber: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    
    // Запрет автоматических редиректов (для фиксации перенаправления на stub-страницы провайдеров)
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
    
    public static func probe(urlStr: String, timeoutMs: Int = 5000) async -> HttpCheckResult {
        guard let url = URL(string: urlStr) else {
            return HttpCheckResult(statusCode: nil, pltMs: nil, isStub: false, error: "invalid URL", timedOut: false)
        }
        
        let prober = HTTPProber()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Double(timeoutMs) / 1000.0
        config.timeoutIntervalForResource = Double(timeoutMs) / 1000.0
        let session = URLSession(configuration: config, delegate: prober, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Double(timeoutMs) / 1000.0
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        
        let start = DispatchTime.now()
        do {
            let (data, response) = try await session.data(for: request)
            let end = DispatchTime.now()
            let elapsedMs = Int64((end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return HttpCheckResult(statusCode: nil, pltMs: elapsedMs, isStub: false, error: "not HTTP response", timedOut: false)
            }
            
            let statusCode = httpResponse.statusCode
            var isStub = false
            
            if (200...399).contains(statusCode) || statusCode == 451 {
                let bodyPrefix = String(decoding: data.prefix(4000), as: UTF8.self).lowercased()
                isStub = (statusCode == 451) || STUB_MARKERS.contains { marker in
                    bodyPrefix.contains(marker)
                }
            }
            
            return HttpCheckResult(statusCode: statusCode, pltMs: elapsedMs, isStub: isStub, error: nil, timedOut: false)
        } catch let urlError as URLError {
            let end = DispatchTime.now()
            let elapsedMs = Int64((end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
            if urlError.code == .timedOut {
                return HttpCheckResult(statusCode: nil, pltMs: nil, isStub: false, error: "timeout", timedOut: true)
            }
            return HttpCheckResult(statusCode: nil, pltMs: elapsedMs, isStub: false, error: urlError.localizedDescription, timedOut: false)
        } catch {
            return HttpCheckResult(statusCode: nil, pltMs: nil, isStub: false, error: error.localizedDescription, timedOut: false)
        }
    }
}
