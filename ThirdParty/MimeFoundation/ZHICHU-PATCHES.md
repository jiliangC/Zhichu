Upstream: https://github.com/migueldeicaza/MimeFoundation
Revision: dcb6746729d20cf00c42ad6453b4637a075f7d0b
License: MIT (see LICENSE)

Vendored source is kept for reproducible, reviewed MIME fixes:
- Multipart boundaries are split at original byte offsets. Upstream converted Latin-1 body strings to UTF-8, corrupting 8-bit Chinese text and binary attachments, and normalized binary newlines.
- Apply ParserOptions.maxMimeDepth to multipart and embedded-message parsing, before recursion.
- Minimal package manifest omits upstream benchmarks, tests and documentation plugins. Runtime cryptographic APIs remain upstream code; Zhichu does not decrypt encrypted email.

Regression checks live in Tests/DigUpKitTests/MailSourceTests.swift.
