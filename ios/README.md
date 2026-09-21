# RKN Block Checker (iOS & iPadOS App)

Нативное приложение для iOS и iPadOS для диагностики сетевой цензуры, фильтрации ТСПУ/DPI и блокировок провайдеров в РФ, функционально идентичное [Android-версии](../README.md).

---

## 🚀 Особенности и возможности

- **Сведения о сети и интернет-провайдере**:
  - Автоматическое определение внешнего IP-адреса, провайдера/организации (ISP / AS) и геолокации через `ipinfo.io` (с отказоустойчивым fallback на `ipwho.is`).
- **4-уровневый диагностический сетевой конвейер**:
  1. **DNS & DoH (DNS-over-HTTPS)**:
     - Сравнение локального системного DNS (через POSIX `getaddrinfo`) с защищённым DoH Cloudflare (`https://cloudflare-dns.com/dns-query`).
     - Детекция DNS-спуфинга, поддельных ответов и прозрачной подмены DNS (`DNS Mismatch`).
  2. **TCP Probing (порт 443)**:
     - Низкоуровневое TCP-подключение на порт 443 с замером RTT (`TCP ms`).
     - Детекция пакетов сброса middlebox (`TCP RESET`) и неотвечающих маршрутов (`TIMEOUT`).
  3. **TLS Handshake & SNI DPI Probing**:
     - Рукопожатие через Apple `Network.framework` (`NWConnection`) с явным указанием SNI (`NWProtocolTLS.Options`).
     - Замер латентности TLS (`TLS ms`).
     - Выявление специфической сигнатуры ТСПУ/РКН: мгновенный сброс TCP RST сразу после ClientHello или тихое отбрасывание пакетов (silent drop / blackhole).
  4. **HTTP Probing & ISP Stub Detection**:
     - Запрос через `URLSession` с отключенным автоматическим следованием по редиректам (для фиксации перенаправления на страницы-заглушки провайдеров).
     - Детекция кода `HTTP 451` (Unavailable For Legal Reasons).
     - Сканирование первых 4000 символов тела ответа на 10 сигнатур заглушек («доступ ограничен», «по решению роскомнадзора», «единый реестр» и др.).
- **Предустановленные списки ресурсов (36 целей)**:
  - **Whitelist (21 ресурс)**: ключевые сервисы РФ (`gosuslugi`, `gov.ru`, `sberbank`, `yandex`, `vk`, `ozon`, `avito`, `tass` и др.).
  - **Blacklist (15 ресурсов)**: сервисы под ограничениями РКН (`instagram`, `facebook`, `x/twitter`, `discord`, `rutracker`, `meduza`, `protonvpn` и др.).
- **Адаптивный интерфейс Apple HIG & iPadOS**:
  - **iPadOS**: двухпанельный `NavigationSplitView` с постоянной боковой панелью фильтров, системным статусом и адаптивной многоколоночной сеткой `LazyVGrid` на основном холсте. Поддержка поворота экрана, Stage Manager, Split View (50/50, 1/3) и Slide Over.
  - **iOS (iPhone)**: оптимизированный `NavigationStack` с прокручиваемым дашбордом и сегментированными чипами фильтров (`All`, `Whitelist`, `Blacklist`, `Blocked`).
  - **Глубокий технический инспектор (Sheet)**: просмотр подробных данных по любому ресурсу при клике на карточку (сравнение DNS IP, сырые ошибки сокетов, время ответа, повторная проверка отдельного ресурса).
  - **Тёмная тема (Cyber/Terminal)**: глубокий фон `#0C0C0C`, плашки `#161618`, моноширинные замеры задержек и системные иконки SF Symbols.

---

## 🛠 Вердикты и статусы

| Вердикт | Символ | Описание |
| :--- | :---: | :--- |
| **`✓ OK`** | `checkmark.shield.fill` | Доступен: DNS разрешён, TCP/TLS установлены, статус HTTP корректен, тело ответа чистое. |
| **`~ TLS DPI`** | `lock.slash.fill` | Сброс TLS-рукопожатия или сброс после передачи SNI ClientHello (характерная сигнатура ТСПУ). |
| **`~ TCP RESET`** | `arrow.triangle.swap` | Инъекция TCP RST на порт 443 промежуточным фильтром (middlebox). |
| **`✗ HTTP STUB`** | `doc.text.magnifyingglass` | Обнаружена страница-заглушка провайдера либо ответ HTTP 451. |
| **`⛔ DNS BLOCK`** | `network.slash` | Системный DNS завершился с ошибкой, в то время как DoH успешно разрешил домен (DNS poisoning). |
| **`? TIMEOUT`** | `clock.badge.exclamationmark` | Таймаут подключения к порту 443 (блокировка по IP или отбрасывание трафика). |
| **`· DOWN`** | `xmark.circle` | Ресурс не резолвится ни одним DNS или выключен. |
| **`... TESTING`** | `arrow.clockwise` | В процессе активной диагностики. |

---

## 📁 Структура каталога `ios/`

```
ios/
├── project.yml               # Спецификация для генератора проекта XcodeGen
├── RKNChecker.xcodeproj      # Готовый к открытию проект Xcode (Universal iPad & iPhone)
├── Package.swift             # Swift Package манифест для сборки и модульных тестов
├── README.md                 # Документация проекта для iOS/iPadOS
├── RKNChecker/
│   ├── App/
│   │   ├── RKNCheckerApp.swift   # Точка входа @main
│   │   └── Info.plist            # Настройки ATS (разрешение HTTP-заглушек) и ориентаций iPad
│   ├── Models/
│   │   ├── TargetItem.swift      # Модель целевого ресурса (name, url, isWhitelist)
│   │   ├── IpInfo.swift          # Модель внешнего соединения и ISP
│   │   ├── Verdict.swift         # Перечисление вердиктов со стилями и SF Symbols
│   │   └── CheckResult.swift     # Результаты замеров и диагностические заметки
│   ├── Engine/
│   │   ├── SystemDNSResolver.swift # Резолвинг через getaddrinfo
│   │   ├── DoHResolver.swift       # Cloudflare DNS-over-HTTPS JSON API
│   │   ├── TCPProber.swift         # Низкоуровневый замер TCP 443 с детекцией RST
│   │   ├── TLSProber.swift         # Network.framework с кастомным SNI для детекции DPI
│   │   ├── HTTPProber.swift        # URLSession без редиректов и сканирование STUB_MARKERS
│   │   └── NetworkDiagnosticsEngine.swift # Диспетчер проверок и запрос IP
│   ├── ViewModels/
│   │   └── CheckerViewModel.swift  # Реактивное управление состоянием и подсчёт статистики
│   ├── Views/
│   │   ├── MainAdaptiveView.swift  # Корневой адаптивный вид (iPad / iPhone)
│   │   ├── Components/
│   │   │   ├── NetworkHeaderCardView.swift   # Карточка сведений о сети
│   │   │   ├── SummaryOverviewCardView.swift # Сводка блокировок
│   │   │   ├── SiteResultCardView.swift      # Карточка проверяемого ресурса
│   │   │   ├── MetricPillView.swift          # Плашки задержек (TCP, TLS, PLT, Status)
│   │   │   ├── VerdictBadgeView.swift        # Бейдж вердикта
│   │   │   └── BlockChipView.swift           # Чипы категорий блокировок
│   │   ├── Detail/
│   │   │   └── SiteDetailSheet.swift         # Инспектор технических деталей
│   │   └── iPad/
│   │       ├── iPadSplitContainerView.swift  # NavigationSplitView для iPadOS
│   │       └── iPadGridView.swift            # Адаптивная сетка LazyVGrid
│   └── Resources/
│       └── Assets.xcassets/
│           ├── AccentColor.colorset/
│           └── AppIcon.appiconset/
└── Tests/
    └── RKNCheckerTests/
        └── DiagnosticEngineTests.swift       # Модульные тесты движка и моделей
```

---

## 💻 Сборка и запуск

### 1. Открытие в Xcode
Дважды нажмите на файл `ios/RKNChecker.xcodeproj` или выполните:
```bash
open ios/RKNChecker.xcodeproj
```
В Xcode выберите целевое устройство:
- Любой iPad (например, **iPad Pro 11-inch** или **iPad Air**) для проверки планшетного интерфейса и режима Split View.
- Любой iPhone (например, **iPhone 16 Pro** или **iPhone 15**) для проверки мобильного интерфейса.
- Нажмите **Cmd + R** для запуска.

### 2. Регенерация проекта через XcodeGen (при необходимости)
Если вы добавили новые файлы или изменили `project.yml`:
```bash
cd ios
xcodegen generate
```

### 3. Запуск тестов из командной строки
```bash
cd ios
swift test
```
