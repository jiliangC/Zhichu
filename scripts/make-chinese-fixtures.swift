#!/usr/bin/env swift
// Reproducible local smoke data. Only writes to the supplied folder, default .dev/fixtures.
import AppKit
import CoreText
import PDFKit
import ImageIO
import UniformTypeIdentifiers

let folder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".dev/fixtures")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let documents = [
    "财务预算.md": "# 第四季度预算\n市场推广预算为八万元，研发设备预算为三万元。所有报销必须附上发票，月底由财务统一核对。",
    "家常菜谱.txt": "今天做红烧茄子，先将茄子切块煎软，再加入酱油和少量糖。最后撒上葱花，搭配米饭食用。",
    "会议纪要.md": "知处项目本周优先完善中文搜索与文件预览，下周评测扫描文档。会议约定周五下午提交测试报告。",
    "城市出行.md": "从上海虹桥站出发，乘坐高铁前往杭州东站。到达后转乘地铁，下午参观西湖边的展览。",
]
for (name, text) in documents { try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8) }
func line(_ text: String, size: CGFloat = 20) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("PingFangSC-Regular" as CFString, size, nil),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): NSColor.black.cgColor,
    ]))
}
var page = CGRect(x: 0, y: 0, width: 595, height: 842)
let pdfURL = folder.appendingPathComponent("租房合同.pdf")
let pdf = CGContext(pdfURL as CFURL, mediaBox: &page, nil)!
for lines in [
    ["公寓租赁合同", "第一条：租期为一年，租金每月支付。", "第二条：房屋设施由双方在交付时确认。"],
    ["第六条：宠物与居住约定", "承租人可以在公寓内饲养猫狗等宠物。", "需要登记并保持卫生，不得影响邻居。", "合同编号 AB-2026-1024。"],
] {
    pdf.beginPDFPage(nil)
    for (i, text) in lines.enumerated() {
        pdf.textPosition = CGPoint(x: 55, y: 740 - i * 42)
        CTLineDraw(line(text), pdf)
    }
    pdf.endPDFPage()
}
pdf.closePDF()
let bitmap = CGContext(data: nil, width: 1400, height: 800, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
bitmap.setFillColor(NSColor.white.cgColor)
bitmap.fill(CGRect(x: 0, y: 0, width: 1400, height: 800))
for (i, text) in ["支付结果", "订单付款失败，请检查银行卡余额。", "错误编号 PAY-20261024"].enumerated() {
    bitmap.textPosition = CGPoint(x: 90, y: 650 - i * 110)
    CTLineDraw(line(text, size: 42), bitmap)
}
let screenshot = folder.appendingPathComponent("付款失败截图.png")
let destination = CGImageDestinationCreateWithURL(screenshot as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, bitmap.makeImage()!, nil)
CGImageDestinationFinalize(destination)
print("Created \(folder.path)")
