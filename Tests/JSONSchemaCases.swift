//
//  JSONSchemaCases.swift
//  JSONSchema
//
//  Created by Kyle Fuller on 07/03/2015.
//  Copyright (c) 2015 Cocode. All rights reserved.
//

import Foundation
import XCTest
import JSONSchema

func fixture(named:String, forObject:AnyObject) -> NSData {
  let bundle = Bundle(for:object_getClass(forObject))
  let path = bundle.url(forResource: named, withExtension: nil)!
  let data = NSData(contentsOf: path)!
  return data
}

func JSONFixture(named:String, forObject:AnyObject) -> [[String:AnyObject]] {
  let data = fixture(named: named, forObject: forObject)
  let object: Any
  do {
    object = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions(rawValue: 0))
  } catch {
    fatalError()
  }
  return object as! [[String:AnyObject]]
}

class JSONSchemaCases: XCTestCase {
  func testEverything() {
    let bundle = Bundle(for: JSONSchemaCases.self)
    let fileManager = FileManager.default
    let files = fileManager.enumerator(atPath: bundle.resourcePath!)!.allObjects as! [String]
    let suites = files.filter { (path) -> Bool in
      let blacklist = [
        "ref.json",
        "refRemote.json",
        "definitions.json",

        // Optionals
        "bignum.json",
        "format.json",
      ]
      return path.hasSuffix(".json") && !blacklist.contains(path)
    }

    let cases = suites.map { (file) -> [Case] in
      let suite = JSONFixture(named: file, forObject: self)
      return suite.map(makeCase(filename: file))
    }

    let flatCases = cases.reduce([Case](), +)
    for c in flatCases {
      for (name, assertion) in makeAssertions(c: c) {
        // TODO: Improve testing
        print(name)
        assertion()
      }
    }
  }
}

struct Test {
  let description:String
  let data:AnyObject
  let value:Bool

  init(description:String, data:AnyObject, value:Bool) {
    self.description = description
    self.data = data
    self.value = value
  }
}

func makeTest(object:[String:AnyObject]) -> Test {
  return Test(description: object["description"] as! String, data: object["data"] as AnyObject!, value: object["valid"] as! Bool)
}

struct Case {
  let description:String
  let schema:[String:AnyObject]
  let tests:[Test]

  init(description:String, schema:[String:AnyObject], tests:[Test]) {
    self.description = description
    self.schema = schema
    self.tests = tests
  }
}

func makeCase(filename: String) -> (_ object: [String:AnyObject]) -> Case {
  return { object in
    let description = object["description"] as! String
    let schema = object["schema"] as! [String:AnyObject]
    let tests = (object["tests"] as! [[String: AnyObject]]).map(makeTest)
    let caseName = (filename as NSString).deletingPathExtension
    return Case(description: "\(caseName) \(description)", schema: schema, tests: tests)
  }
}

typealias Assertion = (String, () -> ())

func makeAssertions(c:Case) -> ([Assertion]) {
  return c.tests.map { test -> Assertion in
    return ("\(c.description) \(test.description)", {
      let result = validate(test.data, schema: c.schema)
      switch result {
      case .valid:
        XCTAssertEqual(result.valid, test.value, "Result is valid")
      case .invalid(let errors):
        XCTAssertEqual(result.valid, test.value, "Failed validation: \(errors)")
      }
    })
  }
}
