import AppKit
import Testing
@testable import DigUpKit
@testable import ZhichuApp

@Suite @MainActor struct MailResultsTests {
    private func hit(attachment: Bool = true) -> SearchHit {
        var info = ["mail_id": "mail-1", "mail_subject": "第四季度采购报价与付款约定", "mail_sender": "王静 <wangjing@example.com>",
                    "mail_date": "1792828800", "mail_account": "工作邮箱", "mail_mailbox": "收件箱",
                    "mail_message_id": "quote+tag@example.invalid", "mail_original": "/Mail/12345.emlx"]
        if attachment { info["mail_attachment"] = "报价单.pdf" }
        return SearchHit(path: attachment ? "/cache/1-报价单.pdf" : "/cache/message.zhmail", kind: attachment ? .pdf : .mail,
            score: 1, z: 3, cosine: nil, keywordRank: 1, segment: attachment ? .page : .chunk, segmentID: 1,
            loc: attachment ? 3 : 1, locEnd: nil, excerpt: "含税«报价»", modified: 1, size: 20, info: info)
    }
    @Test func mailMetadataAndAttachmentPageArePresentedTogether() {
        let result = ResultRow(hit())
        #expect(result.name == "第四季度采购报价与付款约定")
        #expect(result.folder == "工作邮箱 · 收件箱")
        #expect(result.isMail)
        #expect(result.reason == "匹配附件《报价单.pdf》第 3 页")
        #expect(result.page == 3)
        #expect(result.openTitle == "打开原邮件")
        #expect(ResultSet([hit()]).groups.first?.kind == .mail)
        #expect(result.quickLookURL.path == "/cache/1-报价单.pdf")
        let body = ResultRow(hit(attachment: false))
        #expect(body.quickLookURL.path == "/Mail/12345.emlx")
        #expect(body.reason == "匹配邮件正文")
        #expect(body.mailLink?.absoluteString == "message://%3Cquote%2Btag%40example%2Einvalid%3E")
    }
    @Test func disabledMailSourceInvalidatesOnlyTheMailSelection() {
        var state = SearchFolders()
        state.select("mail:account:work", code: false)
        state.select("/code", code: true)
        let retained = state.validate(content: ["/folder", "mail:account:work"], code: ["/code"])
        #expect(!retained)
        let removed = state.validate(content: ["/folder"], code: ["/code"])
        #expect(removed)
        #expect(state.content == nil && state.code == "/code")
    }
}
