//
//  ContentView.swift
//  azkari Watch App
//
//  The three screens: Home (master toggle, interval, links), Adhkar list,
//  Quiet hours. Every settings change triggers an immediate rebuild (AC-6).
//

import SwiftUI
import UserNotifications

enum Screen: Hashable {
    case adhkar, quiet
}

struct ContentView: View {
    @State private var path: [Screen]

    init() {
        var initial: [Screen] = []
        #if DEBUG
        // Headless screenshots: "-screen adhkar" / "-screen quiet" open that
        // screen pushed on the stack; "-screen home" just suppresses the
        // first-launch permission request (see HomeView.refreshAuthState).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-screen"), i + 1 < args.count {
            switch args[i + 1] {
            case "adhkar": initial = [.adhkar]
            case "quiet": initial = [.quiet]
            default: break
            }
        }
        #endif
        _path = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .adhkar: AdhkarListView()
                    case .quiet: NotificationWindowView()
                    }
                }
        }
        .tint(.accentColor) // jade controls (toggles, picker chips) over system green
    }
}

#if DEBUG
/// Value following `flag` in the launch arguments, e.g. "-hint 5" → "5".
func debugArgument(_ flag: String) -> String? {
    let args = ProcessInfo.processInfo.arguments
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}
#endif

// MARK: - Home

struct HomeView: View {
    @AppStorage(SettingsKey.remindersOn) private var remindersOn = SettingsDefault.remindersOn
    @AppStorage(SettingsKey.intervalMinutes) private var intervalMinutes = SettingsDefault.intervalMinutes
    @AppStorage(SettingsKey.enabledMask) private var enabledMask = SettingsDefault.enabledMask
    @AppStorage(SettingsKey.quietStartMinutes) private var quietStart = SettingsDefault.quietStartMinutes
    @AppStorage(SettingsKey.quietEndMinutes) private var quietEnd = SettingsDefault.quietEndMinutes
    @State private var authDenied: Bool
    @Environment(\.scenePhase) private var scenePhase

    init() {
        var denied = false
        #if DEBUG
        denied = ProcessInfo.processInfo.arguments.contains("-denied") // screenshot the hint row
        #endif
        _authDenied = State(initialValue: denied)
    }

    var body: some View {
        List {
            Section {
                Toggle("التذكيرات", isOn: $remindersOn)
                if authDenied {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.orange)
                        Text("فعّل الإشعارات من إعدادات الساعة")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                Picker("التكرار", selection: $intervalMinutes) {
                    ForEach(SettingsDefault.allowedIntervals, id: \.self) { minutes in
                        Text(intervalName(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.navigationLink)

                NavigationLink(value: Screen.adhkar) {
                    subtitledRow("الأذكار", detail: "\(arabicDigits(enabledMask.nonzeroBitCount)) من \(arabicDigits(Dhikr.all.count))")
                }
                NavigationLink(value: Screen.quiet) {
                    subtitledRow("وقت الإشعارات", detail: windowDetail)
                }
            }
        }
        .navigationTitle("أذكار")
        .azkariBackground()
        .onChange(of: remindersOn) { _, on in handleMasterChange(on) }
        .onChange(of: intervalMinutes) { rebuild() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await refreshAuthState()
        }
    }

    // Active window shown to the user = complement of the stored quiet window: its
    // start is quietEnd (reminders resume), its end is quietStart (reminders stop).
    private var windowDetail: String {
        quietStart == quietEnd ? "طوال اليوم" : "\(timeText(quietEnd)) – \(timeText(quietStart))"
    }

    private func subtitledRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func intervalName(_ minutes: Int) -> String {
        switch minutes {
        case 15: "١٥ دقيقة"
        case 30: "٣٠ دقيقة"
        case 60: "ساعة"
        case 120: "ساعتان"
        case 180: "٣ ساعات"
        case 240: "٤ ساعات"
        default: "\(arabicDigits(minutes)) دقيقة"
        }
    }

    private func rebuild() {
        Task { await Scheduler.rebuild() }
    }

    /// Enabling asks for permission first (no-op if already granted); a denial
    /// reverts the toggle and shows the hint row. Disabling rebuilds to an
    /// empty queue (AC-5).
    private func handleMasterChange(_ on: Bool) {
        Task {
            if on {
                if await Scheduler.requestAuth() {
                    authDenied = false
                    await Scheduler.rebuild()
                    Scheduler.scheduleNextRefresh()
                } else {
                    authDenied = true
                    remindersOn = false
                }
            } else {
                await Scheduler.rebuild()
            }
        }
    }

    /// Runs on every activation: refresh the hint state, and on a fresh
    /// install (defaults on, permission not yet determined) ask right away.
    private func refreshAuthState() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-denied") { return }
        #endif
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        authDenied = status == .denied
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-screen") { return }
        #endif
        if status == .notDetermined && remindersOn {
            handleMasterChange(true)
        }
    }
}

// MARK: - Adhkar list

struct AdhkarListView: View {
    @AppStorage(SettingsKey.enabledMask) private var enabledMask = SettingsDefault.enabledMask
    @State private var lastOneHintID: Int?

    init() {
        #if DEBUG
        _lastOneHintID = State(initialValue: debugArgument("-hint").flatMap(Int.init)) // screenshot the AC-8 hint
        #endif
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Dhikr.all) { dhikr in
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: binding(for: dhikr.id)) {
                            Text(dhikr.text)
                                .font(.body.weight(.medium))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if lastOneHintID == dhikr.id {
                            Text("يجب إبقاء ذكر واحد على الأقل")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onAppear {
                #if DEBUG
                if let target = debugArgument("-scroll").flatMap(Int.init) {
                    proxy.scrollTo(target, anchor: .center) // screenshot any row headlessly
                }
                #endif
            }
        }
        .navigationTitle("الأذكار")
        .azkariBackground()
        .onChange(of: enabledMask) { Task { await Scheduler.rebuild() } }
    }

    private func binding(for id: Int) -> Binding<Bool> {
        Binding(
            get: { enabledMask & (1 << (id - 1)) != 0 },
            set: { on in
                let bit = 1 << (id - 1)
                if on {
                    enabledMask |= bit
                } else if enabledMask != bit {
                    enabledMask &= ~bit
                } else {
                    showLastOneHint(for: id) // AC-8: last one stays on
                }
            }
        )
    }

    private func showLastOneHint(for id: Int) {
        withAnimation { lastOneHintID = id }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if lastOneHintID == id {
                withAnimation { lastOneHintID = nil }
            }
        }
    }
}

// MARK: - Notification window

/// The period during which reminders appear. Stored as the quiet window (when NOT
/// to notify), so it is inverted here: the active window's START binds to quietEnd
/// (reminders resume) and its END binds to quietStart (reminders stop). Equal times
/// = disabled quiet window = reminders all day.
struct NotificationWindowView: View {
    @AppStorage(SettingsKey.quietStartMinutes) private var quietStart = SettingsDefault.quietStartMinutes
    @AppStorage(SettingsKey.quietEndMinutes) private var quietEnd = SettingsDefault.quietEndMinutes

    var body: some View {
        List {
            Section("البداية") {
                DatePicker("البداية", selection: timeBinding($quietEnd), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            Section {
                DatePicker("النهاية", selection: timeBinding($quietStart), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            } header: {
                Text("النهاية")
            } footer: {
                Text(quietStart == quietEnd
                     ? "الوقتان متساويان — تظهر التذكيرات طوال اليوم"
                     : "تظهر التذكيرات خلال هذه الفترة")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("وقت الإشعارات")
        .azkariBackground()
        .onChange(of: quietStart) { Task { await Scheduler.rebuild() } }
        .onChange(of: quietEnd) { Task { await Scheduler.rebuild() } }
    }

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: minutes.wrappedValue / 60,
                    minute: minutes.wrappedValue % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: {
                minutes.wrappedValue = Calendar.current.component(.hour, from: $0) * 60
                    + Calendar.current.component(.minute, from: $0)
            }
        )
    }
}

// MARK: - Shared styling & formatting

extension View {
    /// The app's sense of place: a deep green-black wash behind every screen's
    /// content and chrome.
    func azkariBackground() -> some View {
        containerBackground(Color(red: 0.075, green: 0.145, blue: 0.11).gradient, for: .navigation)
    }
}

/// Eastern Arabic digits regardless of simulator/system locale.
func arabicDigits(_ n: Int) -> String {
    String(String(n).map { c in
        c.wholeNumberValue.flatMap { UnicodeScalar(0x0660 + $0).map(Character.init) } ?? c
    })
}

private let arabicTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ar")
    formatter.timeStyle = .short
    return formatter
}()

/// "22:00" minutes-of-day → "١٠:٠٠ م".
func timeText(_ minutesOfDay: Int) -> String {
    let date = Calendar.current.date(
        bySettingHour: minutesOfDay / 60,
        minute: minutesOfDay % 60,
        second: 0,
        of: .now
    ) ?? .now
    return arabicTimeFormatter.string(from: date)
}

#Preview {
    ContentView()
}
