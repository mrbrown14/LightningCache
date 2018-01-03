//
//  LightningCacheTests.swift
//  LightningCacheTests
//
//  Created by Jeremy Zhou on 12/23/17.
//  Copyright © 2017 jz. All rights reserved.
//

import XCTest
@testable import LightningCache


class CustomClass {
    
}

class LightningCacheTests: XCTestCase {
    
    let memCache = MemoryCache<String, Any>()

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testMemCache() {
        let d1 = Data(bytes: [1,2,3,4])
        let d2 = "string_abc"
        let d3 = 1024
        let d4 = [1,2,3,4]
        let d5 = ["key": "dict_abc"]
        
        memCache.setValue(d1, withKey: "key1")
        memCache.setValue(d2, withKey: "key2")
        memCache.setValue(d3, withKey: "key3")
        memCache.setValue(d4, withKey: "key4")
        memCache.setValue(d5, withKey: "key5")
        memCache.setValue(CustomClass(), withKey: "key6")
        

        XCTAssertEqual(memCache["key1"] as? Data, d1)
        
        XCTAssertEqual(memCache.totalCount, 6)
        
        memCache.trimToCount(4)
        
        XCTAssertEqual(memCache.totalCount, 4)
        XCTAssertFalse(memCache.contains("key2"))
        
    }

    
}
