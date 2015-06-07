//
//  ManagedObject.swift
//  Griddle
//
//  Created by Thomas Bouldin on 6/6/15.
//  Copyright (c) 2015 Inlined. All rights reserved.
//

import Foundation

public class ManagedObject {
  private var serverData = FDataSnapshot()
  private var dirtyData = [String:AnyObject]()
  
  private var ref : Firebase!
  private var eventHandle: UInt = 0
  
  public init(atURL: String) {
    ref = Firebase(url:atURL)
    eventHandle = ref.observeEventType(.Value, withBlock: { [unowned self] snapshot in
      self.updateSnapshot(snapshot)
    })
  }
  
  func updateSnapshot(snapshot: FDataSnapshot!) {
    serverData = snapshot
  }
}