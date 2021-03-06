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
        arrayBuffer = [UInt8]()
        return str
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
        
        let count = data.length / sizeof(UInt8)
        
        // create an array of Uint8
        var array = [UInt8](count: count, repeatedValue: 0)
        
        // copy bytes into array
        data.getBytes(&array, length:count * sizeof(UInt8))
    
        arrayBuffer = arrayBuffer + array
        array = arrayBuffer
        
        //let newStr = arrayBuffer.description
        //buffer += newStr
        if arrayBuffer.count > 100 { //TODO: richtige grösse
            
            //leeres array für start indizes
            var startIndices = [Int](count: array.count, repeatedValue: 0)
            
            var x = 0 //laufnummer
            
            //start in empfangen Daten finden
            for var index = 0; index < array.count; ++index {
                
                if array[index] == 0xAA{
                    if array[index+1] == 0x55{
                        startIndices[x] = index
                        x++
                    }
                    
                }
            }

            
            let startIndex = 0
            var subArr = array[startIndices[startIndex]...startIndices[startIndex]+45]
            //let subArr = [0xAA,0x55,0x2D,0x06,0x8F,0x1E,0xB8,0x00,0x01,0x09,0x00,0x01,0x00,0x02,0x00,0x02,0x1D,0x00,0x00,0x00,0x01,0x00,0x02,0x25,0x04,0x00,0x20,0x13,0x04,0x80,0x00,0x00,0x1B,0x00,0x25,0x2C,0x00,0x00,0x00,0x00,0x1A,0x15,0x00,0x12,0x11,0x30]
            
            //return string für message field
            var returnString = ""
            
            //ausgabe formatieren
            for var i = 0; i <= 45; ++i {
                let wert = subArr[startIndices[startIndex]+i].description
                returnString = returnString + "B" + (i as NSNumber).stringValue + ": "
                //returnString = returnString + (subArr[i] as NSNumber).stringValue + "\n"
                returnString = returnString + wert + "\n"
            }
            
            let newStr = returnString
            buffer += newStr
            
            // notify the delegate of the new string
            if delegate.respondsToSelector(Selector("serialHandlerDidReceiveMessage:")) {
                delegate!.serialHandlerDidReceiveMessage!(newStr)
            }
        
        }
        
    }
   
}
