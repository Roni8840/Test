//
//  Settings.swift
//  HM10 Serial
//
//  Created by Ronald Reichmuth on 07.10.15.
//  Copyright © 2015 Balancing Rock. All rights reserved.
//

import UIKit
import CoreBluetooth
import QuartzCore

class SettingsViewController: UIViewController, UITextFieldDelegate, DZBluetoothSerialDelegate  {
    
    
//MARK: IBOutlets
    

    @IBOutlet weak var nachlaufzeit: UITextView!
    


    
//MARK: Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // as usual....
        serial.delegate = self
        
        // UI
        title = serial.connectedPeripheral!.name
        nachlaufzeit.text = ""
        

        
    }
    
    
    
//MARK: DZBluetoothSerialDelegate
    
    func serialHandlerNewData(message: String) {
        // add the received text to the textView, optionally with a line break at the end
        nachlaufzeit.text! = serial.read()
    }
    

}
