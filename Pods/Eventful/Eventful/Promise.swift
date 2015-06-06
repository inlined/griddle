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
  var val: ContinueWith! { get }
  var err: NSError? { get }
  var cancelled: Bool { get }
  func always(block: (Promise<ContinueWith>)->()) -> Promise<ContinueWith>
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
  private var callbacks: [(Promise)->()] = []
  
  public var val: T! = nil
  public var err: NSError? = nil
  public var cancelled: Bool = false
  private var resolved = false
  
  public init() {}
  public convenience init(_ val: T) {
    self.init()
    resolve(val)
  }
  
  private func whenResolved(block: (Promise)->()) {
    lock.synchronized {
      if self.resolved {
        block(self)
      } else {
        self.callbacks.append(block)
      }
    }
  }
  
  // then<Promise<Y>> accepts a callback that returns a promise.
  // When self is fulfilled, the block is called to generate
  // a nested promise. That promise fulfills or fails the
  // promise returned by this function.
  // It's easiest to rationalize this as "flattening" out nested promises as they
  // are lazily evaluated.
  public func then<Y : PromiseBase>(block: (T!) -> Y) -> Promise<Y.ContinueWith> {
    let chained = Promise<Y.ContinueWith>()
    whenResolved { promise in
      if promise.cancelled {
        chained.cancel()
      } else if promise.err != nil {
        chained.fail(promise.err)
      } else {
        block(promise.val).always { promise in
          chained.notify(promise.val, promise.err, false)
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
    whenResolved { promise in
      if promise.cancelled {
        chained.cancel()
      } else if promise.err != nil {
        chained.fail(promise.err)
      } else {
        chained.resolve(block(promise.val))
      }
    }
    return chained
  }
  
  // error accepts a callback to be executed when a promise fails
  // (immediately if the promise has been failed previously). It returns a copy of self.
  public func error(block: (NSError!)->(T)) -> Promise {
    var chained = Promise()
    whenResolved { promise in
      if promise.cancelled {
        chained.cancel()
      } else if promise.err != nil {
        chained.resolve(block(promise.err))
      } else {
        chained.resolve(promise.val)
      }
    }
    return chained
  }
  
  public func error(block: (NSError!) ->()) -> Promise {
    whenResolved { promise in
      if promise.err != nil {
        block(promise.err)
      }
    }
    return self
  }
  
  public func cancelled(block: ()->()) {
    whenResolved { promise in
      if promise.cancelled {
        block()
      }
    }
  }
  
  // Always accepts a block that is called on success or faiulre of a promise and
  // returns self.
  public func always<Y>(block: (Promise)->(Y)) -> Promise<Y> {
    var chained = Promise<Y>()
    whenResolved { promise in
      chained.resolve(block(promise))
    }
    return chained
  }
  
  public func always(block: (Promise) -> ()) -> Self {
    whenResolved { promise in
      block(promise)
    }
    return self
  }
  
  private func notify(val: T!, _ err: NSError?, _ cancelled: Bool) {
    lock.synchronized {[unowned self] in
      if self.cancelled || cancelled && self.resolved {
        return
      }
      assert(!self.resolved, "Can only resolve or fail a promise once")

      self.resolved = true
      self.val = val
      self.err = err
      self.cancelled = cancelled
      
      for callback in self.callbacks {
        callback(self)
      }
    }
  }
  
  public func cancel() {
    notify(nil, nil, true)
  }
  public func resolve(val: T!) {
    notify(val, nil, false)
  }
  
  public func fail(err: NSError!) {
    notify(nil, err, false)
  }
}