import Foundation

/// Данные о внешнем сетевом соединении пользователя (публичный IP, провайдер/AS и локация).
/// Соответствует IpInfo из Android.
public struct IpInfo: Identifiable, Hashable, Sendable {
    public var id: String { ip }
    
    /// Внешний IP-адрес клиента
    public let ip: String
    
    /// Название интернет-провайдера / организации (ISP / AS)
    public let isp: String
    
    /// Геолокация (Город, Регион, Страна)
    public let location: String
    
    public init(ip: String, isp: String, location: String) {
        self.ip = ip
        self.isp = isp
        self.location = location
    }
}
