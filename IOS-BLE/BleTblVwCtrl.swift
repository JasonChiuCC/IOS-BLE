//
//  BleTblVwCtrl.swift
//  IOS-BLE
//
//  Created by dah.com on 2016/8/30.
//  Copyright © 2016年 Jason. All rights reserved.
//

import UIKit
import CoreBluetooth

var activeCentralManager    : CBCentralManager?
var peripheralDev           : CBPeripheral?
var devDict                 : Dictionary<String, CBPeripheral> = [:]
var devName                 : String?
var devServices             : CBService!
var devCharacteristics      : CBCharacteristic!
var devRSSI = [NSNumber]()


class BleTblVwCtrl: UITableViewController {
    
    // MARK: View
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(animated: Bool) {
        // Clear devices dictionary.
        devDict.removeAll(keepCapacity: false)
        devRSSI.removeAll(keepCapacity: false)
        
        // Initialize central manager on load
        activeCentralManager    = CBCentralManager(delegate: self, queue: nil)
        let refreshControl      = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(UIMenuController.update), forControlEvents: UIControlEvents.ValueChanged)
        self.refreshControl     = refreshControl
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func update(){
        // Clear devices dictionary.
        devDict.removeAll(keepCapacity: false)
        devRSSI.removeAll(keepCapacity: false)
        // Initialize central manager on load
        activeCentralManager = CBCentralManager(delegate: self, queue: nil)
        self.refreshControl?.endRefreshing()
    }
    
    func cancelConnection(){
        if let activeCentralManager = activeCentralManager{
            print("Died!")
            if let peripheralDevice = peripheralDev {
                //println(peripheralDevice)
                activeCentralManager.cancelPeripheralConnection(peripheralDevice)
            }
        }
    }
    
    func writeValue(data: String){
        let data = (data as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        if let peripheralDevice = peripheralDev {
            if let deviceCharacteristics = devCharacteristics{
                peripheralDevice.writeValue(data!, forCharacteristic: deviceCharacteristics, type: CBCharacteristicWriteType.WithoutResponse)
            }
        }
    }
    
    // MARK: TableView
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devDict.count
    }

    /* TableView 畫面 */
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell                        = tableView.dequeueReusableCellWithIdentifier("cell")! as UITableViewCell
        let discoveredPeripheralArray   = Array(devDict.values)
        print(discoveredPeripheralArray.count)
        
        // 將抓到的外接裝置顯示在 TableView
        if let name = discoveredPeripheralArray[indexPath.row].name{
            if let textLabelText = cell.textLabel{
                textLabelText.text = name
            }
            if let detailTextLabel = cell.detailTextLabel{
                detailTextLabel.text = devRSSI[indexPath.row].stringValue
            }
        }
        return cell
    }
 
    /* 選擇 Table 中的某個 item  */
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (devDict.count > 0){

            let discoveredPeripheralArray = Array(devDict.values)
            peripheralDev = discoveredPeripheralArray[indexPath.row]
            
            // Attach the peripheral delegate.
            if let peripheralDevice = peripheralDev {
                peripheralDevice.delegate   = self
                devName = peripheralDevice.name!
            } else {
                devName = " "
            }
            
            // 連接外接裝置
            if let activeCentralManager = activeCentralManager {
                activeCentralManager.stopScan()  // 停止掃描外接裝置
                activeCentralManager.connectPeripheral(peripheralDev!, options: nil)
                navigationItem.title = "Connecting \(devName)"
            }
            
        }
    }
}


// MARK: BLE
extension BleTblVwCtrl: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripheralsWithServices(nil, options: nil)
            print("Searching for BLE Devices")
        } else {
            // Can have different conditions for all states if needed - print generic message for now
            print("Bluetooth switched off or not initialized")
        }
    }
    
    // Check out the discovered peripherals to find Sensor Tag
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        // Get this device's UUID.
        if let name = peripheral.name {
            if(devDict[name] == nil) {
                devDict[name] = peripheral
                devRSSI.append(RSSI)
                self.tableView.reloadData()
            }
        }
    }
    
    // Discover services of the peripheral
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        if let peripheralDevice = peripheralDev {
            peripheralDevice.discoverServices(nil)
            if navigationController != nil {
                navigationItem.title = "Connected to \(devName)"
            }
        }
    }
    
    // If disconnected, start searching again
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Disconnected")
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
}

extension BleTblVwCtrl: CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        // Iterate through the services of a particular peripheral.
        for service in peripheral.services!
        {
            let thisService = service
            // Let's see what characteristics this service has.
            peripheral.discoverCharacteristics(nil, forService: thisService)
            if navigationController != nil {
                navigationItem.title = "Discovered Service for \(devName)"
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        // check the uuid of each characteristic to find config and data characteristics
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic
            // Set notify for characteristics here.
            peripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
            
            if navigationController != nil {
                navigationItem.title = "Discovered Characteristic for \(devName)"
            }
            devCharacteristics = thisCharacteristic
        }

        // Now that we are setup, return to main view.
        if let navigationController = navigationController {
            navigationController.popViewControllerAnimated(true)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        print("Got some!")
    }
}
