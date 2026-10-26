<p align="center"><img src="docs/media/icon.png" width="96" alt="知处图标"></p>

<h1 align="center">知处 · Zhichu</h1>

<p align="center"><b>记得内容，就能找到。</b><br>
用你记得的文字、画面或声音，找回 Mac 上的文件。</p>

<p align="center">
<a href="https://github.com/jiliangC/Zhichu/releases"><b>下载 Mac 版</b></a> ·
<a href="https://github.com/jiliangC/Zhichu/issues">反馈问题</a><br>
<sub>Apple Silicon · macOS 14 及以上 · 本地搜索 · 中文界面</sub>
</p>

<p align="center">
<a href="https://github.com/jiliangC/Zhichu/releases"><img src="https://img.shields.io/github/v/release/jiliangC/Zhichu?include_prereleases&amp;style=flat-square&amp;color=8B78CE" alt="版本"></a>
<a href="https://github.com/jiliangC/Zhichu/releases"><img src="https://img.shields.io/github/downloads/jiliangC/Zhichu/total?style=flat-square&amp;color=8B78CE" alt="下载"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-8B78CE?style=flat-square" alt="MIT License"></a>
</p>

<p align="center"><img src="docs/media/demo.gif" width="960" alt="知处使用演示：按画面搜索图片、查找截图文字、定位 PDF 命中页。演示使用虚构资料。"></p>

文件名想不起来，但你还记得它说过什么。知处把图片、截图、PDF、文档、音视频和主动开启的本地邮件放进同一个搜索入口，结合关键词与语义匹配，帮你从内容找回资料。

## 可以找什么

- **“海边的小狗”**：按画面描述寻找图片或视频片段。
- **“付款失败”**：查找截图里的提示文字。
- **“合同里关于宠物的约定”**：找到相关 PDF，并预览命中的页面。
- **“第四季度预算”**：搜索文档正文、表格或演示文稿中的内容。
- **“报价单”**：在已开启的 Apple Mail 来源中搜索邮件正文和已下载附件。
- **`code: 重试失败的请求`**：搜索指定项目中的代码，并在编辑器中定位。

除了描述内容，也可以直接输入文件名、编号、错误码或关键词。中文文件名支持全拼、首字母搜索，并提供基本的简繁匹配。

## 先选范围，再找内容

只索引你主动添加的文件夹。搜索时可以限定某个文件夹或已开启的邮件来源，再按截图、图片、文档、邮件、视频、音频筛选。

大窗口适合浏览缩略图和预览；快捷搜索面板适合随手查找。文档显示摘要，支持预览、打开、复制，以及在 Finder 中显示。

## 本地处理

文件内容、邮件缓存、索引和向量保存在这台 Mac 上，搜索不会把这些内容上传到服务器。

首次使用需要下载约 **865 MB** 的模型文件；也可以在设置中导入离线模型。模型就绪后可以离线搜索。源码构建和模型下载仍需要相应的网络访问。

Apple Mail 搜索默认关闭。开启后只读取已下载到本机的邮件与选定类型的附件，不连接邮箱服务器，也不会代替 Mail 下载邮件。此功能需要你在 macOS 中授予完全磁盘访问权限。

## 安装

1. 从 [Releases](https://github.com/jiliangC/Zhichu/releases) 下载适用于 Apple Silicon 的 DMG 或 ZIP。
2. 将 **知处.app** 放入“应用程序”，然后打开。
3. 选择搜索目录，等待模型准备及首次索引完成。
4. 按 **⇧⌘Space**，输入你记得的内容。

当前为公开预览版本，仅提供 Apple Silicon Mac 构建。0.1.13 起的官方安装包使用 Developer ID 签名并完成 Apple 公证。历史版本的公证状态以对应 Release 说明为准。

## 快捷操作

| 快捷键 | 操作 |
|---|---|
| ⇧⌘Space | 打开快捷搜索面板，可在设置中修改 |
| ↑ / ↓ | 选择结果 |
| ↩ | 打开选中结果 |
| Space | 快速查看 |
| ⌘↩ | 在 Finder 中显示 |
| ⌘C | 复制选中文件 |
| ⌘O | 在大窗口中查看搜索结果 |

知处常驻菜单栏，可以查看索引进度、暂停索引或打开设置。

## 支持的内容

| 类型 | 搜索与预览 |
|---|---|
| 图片、截图 | 画面语义、OCR 文字；支持 PNG、JPEG、HEIC 等常见格式 |
| PDF | 逐页读取，支持扫描页识别及命中页预览 |
| 文档 | TXT、Markdown、RTF、Word、HTML、ODT 等常见内容 |
| 表格、幻灯片 | XLSX、PPTX 等；PPTX 保留幻灯片边界并预览命中页 |
| 音频、视频 | 分段建立索引，结果可定位对应时间片段 |
| Apple Mail | 邮件主题、发件人、正文和已下载附件；附件命中可预览对应页 |
| 代码 | 单独选择目录、单独建立索引，使用 `code:` 查询 |

文档分页和 Office 预览受文件格式及 macOS 渲染能力影响；并非所有格式都具有完全一致的页码定位能力。加密、损坏、未下载或不支持的内容可能无法索引。

## 后台更新

- 文件变化后增量更新，不需要每次重建整个资料库。
- 邮件来源开启后，通常每分钟检查一次本机邮件变化；也可手动重新检查。
- 开启 **“仅接通电源时更新索引”** 后，使用电池时暂停文件、邮件、代码的索引更新及邮件同步，接电后继续。已有索引仍可搜索。
- 支持手动暂停、指定索引时段、排除目录和文件类型。
- 文件夹和邮件分别显示处理进度、可搜索数量及失败情况。

首次索引较多资料需要一些时间。搜索结果会随着处理完成逐步补齐；新增邮件还需要先由 Mail 下载到本机。

## 从源码构建

需要 Apple Silicon Mac、macOS 14+、Xcode 26（Swift 6.2 或更新版本）和 Git。构建脚本会准备固定版本的模型运行库。

```sh
git clone https://github.com/jiliangC/Zhichu.git
cd Zhichu
./build.sh
open build.noindex/知处.app
```

运行测试：

```sh
swift test
```

未配置签名身份时使用临时签名。需要固定签名时，可将自己的代码签名身份写入本机 `.sign-id`；该文件不会提交到 Git。

## 常见问题

**必须联网才能搜索吗？**
模型下载并完成索引后，已有内容可以离线搜索。

**为什么刚收到的邮件还搜不到？**
邮件必须先下载到 Mail 本地，再由知处检查、解析并完成索引；更新也会受到电源条件和暂停状态影响。

**会自动更新应用吗？**
从 0.1.12 开始，可在菜单栏点击“检查更新”。启用“自动检查更新”后每天检查一次，发现新版本时提醒，由你确认下载、安装和重新启动。更新列表及安装包使用 Ed25519 签名，安装时同时校验应用代码签名。0.1.11 及更早版本需先从 [Releases](https://github.com/jiliangC/Zhichu/releases) 手动安装一次新版本。

**如何反馈问题？**
请在 [Issues](https://github.com/jiliangC/Zhichu/issues) 中提供版本、macOS 版本与复现步骤。截图和日志可能包含文件名、搜索词或邮件内容，请先移除私人信息。

## 开源组件

知处使用 [EmbeddingGemma 2](https://huggingface.co/google/embeddinggemma-2)、[llama.cpp](https://github.com/ggml-org/llama.cpp)、[Sparkle](https://sparkle-project.org/) 和 MimeFoundation 等组件。相关版权及第三方许可声明随源码与应用提供，见 [许可证](LICENSE) 和 [第三方许可](Resources/Acknowledgements.txt)。

## 许可证

[MIT](LICENSE)
