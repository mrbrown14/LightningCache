//
//  Cacheable.swift
//  LightningCache
//
//  Created by Jeremy Zhou on 1/12/18.
//  Copyright © 2018 jz. All rights reserved.
//

import Foundation
import UIKit

public protocol Cacheable {
    associatedtype SelfType
    static func deserialize(_ data: Data) -> SelfType?
    func serialize() -> Data?
}

extension NSObject  {
    static public func serialize<T: NSObject>(obj: T) -> Data? where T: NSCoding {
        return NSKeyedArchiver.archivedData(withRootObject: obj)
    }
    static public func deserialize<T: NSObject>(data: Data, objType: T.Type = T.self) -> T? where T: NSCoding {
        guard let obj =  NSKeyedUnarchiver.unarchiveObject(with: data) else { return nil }
        return obj as? T
    }
}


#if os(iOS)
    extension UIImage: Cacheable {
        
        public func serialize() -> Data? {
            return UIImageJPEGRepresentation(self, 1)
        }
        
        public static func deserialize(_ data: Data) -> UIImage? {
            return UIImage(data: data)
        }
    }
#endif
