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

    @IBOutlet weak var ApplicationTitle: UILabel!
    @IBOutlet weak var Text: UITextView!
    @IBOutlet weak var activity: UIProgressView!
    @IBOutlet weak var CounterMAX: UIProgressView!
    @IBOutlet weak var helligkeit: UIProgressView!
    @IBOutlet weak var HelligkeitLabel: UILabel!
    @IBOutlet weak var RelaisStateView: UISwitch!
    @IBOutlet weak var Brightness: UILabel!
    @IBOutlet weak var Delay: UILabel!
    @IBOutlet weak var Range: UILabel!
    @IBOutlet weak var Relais: UILabel!
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
        
        //init text field
        Text.text! = ""
        
    }
    
    
    
//MARK: DZBluetoothSerialDelegate
    
    func serialHandlerNewData(message: String) {
        // add the received text to the textView, optionally with a line break at the end
        //nachlaufzeit.text! = serial.readArray().description
        
        let daten = serial.readArray()
        
        var string = ""
        
        string += "\n"
        
        string += "Settings:\n"
        
        let TimerNachlaufzeit = Int(daten[37])*256+Int(daten[38])
        //let RelaisOperatingTimeMS = Float(Int(daten[44])*256+Int(daten[45]))/1000
        Relais.text = "Relais " + String(format: "%i", TimerNachlaufzeit) + " s"
        
        
        string += "Nachlaufzeit: " + (Int(daten[39])*256+Int(daten[40])).description + "s\n"
        let Nachlaufzeit : Int = (Int(daten[39])*256+Int(daten[40]))
        Delay.text = "Delay " + String(format: "%i", Nachlaufzeit) + " s"
        
        string += "Range: " + (Int(daten[41])).description + " Prozent \n"
        let RangeSetting : Int = Int(daten[41])
        Range.text = "Range " + String(format: "%i", RangeSetting) + " %"
        
        string += "Lux: " + (Int(daten[42])*256+Int(daten[43])).description + "lx \n"
        let BrightnessSetting : Int = (Int(daten[42])*256+Int(daten[43]))
        Brightness.text = "Brightness " + String(format: "%i", BrightnessSetting) + " lx"
        
        string += "\n"
        
        string += "Informationen:\n"
        string += "Temp: " + Int(daten[32]).description + "°C \n"
        string += "Measured Brightness: " + (Int(daten[22])*256+Int(daten[23])).description
        string += " (Lux Lupe: " + (Int(daten[25])).description + ")\n"
        string += "Calculated Brightness: "
        
        let LuxLupe = Int(daten[25])
        var als = 0.0
        als = Double(Int(daten[22])*256+Int(daten[23]))
        var ambientLightInLux = 0.0
        
        switch LuxLupe{
        case 1: ambientLightInLux = (als*0.6312)+1.2255
        case 0: ambientLightInLux = (als*4.2265)-4.9996
        default: string += "NA"
        }
        string += ambientLightInLux.description
        string += " lx\n"
        helligkeit.progress = Float(ambientLightInLux)/2000
        HelligkeitLabel.text = "Brightness " + String(format: "%.0f", ambientLightInLux) + " lx"
        
        string += "\n"
        
        //-- Applikation
        string += "\nApplikation:\n"
        string += "State: " + (Int(daten[20])).description + " ("
        let ApplikationsState = daten[20]
        var state = ""
        switch ApplikationsState
        {
            case 0: state += "Initialize"
            case 1: state += "Idle"
            case 2: state += "Install Mode"
            case 3: state += "Self Test"
            case 4: state += "Relay Test"
            case 5: state += "Permanent ON"
            case 6: state += "Permanent OFF"
            case 7: string += "Burn In"
            default: state += "unbekannt"
        }
        
        string += state
        ApplicationTitle.text = "Application (" + state + ")"
        
        
        string += ")\n"
        
        string += "Timer Nachlaufzeit: " + (Int(daten[37])*256+Int(daten[38])).description + "s \n"
        
        
        
        string += "\n"
        
        //-- HF Sensor
        string += "\nHF Sensor:\n"
        string += "Video: " + (Int(daten[8])*256+Int(daten[9])).description + "\n"
        string += "Filtered Video: " + (Int(daten[10])*256+Int(daten[11])).description + "\n"
        string += "Deviation: " + (Int(daten[12])*256+Int(daten[13])).description + "\n"
        string += "Schleppzeiter: " + (Int(daten[14])*256+Int(daten[15])).description + "\n"
        string += "Range: " + (Int(daten[16])).description + "\n"
        string += "Counter: " + (Int(daten[17])).description + "\n"
        string += "Counter MAX: " + (Int(daten[18])).description + "\n"
        CounterMAX.progress = Float(daten[18])/100
        
        string += "\n"
        activity.progress = Float(Int(daten[8])*256+Int(daten[9]))/1024
        
        
        //-- Relais
        string += "\nRelay:\n"
        let RelaisState = daten[33]
        string += "State: " + Int(daten[33]).description
        if RelaisState == 0{
            string += " (Relay OFF)\n"
            RelaisStateView.on = false
        }
        else{
            string += " (Relay ON)\n"
            RelaisStateView.on = true
        }
        string += "Current: " + (Int(daten[21])).description + "\n"
        string += "Operating Time: " + (Int(daten[44])*256+Int(daten[45])).description + " us\n"
        
        string += "\n"
        //Flags
        string += "\nFlags:\n"
        let Flags = UInt8(daten[36])
        string += "B36: "
        string += Flags.description + "\n"
        
        
        let motion = Flags & 0x01
        if motion == 0x00{
            string += "Motion detected !\n"
        }
        
        Text.text! = string

        
    }
    
    

}
