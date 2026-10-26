import AppKit
import Observation
import SwiftUI

/// Ephemeral search state: content and code libraries have independent directory selections.
nonisolated struct SearchFolders: Equatable, Sendable {
    private(set) var content: String?
    private(set) var code: String?

    func selected(code: Bool) -> String? { code ? self.code : content }

    mutating func select(_ folder: String?, code: Bool) {
        if code { self.code = folder } else { content = folder }
    }

    /// A removed root must not silently leave the next query restricted to an unavailable selection.
    @discardableResult mutating func validate(content roots: [String], code codeRoots: [String]) -> Bool {
        let old = self
        if let content, !roots.contains(content) { self.content = nil }
        if let code, !codeRoots.contains(code) { self.code = nil }
        return old != self
    }

    static func name(_ path: String) -> String { URL(fileURLWithPath: path).lastPathComponent }
}

/// A native menu keeps menu tracking, keyboard navigation and panel focus in AppKit.
/// Both search surfaces use the same control and the same choices.
struct SearchScopePicker: NSViewRepresentable {
    let folder: String?
    let roots: [URL]
    var compact = false
    var mail: MailController? = nil
    let select: (String?) -> Void
    let manage: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.open(_:)))
        button.isBordered = false
        button.cell?.lineBreakMode = .byTruncatingMiddle
        button.wantsLayer = true
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 1
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        let name = mail?.scopeName(folder) ?? folder.map(SearchFolders.name) ?? "所有文件夹"
        let color = NSColor(srgbRed: 0.69, green: 0.61, blue: 0.91, alpha: 1)
        let label = NSMutableAttributedString()
        if let image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: compact ? 13 : 12, weight: .medium))?
            .withSymbolConfiguration(.init(paletteColors: [color])) {
            let attachment = NSTextAttachment()
            attachment.image = image
            label.append(NSAttributedString(attachment: attachment))
        }
        label.append(NSAttributedString(string: "  范围：\(name)", attributes: [
            .font: NSFont.systemFont(ofSize: compact ? 13 : 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]))
        button.attributedTitle = label
        button.layer?.borderColor = color.withAlphaComponent(folder == nil ? 0.25 : 0.7).cgColor
        button.layer?.backgroundColor = color.withAlphaComponent(folder == nil ? 0.03 : 0.08).cgColor
        button.toolTip = folder?.hasPrefix("mail:") == true ? "仅搜索所选邮件来源" : folder.map { "仅搜索 \(tildePath($0)) 及其子文件夹" } ?? (mail?.isAvailable == true ? "搜索已添加的文件夹和主动开启的邮件来源" : "搜索所有已添加的文件夹")
        button.setAccessibilityLabel("搜索范围：\(name)")
        button.setAccessibilityIdentifier("searchScopePicker")
    }

    final class Coordinator: NSObject {
        var parent: SearchScopePicker
        init(_ parent: SearchScopePicker) { self.parent = parent }

        @objc func open(_ sender: NSButton) {
            let menu = NSMenu()
            menu.autoenablesItems = false
            menu.minimumWidth = 240
            let heading = NSMenuItem(title: "搜索范围", action: nil, keyEquivalent: "")
            heading.isEnabled = false
            menu.addItem(heading)
            add(parent.mail?.isAvailable == true ? "所有来源" : "所有文件夹", folder: nil, to: menu)
            for root in parent.roots { add(root.lastPathComponent, folder: root.path, to: menu) }
            if let mail = parent.mail, mail.isAvailable {
                menu.addItem(.separator())
                add("所有邮件", folder: "mail:all", to: menu)
                for account in mail.activeAccounts { add(account.name, folder: "mail:account:" + account.id, to: menu) }
            }
            menu.addItem(.separator())
            let manage = NSMenuItem(title: "管理索引文件夹…", action: #selector(manageFolders), keyEquivalent: "")
            manage.target = self
            manage.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
            menu.addItem(manage)
            let below = sender.isFlipped ? sender.bounds.maxY + 5 : sender.bounds.minY - 5
            menu.popUp(positioning: nil, at: NSPoint(x: sender.bounds.maxX - 240, y: below), in: sender)
        }

        private func add(_ name: String, folder: String?, to menu: NSMenu) {
            let item = NSMenuItem(title: name, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = folder
            item.state = parent.folder == folder ? .on : .off
            item.image = NSImage(systemSymbolName: folder == nil ? "square.stack" : "folder", accessibilityDescription: nil)
            if let folder, !folder.hasPrefix("mail:") {
                let title = NSMutableAttributedString(string: name, attributes: [.font: NSFont.menuFont(ofSize: 13)])
                title.append(NSAttributedString(string: "\n" + tildePath(folder), attributes: [
                    .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
                ]))
                item.attributedTitle = title
                item.toolTip = folder
            }
            menu.addItem(item)
        }

        @objc private func choose(_ item: NSMenuItem) { parent.select(item.representedObject as? String) }
        @objc private func manageFolders() { parent.manage() }
    }
}
