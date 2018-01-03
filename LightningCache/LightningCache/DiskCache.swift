//
//  DiskCache.swift
//  LightningCache
//
//  Created by Jeremy Zhou on 9/23/17.
//  Copyright © 2017 Jeremy Zhou. All rights reserved.
//

import Foundation

public class DiskCache<Key: CacheKey, Value: Hashable> {

    public typealias ValueType = Value
    public typealias KeyType = Key

    fileprivate let lock = DispatchSemaphore(value: 1)
    fileprivate let queue = DispatchQueue(label: "com.lightningcache.disk")
    fileprivate let kvs: KVStorage<Key>

    public var name: String?
    public let path: String

    public var countLimit = UInt.max
    public var costLimit = UInt.max
    public var freeDiskSpaceLimit = UInt.max
    public var ageLimit = TimeIntervalMax
    public var autoTrimInterval = TimeInterval(5)


    public var totalCount: UInt { return 0 }
    public var totalCost: UInt { return 0 }


    public var customFilename: ((String) -> String)?
    public func totalCount(_ calculate: ((_ count: UInt) -> Void)?) {
    
    }

    public required init?(path: String, threshold: UInt) {
        self.path = path
        
        var type = KVStorageType.automatic
        if threshold == 0 {
            type = .file
        } else if threshold == UInt.max {
            type = .sqlite
        }
        
        guard let kvStorage = KVStorage<Key>(path: path, type: type) else { return nil }
        kvs = kvStorage
    }    
    
    private func fileNameForKey(_ key: String) -> String {
        if let custom = customFilename {
            return custom(key)
        } else {
            return MD5Encoder.encodeMd5(string: key)
        }
    }
    
    
    public func contains(_ key: Key) -> Bool {
        _ = lock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        defer { lock.signal() }
        return kvs.containItemforKey(key: key.description)
    }
    
    public func contains(_ key: Key, handle: ((Key, Bool) -> Void)?) {
        queue.async {[weak self] in
            guard let `self` = self else { return }
            handle?(key, self.contains(key))
        }
    }
    
    public func valueForKey(_ key: Key) -> Value? {
        _ = lock.wait(timeout: DispatchTime(uptimeNanoseconds: UInt64.max))
        let item = kvs.itemForKey(key: key.description)
        lock.signal()
        
        return item?.value as? Value
//        guard let data = item?.value else { return nil }
//        return Value.build(data) as? Value
    }
    
    public func valueForKey(_ key: Key, handle: ((_ key: Key, _ value: Value?) -> Void)?) {
        queue.async { [weak self] in
            guard let `self` = self else { return }
            let v = self.valueForKey(key)
            handle?(key, v)
        }
    }
    
    public func setValue(_ value: Value?, withKey key: Key) {
//        let data = value?.mapToData()
        let data = value
        switch kvs.type {
        case .sqlite:
            _ = kvs.save(key: key.description, value: data as? Data)
        default:
            let fn = fileNameForKey(key.description)
            _ = kvs.save(key: key.description, value: data as? Data, filename: fn)
        }
    }
    
    public func setValue(_ value: Value?, withKey key: Key, handle: (() -> Void)?) {
        queue.async {[weak self] in
            guard let `self` = self else { return }
            self.setValue(value, withKey: key)
            handle?()
        }
    }
    
    public func removeValueForKey(_ key: Key) {
        _ = kvs.remove(forKey: key.description)
    }
    public func removeAllValue() {
        _ = kvs.remove(allItems: ())
    }
    public func removeValueForKey(_ key: Key, handle: (() -> Void)?) {
        queue.async { [weak self] in
            guard let `self` = self else { return }
            self.removeValueForKey(key)
        }
    }
    public func removeAllValues(_ handle: (() -> Void)?) {
        queue.async { [weak self] in
            guard let `self` = self else { return }
            self.removeAllValue()
        }
    }
    public func removeAllValues(_ progress: ((_ removedCount: UInt, _ totalCount: UInt) -> Void)?, handle: (() -> Void)?) {
        queue.async { [weak self] in
            guard let `self` = self else { return }
            self.kvs.remove(allItems: { (rm: Int32, total: Int32) in
                progress?(UInt(rm), UInt(total))
                }, finish: { (flag: Bool) in
                handle?()
            })
        }
    }
    
    public func trimToCount(_ count: UInt) {
        guard count < UInt.max else { return }
        _ = kvs.remove(toFitCount: Int32(count))
    }
    
    public func trimToCost(_ cost: UInt) {
        guard cost < UInt.max else { return }
        _ = kvs.remove(toFitSize: Int32(cost))
    }
    
    public func trimToAge(_ age: TimeInterval) {
        if age <= 0 {
            removeAllValue()
        } else {
            let timestamp = TimeInterval(time(nil))
            guard timestamp > age else { return }
            let age = timestamp - ageLimit
            guard age < TimeIntervalMax else { return }
            _ = kvs.remove(earlierThan: Int32(age))
        }
    }
    
    public func trimToCount(_ count: UInt, handle: (() -> Void)?) {
        queue.async { [weak self] in
            guard let `self` = self else { return }
            self.trimToCount(count)
            handle?()
        }
    }
    
    public func trimToCost(_ cost: UInt, handle: (() -> Void)?) {
        queue.async {[weak self] in
            guard let `self` = self else { return }
            self.trimToCost(cost)
            handle?()
        }
    }
    
    public func trimToAge(_ age: TimeInterval, handle: (() -> Void)?) {
        queue.async {[weak self] in
            guard let `self` = self else { return }
            self.trimToAge(age)
            handle?()
        }
    }
    
    public func trimToFreeDiskSpace(_ space: UInt) {
        guard space > 0 else { return }
        let tc = totalCost
        guard tc > 0  else { return }
        let fs = FileManager.getDiskSpaceFree()
        guard fs > 0 else { return }
        let needTrimBytes = Int64(space) - fs
        guard needTrimBytes > 0  else { return }
        let costLimit = Int64(totalCost) - needTrimBytes
        guard costLimit > 0 else { return }
        trimToCost(UInt(costLimit))
    }
}


extension FileManager {
    internal static func getDiskSpaceFree() -> Int64 {
        guard let attr = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) else { return 0 }
        guard let size = attr[FileAttributeKey.systemFreeSize] as? Int64 else { return 0 }
        return size
    }
}
