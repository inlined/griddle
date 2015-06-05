//
//  Promise.swift
//  eventful
//
//  Created by Thomas Bouldin on 6/2/15.
//  Copyright (c) 2015 Inlined. All rights reserved.
//

import Foundation

public protocol PromiseBase {
  typealias ContinueWith
  typealias SelfType
  func always(block: (ContinueWith!, NSError?)->()) -> SelfType
}

// Promise is inspired by JavaScript promise libraries. They are useful for chaining asynchronous
// processes. In exchange for a simpler syntax, where closures take the parameter type rather than the full promise
// itself, promises do not have an easy syntax for understanding cancellation. Applications should be able to work
// around this where necessary by capturing a cancellation bit and/or using a cancellation error.
//
//
// TODO: should the resolver be separate from the promise itself? Tasks do this, but promise libraries typically
// don't. This can lead to assinine failure cases (which are most likely in test code) where:
// Promise<Foo>.then {(Foo) -> Bar }.resolve() doesn't do anything because the resolve call is on the chained
// promise.
public class Promise<T> : PromiseBase {
  private let lock = Lock()
  private var callbacks: [(T!, NSError?)->()] = []
  private var val: T? = nil
  private var err: NSError? = nil
  private var resolved = false
  
  public init() {}
  public convenience init(_ val: T) {
    self.init()
    resolve(val)
  }
  
  // then<Promise<Y>> accepts a callback that returns a promise.
  // When self is fulfilled, the block is called to generate
  // a nested promise. That promise fulfills or fails the
  // promise returned by this function.
  // It's easiest to rationalize this as "flattening" out nested promises as they
  // are lazily evaluated.
  public func then<Y : PromiseBase>(block: (T!) -> Y) -> Promise<Y.ContinueWith> {
    let chained = Promise<Y.ContinueWith>()
    always { [unowned self](val, err) in
      if err != nil {
        chained.fail(err)
      } else {
        // note: do not inline this call or it won't be called if chained is GCd
        let nested = block(self.val)
        nested.always { [unowned self](val, err) in
          chained.notify(val, err)
        }
      }
    }
    return chained
  }
  
  // then<Y> accepts a callback to be executed when the promise is resolved
  // (immediately if the promise has been resolved previously) and returns
  // a new promise wrapping the return type of the callback. If self fails,
  // the callback is never called and the failure propagates to the returned promise.
  public func then<Y>(block: (T!)->(Y)) -> Promise<Y> {
    let chained = Promise<Y>()
    always { [unowned self](val, err) in
      if err != nil {
        chained.fail(err)
      } else {
        // note: do not inline this call or it won't be called if chained is GCd
        let res = block(self.val)
        chained.resolve(res)
      }
    }
    return chained
  }
  
  // error accepts a callback to be executed when a promise fails
  // (immediately if the promise has been failed previously). It returns a copy of self.
  public func error(block: (NSError!)->()) -> Promise<T> {
    always { [unowned self](val, err) in
      if err != nil {
        block(err)
      }
    }
    return self
  }
  
  // Always accepts a block that is called on success or faiulre of a promise and
  // returns self.
  public func always(block: (T!, NSError?)->()) -> Promise<T> {
    lock.synchronized {
      if self.resolved {
        block(self.val, self.err)
      } else {
        self.callbacks.append(block)
      }
    }
    return self
  }
  
  private func notify(val: T!, _ err: NSError?) {
    lock.synchronized {[unowned self] in
      assert(!self.resolved, "Can only resolve or fail a promise once")

      self.resolved = true
      self.val = val
      self.err = err
      
      for callback in self.callbacks {
        callback(val, err)
      }
    }
  }
  
  public func resolve(val: T!) {
    notify(val, nil)
  }
  
  public func fail(err: NSError!) {
    notify(nil, err)
  }
}