# Federal VPN — Нативный iOS клиент (NetworkExtension + VLESS REALITY)

Полноценный нативный iOS клиент для безопасного сетевого туннелирования, построенный на базе фреймворка **Apple NetworkExtension** (`NEPacketTunnelProvider`, `NETunnelProviderManager`) и архитектуры протокола **VLESS + REALITY + XTLS-Vision**.

---

## 1. Архитектура решения

```
┌────────────────────────────────────────────────────────┐
│                   Main iOS App                         │
│  (SwiftUI, HomeView, ServerListView, DiagnosticsView)  │
└──────────────────────────┬─────────────────────────────┘
                           │ NETunnelProviderManager
                           ▼
┌────────────────────────────────────────────────────────┐
│              Packet Tunnel Provider Extension          │
│                (NEPacketTunnelProvider)                │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ NEPacketTunnelNetworkSettings (IPv4, IPv6, DNS)  │  │
│  └───────────────────────┬──────────────────────────┘  │
│                          │                             │
│  ┌───────────────────────▼──────────────────────────┐  │
│  │               NetworkCoreAdapter                 │  │
│  │         (MockNetworkCore / NativeXrayCore)       │  │
│  └───────────────────────┬──────────────────────────┘  │
└──────────────────────────┼─────────────────────────────┘
                           │ VLESS + REALITY (TCP + Vision)
                           ▼
┌────────────────────────────────────────────────────────┐
│                   VPN Server (Node)                    │
│                 (il1.pornsite.fun:443)                 │
└────────────────────────────────────────────────────────┘
```

### Ключевые компоненты:
1. **Основное приложение (`FederalVPN`)**:
   - `VPNManager`: управляет профилем VPN через системный `NETunnelProviderManager`, отслеживает смену интерфейсов (Wi-Fi ↔ Cellular), запускает сторожевые таймеры (Watchdog) против зависания статуса.
   - `AuthService`: сохраняет токены и пароли исключительно в **Apple Keychain** (запрещено хранить в UserDefaults).
   - `ServerRepository`: управляет списком серверов и выполняет автоматический выбор (`performAutomaticSelection`) по реальному замеру TCP latency.
   - `ConfigurationRepository`: парсер подписок (`vless://`) и генератор настроек туннеля.
   - `AppLogger`: потокобезопасный кольцевой буфер с автоматическим маскированием UUID, токенов и паролей.

2. **Расширение туннеля (`PacketTunnelExtension`)**:
   - `PacketTunnelProvider`: наследник `NEPacketTunnelProvider`. Применяет параметры сетевого интерфейса (IPv4: 10.8.0.2/24 с дефолтным маршрутом `0.0.0.0/0`, IPv6: `fdfe:dcba:9876::2/64` с маршрутом `::/0`, DNS: `1.1.1.1`, `8.8.8.8`, MTU: 1400) и передаёт управление в ядро.
   - `NetworkCoreAdapter`: изолированный слой абстракции ядра. Позволяет подключать `MockNetworkCore` (для тестов и симулятора) или нативный `NativeXrayCore` без переписывания расширения.

---

## 2. Поддерживаемые устройства и версии iOS

| Модель | Чип | Макс. версия iOS | Статус поддержки |
|---|---|---|---|
| **iPhone 7 / 7 Plus** | Apple A10 Fusion | iOS 15.8.3 | **Полная поддержка (iOS 15.0 Deployment Target)** |
| **iPhone 8 / 8 Plus** | Apple A11 Bionic | iOS 16.7.x | **Полная поддержка** |
| **iPhone X / XS / XR** | Apple A11/A12 Bionic | iOS 16 - 18 | **Полная поддержка** |
| **iPhone 11 - 17** | Apple A13 - A19 | iOS 18+ | **Полная поддержка (аппаратный Metal / UltraThinMaterial)** |
| **iPad** (все поколения на iPadOS 15+) | Apple A / M Series | iPadOS 15+ | **Полная поддержка** |

> **Минимальная версия:** **iOS 15.0**. Это самая ранняя версия, которая официально поддерживается актуальным Xcode и даёт доступ к Swift Concurrency (`async/await`) и материалам `.ultraThinMaterial` на старых iPhone 7.

---

## 3. Настройка в Apple Developer Portal и Xcode

Для работы `NetworkExtension` требуются платные права Apple Developer Program.

### Шаг 1. App Identifiers
В [developer.apple.com](https://developer.apple.com) создайте 2 App ID:
1. `com.federalvpn.app` (Основное приложение):
   - Включите **App Groups**: `group.com.federalvpn.app`
   - Включите **Network Extensions**: Packet Tunnel
   - Включите **Keychain Sharing**
2. `com.federalvpn.app.PacketTunnelExtension` (Расширение):
   - Включите **App Groups**: `group.com.federalvpn.app`
   - Включите **Network Extensions**: Packet Tunnel
   - Включите **Keychain Sharing**

### Шаг 2. Signing & Capabilities в Xcode
В настройках таргета `FederalVPN`:
- `Signing & Capabilities` -> `+ Capability`:
  - **Network Extensions** -> отметить галочкой `Packet Tunnel`
  - **App Groups** -> добавить `group.com.federalvpn.app`
  - **Keychain Sharing** -> добавить `group.com.federalvpn.app`

В настройках таргета `PacketTunnelExtension`:
- `Signing & Capabilities` -> `+ Capability`:
  - **Network Extensions** -> отметить галочкой `Packet Tunnel`
  - **App Groups** -> добавить `group.com.federalvpn.app`
  - **Keychain Sharing** -> добавить `group.com.federalvpn.app`

---

## 4. Инструкция по сборке

### Вариант A. Открытие через XcodeGen
Если установлен утилитный инструмент `xcodegen`:
```bash
cd FederalVPN-iOS
xcodegen generate
open FederalVPN.xcodeproj
```

### Вариант B. Создание проекта вручную в Xcode
1. Откройте Xcode -> `Create a new Xcode project` -> `iOS App` -> Название `FederalVPN`.
2. Выберите `SwiftUI` и `Swift`.
3. Добавьте таргет расширения: `File` -> `New` -> `Target...` -> `Network Extension` -> Название `PacketTunnelExtension` (Provider Type: `Packet Tunnel`).
4. Скопируйте файлы из папок `App`, `Core`, `UI`, `Shared` в таргет `FederalVPN`.
5. Скопируйте файлы из `PacketTunnelExtension` и `Shared` в таргет `PacketTunnelExtension`.
6. Установите `iOS Deployment Target` = `15.0` для обоих таргетов.

---

## 5. Интеграция реального нативного ядра (Xray-core / Sing-box)

Проект поставляется с готовым адаптером `NetworkCoreAdapter`. В режиме разработки работает `MockNetworkCore`, позволяя полностью тестировать UI, создание системного интерфейса, маршрутизацию и обработку состояний.

### Для перехода на скомпилированное ядро Xray-core:
1. Соберите `LibXray.xcframework` с помощью `gomobile` под архитектуры `ios-arm64` и `ios-arm64-simulator`.
2. Перетащите `LibXray.xcframework` в таргет `PacketTunnelExtension`.
3. В `Build Phases` -> `Link Binary With Libraries` выберите `Do Not Embed` (расширения не должны встраивать динамические фреймворки внутрь своего бандла).
4. В файле `PacketTunnelExtension/NetworkCore/NativeXrayCore.swift` раскомментируйте вызов gomobile:
   ```swift
   LibXrayRunXray(configFile.path)
   ```
5. В инициализаторе `NetworkCoreAdapter` включите вызов:
   ```swift
   self.activeEngine = NativeXrayCore()
   ```

---

## 6. Чек-лист тестирования

### 1. Тестирование на iPhone 7 (iOS 15):
- Запуск приложения: убедитесь, что верстка не обрезается снизу (используется `ScrollView`).
- Нажатие кнопки «ПОДКЛЮЧИТЬ»: iOS запрашивает системное разрешение *«Federal VPN» Wants to Add VPN Configurations* -> нажать «Allow» -> ввести код-пароль устройства.
- Статус меняется: `DISCONNECTED` -> `CONNECTING` -> `CONNECTED`.
- В статус-баре устройства появляется значок `[VPN]`.
- Переход в «Диагностика» -> проверка счетчиков и статуса TUN0.

### 2. Тестирование на iPhone 15 / 16 / 17:
- Проверка Dynamic Island / Safe Area — верхний хедер аккуратно отступает от системных вырезов.
- Плавность анимаций при 120 Гц ProMotion.
- Переключение Wi-Fi -> сотовая связь: туннель переходит в `reasserting` и автоматически восстанавливает соединение без перезапуска приложения.
