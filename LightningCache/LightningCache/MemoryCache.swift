//
//  MemoryCache.swift
//  LightningCache
//
//  Created by Jeremy Zhou on 9/23/17.
//  Copyright © 2017 Jeremy Zhou. All rights reserved.
//

import Foundation
import UIKit


public class MemoryCache<Key: Hashable, Value: Cacheable> {
    
    public typealias OPerationBlock = (_ cache: MemoryCache<Key,Value>) -> Void
    public typealias ValueType = Value
    public typealias KeyType = Key
    
    typealias Node = LinkedMapNode<Key, Value>
    
    fileprivate let lru = LinkedMap<Key,Value>()
    fileprivate let lock = Mutex()
    fileprivate let queue = DispatchQueue(label: "com.lightningcache.memory")

    
    public var totalCount: UInt {
        lock.lock()
        defer { lock.unlock() }
        return lru.totalCount
    }
    public var totalCost: UInt {
        lock.lock()
        defer { lock.unlock() }
        return lru.totalCost
    }
    
    public var name: String?
    public var countLimit = UInt.max
    public var costLimit = UInt.max
    public var ageLimit = TimeIntervalMax
    public var autoTrimInterval = TimeInterval(5)
    public var shouldremoveAllValuesOnMemoryWarning = true
    public var shouldremoveAllValuesWhenEnteringBackground = true
    
    
    public var didReceiveMemoryWarningBlock: OPerationBlock?
    public var didEnterBackgroundBlock: OPerationBlock?
    
    
    public var releaseOnMainThread = false
    public var releaseAsynchronously = false
    
    
    // MARK: - application lifetime observers
    
    init() {
#if os(iOS)
    NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache.appDidEnterBackgroundNotification(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(MemoryCache.appDidReceiveMemoryWarningNotification(_:)), name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
#endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        lru.removeAll()
    }
    
    
    public func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return lru.contains(key)
    }
    
    subscript(_ key: Key) -> Value? {
        get {
            return valueForKey(key)
        }
    }

    
    public func valueForKey(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let node = lru[key] else { return nil }
        node.time = Date().timeIntervalSince1970
        lru.bringNodeToHead(node: node)
        return node.value
    }
    
    public func setValue(_ value: Value?, withKey key: Key) {
        setValueForKey(value, forKey: key, withCost: 0)
    }
    
    public func setValueForKey(_ value: Value?, forKey key: Key, withCost cost: UInt) {
        guard let v = value else {
            removeValueForKey(key)
            return
        }
        lock.lock()
        defer { lock.unlock() }
        lru[key] = Node(key: key, value: value, cost: cost)
        
        
    }
    
    public func removeValueForKey(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }
        guard let node = lru[key] else { return }
        lru.removeNode(node: node)
    }
    
    public func removeAllValue() {
        lock.lock()
        defer { lock.unlock() }
        lru.removeAll()
    }
    
    
    // MARK: - trim operations
    public func trimToCount(_ count: UInt) {
        guard count > 0 else {
            removeAllValue()
            return
        }
        lock.lock()
        guard lru.totalCount > count else {
            return
        }
        lock.unlock()
        var buffer = [Node]()
        var finish = false
        while !finish {
            if lock.tryLock() == 0 {
                if lru.totalCount > count,
                    let tail = lru.removeTailNode() {
                    buffer.append(tail)
                } else {
                    finish = true
                }
                lock.unlock()
            } else {
                usleep(10000)
            }
        }
        
        if !buffer.isEmpty {
            let q = releaseOnMainThread ? DispatchQueue.main : queue
            q.async {
                buffer.removeAll()
            }
        }
    }
    
    public func trimToCost(_ cost: UInt) {
        guard cost > 0 else {
            removeAllValue()
            return
        }
        lock.lock()
        guard lru.totalCost > cost else{
            return
        }
        lock.unlock()
        var buffer = [Node]()
        var finish = false
        while !finish {
            if lock.tryLock() == 0 {
                if lru.totalCost >= cost,
                    let tail = lru.removeTailNode() {
                    buffer.append(tail)
                } else {
                    finish = true
                }
                lock.unlock()
            } else {
                usleep(10000)
            }
        }
        
        if !buffer.isEmpty {
            let q = releaseOnMainThread ? DispatchQueue.main : queue
            q.async {
                buffer.removeAll()
            }
        }

    }
    
    public func trimToAge(_ age: TimeInterval) {
        guard age > 0 else {
            removeAllValue()
            return
        }
        let now = Date().timeIntervalSince1970
        lock.lock()
        guard let tail = lru.tail else {
            lock.unlock()
            return
        }
        if now - tail.time <= TimeInterval(age) {
            lock.unlock()
            return
        }
        lock.unlock()
        var buffer = [Node]()
        var finish = false
        while !finish {
            if lock.tryLock() == 0 {
                guard let tail = lru.tail else {
                    lock.unlock()
                    return
                }
                if now - tail.time > TimeInterval(age),
                    let tail = lru.removeTailNode() {
                    buffer.append(tail)
                    lock.unlock()
                } else {
                    finish = true
                }
                lock.unlock()
            } else {
                usleep(10000)
            }
        }
        
        if !buffer.isEmpty {
            let q = releaseOnMainThread ? DispatchQueue.main : queue
            q.async {
                buffer.removeAll()
            }
        }
    }

    // MARK: - system notifications
    @objc fileprivate func appDidReceiveMemoryWarningNotification(_ notification: Notification) {
        didReceiveMemoryWarningBlock?(self)
        if shouldremoveAllValuesOnMemoryWarning {
            removeAllValue()
        }
    }
    
    @objc fileprivate func appDidEnterBackgroundNotification(_ notification: Notification) {
        didEnterBackgroundBlock?(self)
        if shouldremoveAllValuesWhenEnteringBackground {
            removeAllValue()
        }
    }

}
