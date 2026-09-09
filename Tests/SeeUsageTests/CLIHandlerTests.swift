import XCTest
@testable import SeeUsage

final class CLIHandlerTests: XCTestCase {
    @MainActor
    func testProfileAliasGeneration() {
        XCTAssertEqual(CLIHandler.profileAlias(name: "Pessoal"), "cxp")
        XCTAssertEqual(CLIHandler.profileAlias(name: "Codex Pessoal"), "cxp")
        XCTAssertEqual(CLIHandler.profileAlias(name: "Trabalho"), "cxt")
        XCTAssertEqual(CLIHandler.profileAlias(name: "Codex Trabalho"), "cxt")
        XCTAssertEqual(CLIHandler.profileAlias(name: "Outra Conta"), "outra-conta")
    }

    @MainActor
    func testCLIHandlerHelp() async {
        let handled = await CLIHandler.handle(arguments: ["seeusage", "--help"])
        XCTAssertTrue(handled)
    }

    @MainActor
    func testCLIHandlerShellInit() async {
        let handled = await CLIHandler.handle(arguments: ["seeusage", "--shell-init", "zsh"])
        XCTAssertTrue(handled)
    }
}
