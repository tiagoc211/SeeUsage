import Foundation

public struct TestAssertionFailure: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

open class XCTestCase {
    public init() {}
    open func setUp() {}
    open func tearDown() {}
}

public func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let valA = try a()
        let valB = try b()
        if valA != valB {
            let desc = "[\(file):\(line)] Assertion failed: \(valA) != \(valB). \(message())"
            print(desc)
            fatalError(desc)
        }
    } catch {
        let desc = "[\(file):\(line)] Assertion threw error: \(error). \(message())"
        print(desc)
        fatalError(desc)
    }
}

public func XCTAssertNotEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        let valA = try a()
        let valB = try b()
        if valA == valB {
            let desc = "[\(file):\(line)] Assertion failed: \(valA) == \(valB). \(message())"
            print(desc)
            fatalError(desc)
        }
    } catch {
        let desc = "[\(file):\(line)] Assertion threw error: \(error). \(message())"
        print(desc)
        fatalError(desc)
    }
}

public func XCTAssertNil(_ a: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        if let val = try a() {
            let desc = "[\(file):\(line)] Assertion failed: expected nil, got \(val). \(message())"
            print(desc)
            fatalError(desc)
        }
    } catch {
        let desc = "[\(file):\(line)] Assertion threw error: \(error). \(message())"
        print(desc)
        fatalError(desc)
    }
}

public func XCTAssertNotNil(_ a: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        if try a() == nil {
            let desc = "[\(file):\(line)] Assertion failed: expected not nil. \(message())"
            print(desc)
            fatalError(desc)
        }
    } catch {
        let desc = "[\(file):\(line)] Assertion threw error: \(error). \(message())"
        print(desc)
        fatalError(desc)
    }
}

public func XCTAssertTrue(_ a: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    do {
        if try !a() {
            let desc = "[\(file):\(line)] Assertion failed: expected true. \(message())"
            print(desc)
            fatalError(desc)
        }
    } catch {
        let desc = "[\(file):\(line)] Assertion threw error: \(error). \(message())"
        print(desc)
        fatalError(desc)
    }
}

public func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    let desc = "[\(file):\(line)] Failure: \(message)"
    print(desc)
    fatalError(desc)
}
