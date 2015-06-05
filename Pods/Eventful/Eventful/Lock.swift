//
//  Lock.swift
//  eventful
//
//  Created by Thomas Bouldin on 6/2/15.
//  Copyright (c) 2015 Inlined. All rights reserved.
//
//  Lock is a simple replacement for @synchronized in swift. It does however have
//  the same semantics for control flow statements (e.g. return, break) because it
//  is operating on a capture.

import Foundation

class Lock {
  private let lock = NSObject()
  func synchronized(block:()->()) {
    objc_sync_enter(lock)
    block()
    objc_sync_exit(lock)
  }
}