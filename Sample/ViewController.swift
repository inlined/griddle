//
//  ViewController.swift
//  Sample
//
//  Created by Thomas Bouldin on 6/7/15.
//  Copyright (c) 2015 Inlined. All rights reserved.
//

import UIKit
import Griddle

class Profile : ManagedObject {
  let name = Property<NSString>(keyPath: "name")
  let handle = Property<NSString>(keyPath:"name")
  override init(atURL: String) {
    super.init(atURL:atURL)
    name.bind(self)
    handle.bind(self)
  }
}

func ~>(property: Property<NSString>, label: UILabel!) {
  property.tap {
    if label != nil {
      label.text = String($0 ?? "")
    }
  }
}

class ViewController: UIViewController {
  @IBOutlet var name: UILabel!
  @IBOutlet var handle: UILabel!
  @IBOutlet var url: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @IBAction func setURL(sender: AnyObject) {
    let model = Profile(atURL: url.text)
    model.name ~> name
    model.handle ~> handle
  }

}

