import Testing
@testable import ZhichuApp

@Suite struct SearchFoldersTests {
    @Test func contentAndCodeSelectionsAreIndependentAndCanBeReset() {
        var state = SearchFolders()
        #expect(state.selected(code: false) == nil)
        state.select("/资料/Test", code: false)
        state.select("/项目/App", code: true)
        #expect(state.selected(code: false) == "/资料/Test")
        #expect(state.selected(code: true) == "/项目/App")
        state.select(nil, code: true)
        #expect(state.selected(code: true) == nil)
        #expect(state.selected(code: false) == "/资料/Test")
    }

    @Test func removedRootsResetOnlyTheirSelection() {
        var state = SearchFolders()
        state.select("/资料/Test", code: false)
        state.select("/项目/App", code: true)
        #expect(state.validate(content: ["/资料/Test"], code: ["/项目/App"]) == false)
        let removedContent = state.validate(content: ["/下载"], code: ["/项目/App"])
        #expect(removedContent)
        #expect(state.content == nil)
        #expect(state.code == "/项目/App")
        let removedCode = state.validate(content: [], code: [])
        #expect(removedCode)
        #expect(state == SearchFolders())
    }
}
