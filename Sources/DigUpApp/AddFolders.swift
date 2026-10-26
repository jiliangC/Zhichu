import AppKit
import DigUpKit
import SwiftUI

/// Settings → Folders → Add Folders…: a sheet like onboarding's folder step. It lists the usual folders that aren't
/// searched yet and any other folder you choose, each with what's in it, how long its first pass takes and its
/// subfolders; nothing changes until Add. With nothing left to suggest, it starts from the open panel.
///
/// With `code`, Settings → Code's: folders for code search, each opening to its repos, with how long reading them
/// takes and how much room their index needs.
final class AddFoldersController {
    private unowned let app: AppController
    private(set) var choices: FolderChoices?
    private var sheet: NSWindow?
    let code: Bool
    /// The folders changed (Settings refreshes its list).
    var onAdded: () -> Void = {}

    init(app: AppController, code: Bool = false) {
        self.app = app
        self.code = code
    }

    var isOpen: Bool { choices != nil }

    func begin(on window: NSWindow?) {
        guard choices == nil else { return }
        let settings = app.model.settings
        let selection = code
            ? FolderSelection(skipped: settings.codeExcluded.map(\.path), kept: settings.codeRoots.map(\.path))
            : FolderSelection(skipped: settings.excludedFolders.map(\.path), kept: settings.roots.map(\.path))
        let suggestions = (code ? CodeFolders.candidates(searched: settings.roots) : OnboardingState.candidates())
            .filter { !selection.isSearched($0.path) }
        let choices = FolderChoices(rows: suggestions, selection: selection, types: code ? [] : settings.excludedTypes,
                                    code: code)
        self.choices = choices
        // Snapshot runs never put an open panel on screen (-debugChoices picks folders instead).
        guard suggestions.isEmpty, !AppController.offscreen else { return present(choices, on: window) }
        app.pickFolders(for: window) { [weak self] picked in
            guard let self else { return }
            guard !picked.isEmpty else {
                self.choices = nil
                return
            }
            choices.add(picked)
            present(choices, on: window)
        }
    }

    private func present(_ choices: FolderChoices, on window: NSWindow?) {
        let view = AddFoldersView(choices: choices,
                                  pick: { [weak self] in self?.pick() },
                                  cancel: { [weak self] in self?.end() },
                                  add: { [weak self] in self?.add() })
        let sheet = NSWindow(contentViewController: NSHostingController(rootView: view))
        sheet.styleMask = [.titled]
        sheet.title = code ? "代码文件夹" : "添加文件夹"
        self.sheet = sheet
        choices.startEstimates()
        log("add folders: \(choices.rows.count) to choose from")
        guard !AppController.offscreen else { return }   // snapshot runs draw it without showing it
        if let window, window.isVisible { window.beginSheet(sheet) } else { app.present(sheet) }
    }

    private func pick() {
        app.pickFolders(for: sheet) { [weak self] picked in
            guard !picked.isEmpty else { return }
            self?.choices?.add(picked)
        }
    }

    func add() {
        guard let choices else { return }
        log("add \(code ? "code " : "")folders: \(choices.roots.map { tildePath($0.path) })"
            + (choices.skipped.isEmpty ? "" : " minus \(choices.skipped.map { tildePath($0.path) })"))
        if code {
            app.applyCodeFolders(choices.roots, excluded: choices.skipped)
        } else {
            app.applyFolders(choices.roots, excluded: choices.skipped)
        }
        end()
        onAdded()
    }

    func end() {
        if let sheet {
            if let parent = sheet.sheetParent { parent.endSheet(sheet) } else { sheet.close() }
        }
        sheet = nil
        choices = nil
    }

    func snapshot(to url: URL) throws {
        try Snapshot.write(sheet, to: url)
    }
}

private struct AddFoldersView: View {
    let choices: FolderChoices
    let pick: () -> Void
    let cancel: () -> Void
    let add: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                if choices.code {
                    StepTitle(title: "搜索你的代码",
                              subtitle: "选择项目所在的文件夹，也可展开后选择部分仓库。"
                                  + "知处首次读取所选代码，之后仅处理变更。代码使用独立索引，请在搜索面板中输入 "
                                  + "code: 加上代码作用或名称。")
                } else {
                    StepTitle(title: "添加要搜索的文件夹",
                              subtitle: "知处首次读取新文件夹，之后仅处理其中的变更。"
                                  + "展开文件夹可选择部分子文件夹。")
                }
                ScrollView {
                    FolderList(choices: choices, addTitle: "选择其他文件夹…", add: pick)
                    if choices.code { CodeFolderNote().padding(.top, 8) }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 12)
            Divider()
            HStack(spacing: 12) {
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("取消", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("添加", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!choices.changesSomething)
            }
            .controlSize(.large)
            .padding(.horizontal, 20)
            .frame(height: 60)
        }
        .frame(width: 600, height: 540)
    }

    private var summary: String {
        guard choices.changesSomething else { return "请选择要添加的文件夹" }
        guard choices.estimatesDone else { return "正在估算文件夹…" }
        let time = choices.totalSeconds < 1 ? "不到 1 秒" : "约 \(roughDuration(choices.totalSeconds))"
        if choices.code {
            return "首次索引需\(time)，占用约 \(roughBytes(choices.totalBytes))"
        }
        let later = choices.totalLaterSeconds
        return "首次索引需\(time)"
            + (later >= 30 ? "，长文件另需约 \(roughDuration(later))" : "")
    }
}

/// What code search leaves out, under a list of code folders.
struct CodeFolderNote: View {
    var body: some View {
        Label {
            Text("代码搜索读取源码、笔记本和仓库文档，跳过 git 忽略项、第三方依赖、"
                 + "生成代码、数据文件，以及疑似密钥或密码的文件。")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}
