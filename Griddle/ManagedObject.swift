//
//  ManagedObject.swift
//  Griddle
//
//  Created by Thomas Bouldin on 6/6/15.
//  Copyright (c) 2015 Inlined. All rights reserved.
//

import Foundation
import Eventful

protocol UnsafeYielder {
  func yieldUnsafe(val: AnyObject!)
}

public class Property<T : AnyObject> : Observable<T>, UnsafeYielder {
  var target: ManagedObject!
  let keyPath: String
  
  public init(keyPath: String) {
    self.keyPath = keyPath
  }
  
  public func bind(target: ManagedObject) {
    assert(self.target == nil)
    self.target = target
  }
  
  func yieldUnsafe(val: AnyObject!) {
    yield(val as? T)
  }
  
  func set(val: T!) {
    target.set(val, forKeyPath:keyPath)
  }
}

infix operator <- { assignment }
func <-<T : AnyObject>(property: Property<T>, val: T!) {
  property.set(val)
}

public class ManagedObject {
  private var serverData = FDataSnapshot()
  private var dirtyData = [String:AnyObject]()
  private var yielders = [String:UnsafeYielder]()
  
  private var ref : Firebase!
  private var eventHandle: UInt = 0
  
  public init(atURL: String) {
    ref = Firebase(url:atURL)
    eventHandle = ref.observeEventType(.Value, withBlock: { [unowned self] snapshot in
      self.updateSnapshot(snapshot)
    })
  }
  
  func get(keyPath: String) -> AnyObject? {
    if let dirtyVal: AnyObject = dirtyData[keyPath] {
      if dirtyVal is NSNull {
        return nil
      }
      return dirtyVal
    }
    return serverData.valueForKeyPath(keyPath)
  }
  
  func set(value: AnyObject!, forKeyPath: String) {
    dirtyData[forKeyPath] = value ?? NSNull()
    yielders[forKeyPath]?.yieldUnsafe(value)
  }
  
  // TODO: Make Promise<Void> easier to use; right now it can't even be initialized.
  public func save() -> Promise<Int> {
    let done = Promise<Int>()
    ref.updateChildValues(dirtyData) { err, _ in
      if err == nil {
        // TODO: dirtyData needs to be purged, but when will we get the updated snapshot?
        done.resolve(0)
      } else {
        done.fail(err)
      }
    }
    return done
  }
  
  // TODO(Thomas): Don't send events for data which hasn't changed.
  func updateSnapshot(snapshot: FDataSnapshot!) {
    serverData = snapshot
    for child in snapshot.children {
      let typedChild = child as! FDataSnapshot
      if let yielder = yielders[typedChild.key] {
        yielder.yieldUnsafe(typedChild.value)
      }
    }
  }
  
  /*
  public func property<T>(keyPath: String) -> Property<T> {
    if let existing = yielders[keyPath] {
      return existing as! Property<T>
    }
    let newProp = Property<T>(target:self, keyPath:keyPath)
    yielders[keyPath] = newProp
    return newProp
  }*/
}