//
//  DZBluetoothSerialHandler.swift
//  HM10 Serial
//
//  Created by Alex on 09-08-15.
//  Copyright (c) 2015 Balancing Rock. All rights reserved.
//
//

import UIKit
import CoreBluetooth

/// Global serial handler, don't forget to initialize it with init(delgate:)
var serial: DZBluetoothSerialHandler!

@objc protocol DZBluetoothSerialDelegate: NSObjectProtocol {
    
    /// Called when a message is received
    optional func serialHandlerDidReceiveMessage(message: String)
    optional func serialHandlerNewData(message: String)
    
    /// Called when de state of the CBCentralManager changes (e.g. when bluetooth is turned on/off)
    optional func serialHandlerDidChangeState(newState: CBCentralManagerState)
    
    /// Called when a new peripheral is discovered while scanning. Also gives the RSSI (signal strength)
    optional func serialHandlerDidDiscoverPeripheral(peripheral: CBPeripheral, RSSI: NSNumber)
    
    /// Called when a peripheral is connected (but not yet ready for cummunication)
    optional func serialHandlerDidConnect(peripheral: CBPeripheral)
    
    /// Called when a peripheral disconnected
    optional func serialHandlerDidDisconnect(peripheral: CBPeripheral, error: NSError)
    
    /// Called when a pending connection failed
    optional func serialHandlerDidFailToConnect(peripheral: CBPeripheral, error: NSError)
    
    /// Called when a peripheral is ready for communication
    optional func serialHandlerIsReady(peripheral: CBPeripheral)
}


final class DZBluetoothSerialHandler: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
//MARK: Variables
    
    /// The delegate object the DZBluetoothDelegate methods will be called upon
    var delegate: DZBluetoothSerialDelegate!
    
    /// The CBCentralManager this bluetooth serial handler uses for communication
    var centralManager: CBCentralManager!
    
    /// The connected peripheral (nil if none is connected)
    var connectedPeripheral: CBPeripheral?
    
    /// The string buffer received messages will be stored in
    var buffer = ""
    var arrayBuffer = [UInt8]()
    var dataBuf = [UInt8](count: 100, repeatedValue: 0)

    
    /// The state of the bluetooth manager (use this to determine whether it is on or off or disabled etc)
    var state: CBCentralManagerState { get { return centralManager.state } }
    
    
//MARK: functions
    
    /// Always use this to initialize an instance
    init(delegate: DZBluetoothSerialDelegate) {
        super.init()
        self.delegate = delegate
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    /// Start scanning for peripherals
    func scanForPeripherals() {
        if centralManager.state != .PoweredOn { return }
        centralManager.scanForPeripheralsWithServices(nil, options: nil) //TODO: Try with service not nil (FFE0 or something)
    }
    
    /// Stop scanning for peripherals
    func stopScanning() {
        centralManager.stopScan()
    }
    
    /// Try to connect to the given peripheral
    func connectToPeripheral(peripheral: CBPeripheral) {
        centralManager.stopScan()
        centralManager.connectPeripheral(peripheral, options: nil)
    }
    
    
    /// Disconnect from the connected peripheral (to be used while already connected to it)
    func disconnect() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
    }
    
    /// Disconnect from the given peripheral (to be used while trying to connect to it)
    func cancelPeripheralConnection(peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    
    /// Send a string to the device
    func sendMessageToDevice(var message: String) {
        
        if centralManager.state != .PoweredOn || connectedPeripheral == nil { return }
        
        // write the value to all characteristics of all services
        for service in connectedPeripheral!.services! as [CBService] {
            for characteristic in service.characteristics! as [CBCharacteristic] {
                connectedPeripheral!.writeValue(message.dataUsingEncoding(NSUTF8StringEncoding)!, forCharacteristic: characteristic, type: .WithResponse)
            }
        }
        
    }
    
    //TODO: Function to send 'raw' bytes (array of UInt8's) to the peripheral
    
    /// Gives the content of the buffer and empties the buffer
    func read() -> String {
        let str = "\(buffer)" // <- is dit wel nodig??
        buffer = ""
        return str
    }
    
    /// Gives the content of the array and empties the array
    func readArray() -> [UInt8] {
        let retVal = dataBuf
        //dataBuf =  [UInt8]()
        return retVal
    }
    
    /// Gives the content of the buffer without emptying it
    func peek() -> String {
        return buffer
    }
    
    
//MARK: CBCentralManagerDelegate functions

    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        if delegate.respondsToSelector(Selector("serialHandlerDidDiscoverPeripheral:RSSI:")) {
            // just send it to the delegate
            delegate.serialHandlerDidDiscoverPeripheral!(peripheral, RSSI: RSSI)
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        if delegate.respondsToSelector(Selector("serialHandlerDidConnect:")) {
            // send it to the delegate
            delegate.serialHandlerDidConnect!(peripheral)
        }
        
        peripheral.delegate = self
        
        // Okay, the peripheral is connected but we're not ready yet! 
        // First get all services
        // Then get all characteristics of all services
        // Once that has been done check whether our characteristic (0xFFE1) is available
        // If it is, subscribe to it, and then we're ready for communication
        // If it is not, we've failed and have to find another device..

        peripheral.discoverServices(nil)
    }

    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        connectedPeripheral = nil
        if delegate.respondsToSelector(Selector("serialHandlerDidDisconnect:error:")) {
            // send it to the delegate
            delegate.serialHandlerDidDisconnect!(peripheral, error: error!)
        }
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        if delegate.respondsToSelector(Selector("serialHandlerDidFailToConnect:error:")) {
            // just send it to the delegate
            delegate.serialHandlerDidFailToConnect!(peripheral, error: error!)
        }
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if delegate.respondsToSelector(Selector("serialHandlerDidChangeState:")) {
            // just send it to the delegate
            delegate.serialHandlerDidChangeState!(central.state)
        }
    }
    
    
//MARK: CBPeripheralDelegate functions
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        // discover all characteristics for all services
        for service in peripheral.services! as [CBService] {
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        // check whether the characteristic we're looking for (0xFFE1) is present
        for characteristic in service.characteristics! as [CBCharacteristic] {
            if characteristic.UUID == CBUUID(string: "FFE1") {
                connectedPeripheral = peripheral
                // subscribe to this value (so we'll get notified when there is serial data for us..)
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                if delegate.respondsToSelector(Selector("serialHandlerIsReady:")) {
                    // notify the delegate we're ready for communication
                    delegate.serialHandlerIsReady!(peripheral)
                }
            }
        }
        
        //TODO: A way to notify the delegate if there is no FFE1 characteristic!
        
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        // there is new data for us! Update the buffer!
        //let data = NSString(data: characteristic.value!, encoding: NSUTF8StringEncoding) as! String
        //var newStr = NSString(data: characteristic.value!, encoding: NSUTF16StringEncoding) as! String

        let data = NSData(data: characteristic.value!)
        
        //create empty array
        let count = data.length / sizeof(UInt8)
        
        // create an array of Uint8
        var array = [UInt8](count: count, repeatedValue: 0)
        
        // copy bytes into array
        data.getBytes(&array, length:count * sizeof(UInt8))
    
        arrayBuffer +=  array
        
        var dataValid : Bool = false
        var amountOfBytes : Int = 0
        
        
        if (arrayBuffer.indexOf(0xAA) != nil && arrayBuffer.indexOf(0x55) != nil){
            if (arrayBuffer.indexOf(0xAA)! == (arrayBuffer.indexOf(0x55)! - 1)){
                //print("start gfunden")
                if ( arrayBuffer.count > (arrayBuffer.indexOf(0x55)!+1)){
                    //print("Genügend Bytes Vorhandem um die Stream länge zu bestimmen")
                    amountOfBytes = Int(arrayBuffer[arrayBuffer.indexOf(0xAA)!+2])
                    if(arrayBuffer.count >= (arrayBuffer.indexOf(0xAA)!+amountOfBytes+2)){
                        //vermutlich ganzes array vorhanden
                        if(arrayBuffer[(arrayBuffer.indexOf(0xAA)!+amountOfBytes+1)] == 0xAA){
                            //print("stream komplett")
                            //nächster stream beginnt auch schon wieder
                            for var index = 0; index<(amountOfBytes+1); ++index{
                                dataBuf[index] = arrayBuffer[arrayBuffer.indexOf(0xAA)!+index]
                            }
                            dataValid = true
                            arrayBuffer = []
                            let timestamp = NSDateFormatter.localizedStringFromDate(NSDate(), dateStyle: .NoStyle, timeStyle: .MediumStyle)
                            buffer += timestamp + " Neue Daten\n"
                            print(timestamp)
                        }
                        
                    }
                }
            }
        }
        
        if (arrayBuffer.count > 100)
        {
            arrayBuffer = []
            print("array buffer gelöscht")
            let timestamp = NSDateFormatter.localizedStringFromDate(NSDate(), dateStyle: .NoStyle, timeStyle: .MediumStyle)
            buffer += timestamp + " Daten verworfen!\n"
            
        }
        

        let newStr = "gugus"
        //buffer += "\n"
        
        if(dataValid == true){
            //notify the delegate of the new string
            if delegate.respondsToSelector(Selector("serialHandlerDidReceiveMessage:")) {
                delegate!.serialHandlerDidReceiveMessage!(newStr)
            }
            if delegate.respondsToSelector(Selector("serialHandlerNewData:")){
                delegate!.serialHandlerNewData!(newStr)
            }
            dataValid = false
        }
        
        
    }
   
}
