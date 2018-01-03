//
//  SwiftKVStoreTests.swift
//  SwiftCacheAppTests
//
//  Created by Jeremy Zhou on 11/22/17.
//  Copyright © 2017 Jeremy Zhou. All rights reserved.
//

import XCTest

@testable import LightningCache

class LightningCacheKVStoreTests: XCTestCase {
    
    let url = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var kvStore : KVStorage<String>?

    override func setUp() {
        super.setUp()

        if kvStore == nil {
            self.kvStore = KVStorage(path: url!.path, type: .automatic)
        }
    }
    
    override func tearDown() {
        super.tearDown()
        
        kvStore?.remove(largerThan: 0)
        kvStore?.remove(earlierThan: Int32.max)

    }
    
    func testSaveItemDb() {
        let d1 = Data(bytes: [1,2,3])

        XCTAssertEqual(kvStore?.totalItemCount, 0)

        //key1 = db only
        let k1 = "key1"
        let re1 = kvStore?.save(key: k1, value: d1)
        
        XCTAssertTrue(re1 == true, "saveItem failed with \(k1)")
        
        let s1 = kvStore?.itemForKey(key: k1)
        XCTAssertEqual(s1?.value, d1)
        
        XCTAssertEqual(kvStore?.itemsForKeys(keys: [k1])?.first, s1)

        XCTAssertEqual(kvStore?.totalItemSize, 3)

        XCTAssertEqual(kvStore?.itemValueForKey(key: k1), d1)
        
        XCTAssertEqual(kvStore?.itemValueForKey(key: k1), d1)
        
        XCTAssertEqual(kvStore?.totalItemCount, 1)
        
        XCTAssertEqual(kvStore?.totalItemSize, 3)
        
        XCTAssertNotNil(kvStore?.itemInfoForKey(key: k1))

    }
    
    func testSaveItemFile() {

        let key = "key2"
        let filename = "item2"
        let data = Data(bytes: [4,5,6])
        
        XCTAssertEqual(kvStore?.totalItemCount, 0)
        
        XCTAssertTrue(kvStore?.save(key: key, value: data, filename: filename) ?? false)
        XCTAssertEqual(kvStore?.itemInfoForKey(key: key)?.filename, filename)

        let item = kvStore?.itemsForKeys(keys: [key])?.first
        XCTAssertEqual(item?.filename, filename)
        XCTAssertEqual(item?.value, data)
        
        let re2 = kvStore?.save(key: "key3", value: data, filename: "item3")
        XCTAssert(re2 == true, "saveItem failed with key3")
        
        let re3 = kvStore?.save(item: KVStorageItem(key: "key4", value: data, filename: "item4", size: 0, modTime: 0, accessTime: 0))

        XCTAssert(re3 == true, "saveItem failed with key3")
        
        XCTAssertEqual(kvStore?.totalItemCount, 3)

    }
}
