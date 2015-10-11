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
        
        string += "\nInformationen:\n"
        string += "Temp: " + Int(daten[32]).description + "°C \n"
        string += "Gemessene Helligkeit: " + (Int(daten[22])*256+Int(daten[23])).description + "lx \n"

        string += "\n...\n"
        
        Text.text! = string

        
    }
    

}
