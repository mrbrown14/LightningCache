//
//  LightningCache.swift
//  LightningCache
//
//  Created by Jeremy Zhou on 9/23/17.
//  Copyright © 2017 Jeremy Zhou. All rights reserved.
//

import Foundation

public typealias CacheKey = CustomStringConvertible & Hashable
public let TimeIntervalMax = TimeInterval(Double.greatestFiniteMagnitude)

public class LightningCache<Key: CacheKey, Value: Cacheable> {

    public var name: String? = nil {
        didSet {
            memoryCache.name = name
            diskCache.name = name
        }
    }
    public let memoryCache: MemoryCache<Key, Value>
    public let diskCache: DiskCache<Key, Value>
    
    convenience public init?(name: String) {
        guard let folder = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory,
                                                               FileManager.SearchPathDomainMask.userDomainMask,
                                                               true).first else { return nil }
        let path = (folder as NSString).appendingPathComponent(name)
        self.init(path: path)
        self.name = name
    }
    
    public init?(path: String) {
        guard let disk = DiskCache<Key, Value>(path: path, threshold: UInt.max) else { return nil }
        diskCache = disk
        memoryCache = MemoryCache<Key, Value>()
        name = MD5Encoder.encodeMd5(string: path)
    }
    
}


extension LightningCache {
    
    /// Contain
    public func contains(_ key: Key) -> Bool {
        return memoryCache.contains(key) || diskCache.contains(key)
    }

    public func contains(_ key: Key, handle: ((Key, Bool) -> Void)?) {
        guard let hd = handle else { return }
        if memoryCache.contains(key) {
            hd(key, true)
        } else {
            diskCache.contains(key, handle: hd)
        }
    }
    
    /// Get
    public func valueForKey(_ key: Key) -> Value? {
        if let v = memoryCache.valueForKey(key) {
            return v
        } else if let v = diskCache.valueForKey(key) {
            memoryCache.setValue(v, withKey: key)
            return v
        } else {
            return nil
        }
    }
    
    public func valueForKey(_ key: Key, handle: ((_ key: Key, _ value: Value?) -> Void)?) {
        guard let hd = handle else { return }
        if let v = memoryCache.valueForKey(key) {
            hd(key, v)
        } else {
            diskCache.valueForKey(key, handle: hd)
        }
    }
    
    
    /// Set
    public func setValue(_ value: Value?, withKey key: Key) {
        memoryCache.setValue(value, withKey: key)
        diskCache.setValue(value, withKey: key)
    }
    
    public func setValue(_ value: Value?, withKey key: Key, handle: (() -> Void)?) {
        memoryCache.setValue(value, withKey: key)
        diskCache.setValue(value, withKey: key, handle: handle)
    }
    
    
    /// Remove
    public func removeValueForKey(_ key: Key) {
        diskCache.removeValueForKey(key)
        memoryCache.removeValueForKey(key)
    }
    
    public func removeAllValue() {
        diskCache.removeAllValue()
        memoryCache.removeAllValue()
    }
    
    public func removeValueForKey(_ key: Key, handle: (() -> Void)?) {
        diskCache.removeValueForKey(key, handle: handle)
        memoryCache.removeValueForKey(key)
    }
    
    public func removeAllValues(_ handle: (() -> Void)?) {
        diskCache.removeAllValues(handle)
        memoryCache.removeAllValue()
    }
    
    public func removeAllValues(_ progress: ((_ removedCount: UInt, _ totalCount: UInt) -> Void)?, handle: (() -> Void)?) {
        diskCache.removeAllValues(progress, handle: handle)
        memoryCache.removeAllValue()
    }
}
