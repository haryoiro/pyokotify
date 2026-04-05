import Foundation
import Testing

@testable import PyokotifyCore

@Suite("Template Expander Tests")
struct TemplateExpanderTests {

    @Test("すべての変数を展開")
    func expandAll() {
        let context = TemplateContext(
            cwd: "/Users/test/myproject",
            branch: "feature/test",
            eventName: "Notification",
            toolName: "Bash"
        )
        let result = TemplateExpander.expand(
            "[$dir:$branch] $event - $tool",
            with: context
        )
        #expect(result == "[myproject:feature/test] Notification - Bash")
    }

    @Test("$dirのみ展開")
    func expandDir() {
        let context = TemplateContext(cwd: "/path/to/myproject")
        let result = TemplateExpander.expand("Project: $dir", with: context)
        #expect(result == "Project: myproject")
    }

    @Test("$branchのみ展開")
    func expandBranch() {
        let context = TemplateContext(branch: "main")
        let result = TemplateExpander.expand("Branch: $branch", with: context)
        #expect(result == "Branch: main")
    }

    @Test("$cwdのみ展開")
    func expandCwd() {
        let context = TemplateContext(cwd: "/full/path/to/project")
        let result = TemplateExpander.expand("Path: $cwd", with: context)
        #expect(result == "Path: /full/path/to/project")
    }

    @Test("未定義の変数は空文字に置換")
    func expandMissing() {
        let context = TemplateContext(cwd: nil, branch: nil)
        let result = TemplateExpander.expand("dir=$dir branch=$branch", with: context)
        #expect(result == "dir= branch=")
    }

    @Test("変数を含まない文字列はそのまま返す")
    func noVariables() {
        let context = TemplateContext(cwd: "/path", branch: "main")
        let result = TemplateExpander.expand("Hello World!", with: context)
        #expect(result == "Hello World!")
    }

    @Test("同じ変数が複数回出現")
    func multipleOccurrences() {
        let context = TemplateContext(cwd: "/path/myproject")
        let result = TemplateExpander.expand("$dir - $dir - $dir", with: context)
        #expect(result == "myproject - myproject - myproject")
    }
}
