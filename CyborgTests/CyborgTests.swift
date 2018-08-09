//
//  Copyright © Uber Technologies, Inc. All rights reserved.
//

import XCTest
@testable import Cyborg

class CyborgTests: XCTestCase {
    
    let string = """
 <vector xmlns:android="http://schemas.android.com/apk/res/android"
     android:height="64dp"
     android:width="64dp"
     android:viewportHeight="600"
     android:viewportWidth="600" >
     <group
         android:name="rotationGroup"
         android:pivotX="300.0"
         android:pivotY="300.0"
         android:rotation="45.0" >
         <path
             android:name="v"
             android:fillColor="#000000"
             android:pathData="M300,70 l 0,-70 70,70 0,0 -70,70z" />
     </group>
 </vector>
"""
    
    func test_Deserialize() {
        let data = string.data(using: .utf8)!
        let callbackIsCalled = expectation(description: "Callback is called")
        VectorDrawable
            .create(from: data) { result in
                callbackIsCalled.fulfill()
                switch result {
                case .ok(let drawable):
                    XCTAssert(drawable.viewPortWidth == 600)
                    XCTAssert(drawable.viewPortHeight == 600)
                    XCTAssert(drawable.groups[0].paths[0].data.count != 0)
                    let noResizing = CGSize(width: 1, height: 1)
                    let path = drawable.createPaths(in: noResizing)
                    var expected = CGMutablePath()
                    var relativeTo = CGPoint(x: 300, y: 70)
                    expected.move(to: relativeTo)
                    let list = [
                        CGPoint(x: 0, y: -70),
                        CGPoint(x: 70, y: 70),
                        CGPoint(x: 0, y: 0),
                        CGPoint(x: -70, y: 70)
                    ]
                    for point in list {
                        let point = point.add(relativeTo)
                        expected.addLine(to: point)
                        relativeTo = point
                    }
                    expected.closeSubpath()
                    let transform: CGAffineTransform = drawable
                        .groups[0]
                        .transform.affineTransform(in: noResizing)
                    expected = expected
                        .apply(transform: transform)
                        .mutableCopy()!
                    XCTAssertEqual(path[0], expected)
                case .error(let error):
                    XCTFail(error)
                }
        }
        wait(for: [callbackIsCalled], timeout: 0.001) // note: this is actually synchronous, but just in case it isn't called, check to make sure it actually happens
    }
    
    func test_move() {
        let move = "M300,70"
        let result = parseMoveAbsolute()(move, move.startIndex)
        let path = CGMutablePath()
        let expected = CGMutablePath()
        let movement: PriorContext = CGPoint(x: 300, y: 70).asPriorContext
        expected.move(to: movement.point)
        switch result {
        case .ok(let pathSegment, _):
            let next = pathSegment(.zero, path, .init(width: 1, height: 1))
            XCTAssertEqual(path, expected)
            XCTAssertEqual(next, movement)
        case .error(let error):
            XCTFail(error)
        }
    }
    
    func test_closePath() {
        let close = "   z"
        let result = parseClosePath()(close, close.startIndex)
        let expected = CGMutablePath()
        expected.closeSubpath()
        switch result {
        case .ok(let wrapped, let index):
            let path = CGMutablePath()
            _ = wrapped(.zero, path, .zero)
            XCTAssertEqual(index, close.endIndex)
            XCTAssertEqual(path, expected)
        case .error(let error):
            XCTFail(error)
        }
    }
    
    func test_line() {
        let lineData = "l 1,0 2,1 3,4"
        let expected = CGMutablePath()
        let points = [(1,0), (2,1), (3,4)].map(CGPoint.init)
        var last: CGPoint = .zero
        for point in points {
            let point = point.add(last)
            last = point
            expected.addLine(to: point)
        }
        switch parseLine()(lineData, lineData.startIndex) {
        case .ok(let result, _):
            let path = createPath(from: result)
            XCTAssertEqual(path, expected)
        case .error(let error):
            XCTFail(error)
        }
    }
    
    func test_pair() {
        let first = "a"
        let second = "b"
        let expected = first + second
        let parser = pair(of: literal(first), literal(second))
        var result = parser(expected, expected.startIndex)
        switch result {
        case .ok(let str, _):
            XCTAssertEqual(str.0 + str.1, expected)
        case .error(let error):
            XCTFail(error)
        }
        for failureCase in [first, second] {
            result = parser(failureCase, failureCase.startIndex)
            switch result {
            case .ok(let incorrectResult, _):
                XCTFail("Succeeded: found \(incorrectResult)")
            case .error(_): break
            }
        }
    }
    
    func test_oneorMoreOf() {
        let str = "a"
        let contents = "aaa"
        XCTAssertEqual(oneOrMore(of: literal(str))(contents, contents.startIndex).asOptional?.0,
                       Array(repeating: str, count: 3))
        let contents2 = "   a a   a"
        XCTAssertEqual(oneOrMore(of: consumeTrivia(before: literal(str)))(contents2, contents2.startIndex).asOptional?.0,
                       Array(repeating: str, count: 3))
    }
    
    func test_int_parser() {
        let str = "-432"
        switch Cyborg.number()(str, str.startIndex) {
        case .ok(let result, _):  XCTAssertEqual(result, -432)
        case .error(let error): XCTFail(error)
        }
        let str2 = "40"
        switch Cyborg.number()(str2, str2.startIndex) {
        case .ok(let result, _):  XCTAssertEqual(result, 40)
        case .error(let error): XCTFail(error)
        }
    }
    
    func test_parse_curve() {
        let curve = "c2,2 3,2 8,2"
        let start = CGPoint(x: 6, y: 2)
        let expected = CGMutablePath()
        expected.move(to: start)
        expected.addCurve(to: CGPoint(x: 8, y: 2).add(start),
                          control1: CGPoint(x: 2, y: 2).add(start),
                          control2: CGPoint(x: 3, y: 2).add(start))
        switch parseCurve()(curve, curve.startIndex) {
        case .ok(let wrapped, _):
            let result = CGMutablePath()
            result.move(to: start)
            _ = wrapped(start.asPriorContext, result, CGSize(width: 1, height: 1))
            XCTAssertEqual(result, expected)
        case .error(let error):
            XCTFail(error)
        }
    }

//    func test_reflection() {
//        let first = CGPoint(x: 0, y: 0)
//        let second = CGPoint(x: 1, y: 1)
//        let point = CGPoint(x: 0.25, y: 0.25)
//        let result = point.reflected(across: first, second)
//        let expected = CGPoint(x: 0.75, y: 0.75)
//        XCTAssertEqual(result, expected)
//    }
    
}

extension CGPoint {
    
    init(_ xy: (CGFloat, CGFloat)) {
        self.init(x: xy.0, y: xy.1)
    }
    
}

func createPath(from: PathSegment, start: PriorContext = .zero) -> CGMutablePath {
    let path = CGMutablePath()
    let identity = CGSize(width: 1, height: 1)
    _ = from(start, path, identity)
    return path
}
