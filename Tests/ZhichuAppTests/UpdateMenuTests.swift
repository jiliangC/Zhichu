import AppKit
import Testing
@testable import ZhichuApp

@Suite @MainActor struct UpdateMenuTests {
    @Test func checkActionRevalidatesWhenUpdateSessionChanges() throws {
        let application = NSApplication.shared
        var available = true
        var checks = 0
        let item = ActionMenuItem("检查更新", isEnabled: { available }) { checks += 1 }
        let validator = try #require(item.target as? any NSMenuItemValidation)
        #expect(validator.validateMenuItem(item))
        application.sendAction(try #require(item.action), to: item.target, from: item)
        #expect(checks == 1)
        available = false
        #expect(!validator.validateMenuItem(item))
        // An already queued click must not open a second update session.
        application.sendAction(try #require(item.action), to: item.target, from: item)
        #expect(checks == 1)
        available = true
        #expect(validator.validateMenuItem(item))
    }
}
