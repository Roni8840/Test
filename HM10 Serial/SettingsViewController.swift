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

    @IBOutlet weak var Text: UITextView!
    //...
    
    
    
//MARK: IBActions
    
    @IBAction func Back(sender: AnyObject) {
        // dismissssssss
        dismissViewControllerAnimated(true, completion: nil)
    }

    
//MARK: Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // as usual....
        serial.delegate = self
        
        // UI
        title = serial.connectedPeripheral!.name
        
    }
    
    
    
//MARK: DZBluetoothSerialDelegate
    
    func serialHandlerNewData(message: String) {
        // add the received text to the textView, optionally with a line break at the end
        //nachlaufzeit.text! = serial.readArray().description
        
        let daten = serial.readArray()
        
        var string = ""
        
        string += "Settings:\n"
        string += "Nachlaufzeit: " + (Int(daten[39])*256+Int(daten[40])).description + "s\n"
        string += "Range: " + (Int(daten[41])).description + " Prozent \n"
        string += "Lux: " + (Int(daten[42])*256+Int(daten[43])).description + "lx \n"
        
        string += "\n"
        
        string += "Informationen:\n"
        string += "Temp: " + Int(daten[32]).description + "°C \n"
        string += "Gemessene Helligkeit: " + (Int(daten[22])*256+Int(daten[23])).description + "\n"
        string += "Lux Lupe: " + (Int(daten[25])).description + "\n"

        string += "\n"
        
        string += "\nApplikation:\n"
        string += "Nachlaufzeit: " + (Int(daten[37])*256+Int(daten[38])).description + "s \n"
        string += "Relais State: " + Int(daten[33]).description
        
        string += "\n"
        
        string += "\nHF Sensor:\n"
        string += "Video: " + (Int(daten[8])*256+Int(daten[9])).description + "\n"
        string += "Counter: " + (Int(daten[17])).description + "\n"
        string += "Counter MAX: " + (Int(daten[18])).description + "\n"
        string += "Schleppzeiger: " + (Int(daten[14])*256+Int(daten[15])).description + "\n"
        
        
        
        Text.text! = string

        
    }
    
    

}
