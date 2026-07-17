//
//  tabBar.swift
//  Code
//
//  Created by Ken Chung on 1/7/2021.
//

import SwiftUI

struct TopBar: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var toolBarManager: ToolbarManager
    @EnvironmentObject var stateManager: MainStateManager
    @EnvironmentObject var themeManager: ThemeManager

    @SceneStorage("sidebar.visible") var isSideBarExpanded: Bool = DefaultUIState.SIDEBAR_VISIBLE
    @SceneStorage("panel.visible") var isPanelVisible: Bool = DefaultUIState.PANEL_IS_VISIBLE
    @SceneStorage("panel.focusedId") var currentPanel: String = DefaultUIState.PANEL_FOCUSED_ID
    @AppStorage("runeStoneEditorEnabled") var runeStoneEditorEnabled: Bool = false
    @AppStorage("clarity.codexLaunchCommand") private var codexLaunchCommand = "codex"
    @State private var showsSnippetShelf = false
    @State private var showsOutline = false
    @State private var showsCodexSetup = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let openConsolePanel: () -> Void

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private var commandForCurrentRemoteFolder: String {
        guard let workspaceURL = URL(string: App.workSpaceStorage.currentDirectory.url) else {
            return codexLaunchCommand
        }
        let path = workspaceURL.path.removingPercentEncoding ?? workspaceURL.path
        guard !path.isEmpty else { return codexLaunchCommand }
        return "cd -- \(shellQuoted(path)) && \(codexLaunchCommand)"
    }

    private func launchCodex() {
        guard App.workSpaceStorage.remoteConnected else {
            showsCodexSetup = true
            return
        }

        currentPanel = "TERMINAL"
        isPanelVisible = true

        guard App.terminalManager.runCommandInRemoteTerminal(commandForCurrentRemoteFolder) else {
            showsCodexSetup = true
            return
        }

        if let terminal = App.terminalManager.remoteTerminal {
            App.terminalManager.renameTerminal(id: terminal.id, name: "Codex")
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        App.notificationManager.showInformationMessage("Codex started in the remote workspace")
    }

    var body: some View {
        HStack(spacing: 0) {
            if !isSideBarExpanded && horizontalSizeClass == .compact {
                Button(action: {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isSideBarExpanded.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 17))
                        .foregroundColor(Color.init("T1"))
                        .padding(5)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                        .padding()
                }
            }

            if horizontalSizeClass == .compact {
                CompactEditorTabs()
                    .frame(maxWidth: .infinity)
            } else {
                if #available(iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            EditorTabs()
                            Spacer()
                        }
                        CompactEditorTabs()
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        EditorTabs()
                    }
                    Spacer()
                }
            }

            ForEach(toolBarManager.items) { item in
                if item.shouldDisplay(App) {
                    ToolbarItemView(item: item)
                }
            }

            Button(action: launchCodex) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(
                        App.workSpaceStorage.remoteConnected
                            ? Color(red: 0.15, green: 0.48, blue: 0.95)
                            : Color.secondary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Codex")
            .help(
                App.workSpaceStorage.remoteConnected
                    ? "Run Codex in Remote Workspace" : "Set Up Remote Codex"
            )
            .padding(.horizontal, 4)

            if App.activeTextEditor != nil {
                Button(action: {
                    Task {
                        let value = await App.monacoInstance.getFullValue()
                        await MainActor.run {
                            UIPasteboard.general.string = value
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color(red: 0.71, green: 0.01, blue: 0.00))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy All")
                .help("Copy All")
                .padding(.horizontal, 4)
            }

            if App.activeTextEditor != nil && !App.runeStoneEditorEnabled {
                Button(action: {
                    Task {
                        await App.monacoInstance.focus()
                        await App.monacoInstance._toggleGoToLineWidget()
                    }
                }) {
                    Image(systemName: "number").font(.system(size: 17))
                        .foregroundColor(Color.init("T1")).padding(5)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20).padding()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go to Line")

                Button(action: {
                    showsOutline = true
                }) {
                    Image(systemName: "list.bullet.indent").font(.system(size: 17))
                        .foregroundColor(Color.init("T1")).padding(5)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .hoverEffect(.highlight)
                        .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20).padding()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Script Outline")

                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 17))
                    .foregroundColor(Color.init("T1")).padding(5)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20).padding()
                    .onTapGesture {
                        Task {
                            await App.monacoInstance.focus()
                            await App.monacoInstance.openSearchWidget()
                        }
                    }
            }

            Menu {
                Section("Codex") {
                    Button(action: launchCodex) {
                        Label(
                            App.workSpaceStorage.remoteConnected
                                ? "Run Codex in Remote Workspace" : "Set Up Remote Codex",
                            systemImage: "sparkles")
                    }
                    Button(action: {
                        showsCodexSetup = true
                    }) {
                        Label("Codex Setup & Command", systemImage: "gearshape")
                    }
                }
                if App.activeTextEditor != nil && !App.runeStoneEditorEnabled {
                    Section("Clarity Tools") {
                        Button(action: {
                            Task { await App.monacoInstance._toggleCommandPalatte() }
                        }) {
                            Label("Command Palette", systemImage: "command")
                        }
                        Button(action: {
                            Task {
                                await App.monacoInstance._runEditorAction(
                                    id: "editor.action.formatDocument")
                            }
                        }) {
                            Label("Format Document", systemImage: "text.alignleft")
                        }
                        Button(action: {
                            Task {
                                await App.monacoInstance._runEditorAction(
                                    id: "editor.action.commentLine")
                            }
                        }) {
                            Label("Toggle Comment", systemImage: "text.bubble")
                        }
                        Button(action: {
                            Task {
                                await App.monacoInstance._runEditorAction(id: "editor.foldAll")
                            }
                        }) {
                            Label("Fold All", systemImage: "rectangle.compress.vertical")
                        }
                        Button(action: {
                            Task {
                                await App.monacoInstance._runEditorAction(id: "editor.unfoldAll")
                            }
                        }) {
                            Label("Unfold All", systemImage: "rectangle.expand.vertical")
                        }
                        Button(action: {
                            showsSnippetShelf = true
                        }) {
                            Label("Snippet Shelf", systemImage: "curlybraces")
                        }
                    }
                }
                if App.activeTextEditor is DiffTextEditorInstnace {
                    Section {
                        Button(action: {
                            Task {
                                await App.monacoInstance.switchToInlineDiffView()
                            }
                        }) {
                            Label(
                                NSLocalizedString("Toogle Inline View", comment: ""),
                                systemImage: "doc.text")
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        App.closeAllEditors()
                    } label: {
                        Label("Close All", systemImage: "xmark")
                    }
                    Button(role: .destructive) {
                        App.loadFolder(url: getRootDirectory())
                        DispatchQueue.main.async {
                            App.showWelcomeMessage()
                        }
                    } label: {
                        Label("Close Workspace", systemImage: "xmark")
                    }
                }
                Divider()
                Section {
                    Button(action: {
                        runeStoneEditorEnabled.toggle()
                    }) {
                        Label(
                            runeStoneEditorEnabled
                                ? "actions.switch_to_monaco_editor"
                                : "actions.switch_to_runestone_editor",
                            systemImage: "arrow.left.arrow.right")
                    }
                }
                Section {
                    Button(action: {
                        App.showWelcomeMessage()
                    }) {
                        Label("Show Welcome Page", systemImage: "newspaper")
                    }

                    Button(action: {
                        openConsolePanel()
                    }) {
                        Label(
                            isPanelVisible ? "Hide Panel" : "Show Panel",
                            systemImage: "chevron.left.slash.chevron.right")
                    }.keyboardShortcut("j", modifiers: .command)

                    if UIApplication.shared.supportsMultipleScenes {
                        Button(action: {
                            UIApplication.shared.requestSceneSessionActivation(
                                nil, userActivity: nil, options: nil, errorHandler: nil)
                        }) {
                            Label("actions.new_window", systemImage: "square.split.2x1")
                        }
                    }

                    Button(action: {
                        stateManager.showsSettingsSheet.toggle()
                    }) {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                }

                #if DEBUG
                    DebugMenu()
                #endif

            } label: {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .light))
                    .foregroundColor(Color.init("T1")).padding(5)
                    .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .hoverEffect(.highlight)
                    .padding()
            }
            .sheet(isPresented: $stateManager.showsSettingsSheet) {
                if #available(iOS 16.4, *) {
                    SettingsView()
                        .presentationBackground {
                            Color(id: "sideBar.background")
                        }

                        .scrollContentBackground(.hidden)
                        .environmentObject(themeManager)
                } else {
                    SettingsView()
                        .environmentObject(App)
                }
            }
            .sheet(isPresented: $showsSnippetShelf) {
                ClaritySnippetShelf(editorImplementation: App.monacoInstance)
            }
            .sheet(isPresented: $showsOutline) {
                ClarityOutlineView(editorImplementation: App.monacoInstance)
            }
            .sheet(isPresented: $showsCodexSetup) {
                ClarityCodexSetupView(
                    launchCommand: $codexLaunchCommand,
                    isRemoteConnected: App.workSpaceStorage.remoteConnected,
                    onLaunch: {
                        showsCodexSetup = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            launchCodex()
                        }
                    })
            }

        }
    }
}

private struct ClarityCodexSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var launchCommand: String
    let isRemoteConnected: Bool
    let onLaunch: () -> Void

    private let installCommand = "npm install --global @openai/codex"
    private let loginCommand = "codex login --device-auth"

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Label(
                        "Codex CLI runs on a connected Mac or Linux computer and edits the same remote workspace shown on your iPad.",
                        systemImage: "ipad.and.arrow.forward")
                    Text(
                        "iPadOS cannot run the native Codex CLI binary locally, so XCode launches it through its built-in SSH terminal."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                } header: {
                    Text("How it works")
                }

                Section("1 · Install on the remote computer") {
                    ClarityCodexCommandRow(
                        title: "Install Codex CLI", command: installCommand)
                    ClarityCodexCommandRow(
                        title: "Sign in with a device code", command: loginCommand)
                }

                Section("2 · Connect XCode") {
                    Label("Open Remotes from the sidebar", systemImage: "network")
                    Text("Add the computer using SFTP/SSH, connect, then open your project folder.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("3 · Choose the launch command") {
                    TextField("codex", text: $launchCommand)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    Text("The default is codex. You can add normal CLI options here.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(action: onLaunch) {
                        Label("Run Codex Now", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!isRemoteConnected || launchCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !isRemoteConnected {
                        Text("Connect a remote workspace first, then this button will become available.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Codex on iPad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ClarityCodexCommandRow: View {
    let title: String
    let command: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                Button {
                    UIPasteboard.general.string = command
                    copied = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy \(title)")
            }
        }
        .padding(.vertical, 2)
    }
}

private struct StackedImageIconView: View {

    var primaryIcon: String
    var secondaryIcon: String?

    var body: some View {
        Image(systemName: primaryIcon)
            .font(.system(size: 17))
            .overlay(alignment: .bottomTrailing) {
                if let secondaryIcon {
                    Image(systemName: secondaryIcon)
                        .foregroundStyle(.background, Color.init("T1"))
                        .font(.system(size: 9))
                } else {
                    EmptyView()
                }
            }

    }
}

private struct ToolbarItemView: View {

    @SceneStorage("panel.visible") var showsPanel: Bool = DefaultUIState.PANEL_IS_VISIBLE
    @SceneStorage("panel.focusedId") var currentPanel: String = DefaultUIState.PANEL_FOCUSED_ID

    let item: ToolbarItem

    var body: some View {
        Button(action: {
            if let panelToFocus = item.panelToFocusOnTap {
                showsPanel = true
                currentPanel = panelToFocus
            }
            item.onClick()
        }) {
            StackedImageIconView(primaryIcon: item.icon, secondaryIcon: item.secondaryIcon)
                .font(.system(size: 17))
                .foregroundColor(Color.init("T1"))
                .padding(5)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .hoverEffect(.highlight)
                .frame(minWidth: 0, maxWidth: 20, minHeight: 0, maxHeight: 20)
                .padding()
        }
        .if(item.shortCut != nil) {
            $0.keyboardShortcut(item.shortCut!.key, modifiers: item.shortCut!.modifiers)
        }
    }
}

private struct ClarityOutlineItem: Identifiable {
    enum Kind {
        case section, function, classType

        var icon: String {
            switch self {
            case .section: return "bookmark.fill"
            case .function: return "f.square"
            case .classType: return "shippingbox"
            }
        }
    }

    let id = UUID()
    let name: String
    let line: Int
    let kind: Kind
}

private struct ClarityOutlineView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ClarityOutlineItem] = []
    @State private var query = ""
    let editorImplementation: EditorImplementation

    private var filteredItems: [ClarityOutlineItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            Group {
                if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 34))
                            .foregroundColor(.secondary)
                        Text(query.isEmpty ? "No functions or sections found" : "No matches")
                            .foregroundColor(.secondary)
                        Text("Use -- # Section Name in Lua to add custom jump points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(filteredItems) { item in
                        Button {
                            Task {
                                await editorImplementation.scrollToLine(line: item.line)
                                await editorImplementation.focus()
                                await MainActor.run { dismiss() }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.kind.icon)
                                    .foregroundColor(Color(red: 0.90, green: 0.08, blue: 0.07))
                                    .frame(width: 24)
                                Text(item.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("L\(item.line)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: "Function or section")
            .navigationTitle("Script Outline")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadOutline() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadOutline()
            }
        }
    }

    private func loadOutline() async {
        let source = await editorImplementation.getFullValue()
        let parsed = Self.parse(source)
        await MainActor.run {
            items = parsed
        }
    }

    private static func parse(_ source: String) -> [ClarityOutlineItem] {
        var result: [ClarityOutlineItem] = []
        let patterns: [(String, ClarityOutlineItem.Kind)] = [
            (#"^(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_:.]*)"#, .function),
            (#"^([A-Za-z_][A-Za-z0-9_:.]*)\s*=\s*(?:async\s+)?function"#, .function),
            (#"^(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)"#, .function),
            (#"^(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>"#, .function),
            (#"^(?:export\s+)?class\s+([A-Za-z_$][A-Za-z0-9_$]*)"#, .classType),
        ]

        source.components(separatedBy: .newlines).enumerated().forEach { index, rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("-- #") || line.hasPrefix("// #") {
                let name = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    result.append(
                        ClarityOutlineItem(name: name, line: index + 1, kind: .section))
                }
                return
            }

            for (pattern, kind) in patterns {
                guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = expression.firstMatch(in: line, range: range),
                    match.numberOfRanges > 1,
                    let nameRange = Range(match.range(at: 1), in: line)
                else { continue }
                result.append(
                    ClarityOutlineItem(
                        name: String(line[nameRange]), line: index + 1, kind: kind))
                break
            }
        }
        return result
    }
}

private struct ClaritySnippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var language: String
    var code: String

    static let defaults: [ClaritySnippet] = [
        ClaritySnippet(
            name: "Lua services",
            language: "Lua",
            code: """
                local Players = game:GetService("Players")
                local RunService = game:GetService("RunService")
                local LocalPlayer = Players.LocalPlayer

                """),
        ClaritySnippet(
            name: "Protected call",
            language: "Lua",
            code: """
                local ok, result = pcall(function()

                end)

                if not ok then
                    warn(result)
                end

                """),
        ClaritySnippet(
            name: "Toggle loop",
            language: "Lua",
            code: """
                task.spawn(function()
                    while enabled do

                        task.wait()
                    end
                end)

                """),
        ClaritySnippet(
            name: "Async request",
            language: "JavaScript",
            code: """
                const response = await fetch(url)
                if (!response.ok) throw new Error(`HTTP ${response.status}`)
                const data = await response.json()

                """),
    ]
}

private struct ClaritySnippetShelf: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("clarityStudio.snippets") private var storedSnippets:
        CodableWrapper<[ClaritySnippet]> = .init(value: ClaritySnippet.defaults)
    @State private var showsEditor = false
    @State private var draftName = ""
    @State private var draftLanguage = "Lua"
    @State private var draftCode = ""

    let editorImplementation: EditorImplementation

    var body: some View {
        NavigationView {
            List {
                ForEach(storedSnippets.value) { snippet in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snippet.name)
                                    .font(.headline)
                                Text(snippet.language.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(Color(red: 0.90, green: 0.08, blue: 0.07))
                            }
                            Spacer()
                            Button {
                                UIPasteboard.general.string = snippet.code
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            Button {
                                Task {
                                    await editorImplementation.insertTextAtCurrentCursor(
                                        text: snippet.code)
                                    await MainActor.run { dismiss() }
                                }
                            } label: {
                                Label("Insert", systemImage: "arrow.down.doc")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.71, green: 0.01, blue: 0.00))
                        }
                        Text(snippet.code)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                .onDelete { offsets in
                    var snippets = storedSnippets.value
                    snippets.remove(atOffsets: offsets)
                    storedSnippets = .init(value: snippets)
                }
            }
            .navigationTitle("Snippet Shelf")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        draftName = ""
                        draftLanguage = "Lua"
                        draftCode = ""
                        showsEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showsEditor) {
                NavigationView {
                    Form {
                        TextField("Name", text: $draftName)
                        TextField("Language", text: $draftLanguage)
                        Section("Code") {
                            TextEditor(text: $draftCode)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 260)
                        }
                    }
                    .navigationTitle("New Snippet")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showsEditor = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                var snippets = storedSnippets.value
                                snippets.append(
                                    ClaritySnippet(
                                        name: draftName.trimmingCharacters(in: .whitespacesAndNewlines),
                                        language: draftLanguage,
                                        code: draftCode))
                                storedSnippets = .init(value: snippets)
                                showsEditor = false
                            }
                            .disabled(
                                draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || draftCode.isEmpty)
                        }
                    }
                }
            }
        }
    }
}
