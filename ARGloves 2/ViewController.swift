//
//  ViewController.swift
//  ARGloves 2
//
//  Created by Ashwat on 22/07/2021.
//

import UIKit
import RealityKit
import Combine
import CoreBluetooth
import ARKit

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, ARSessionDelegate {
    
    @IBOutlet var ArView: ARView!
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.landscape
    }
    
    
    var centralManager: CBCentralManager!
    var myPeripheral: CBPeripheral!
    
    var writeCharacteristic: CBCharacteristic!
    
    var canWrite = false
    
    var hand: Entity?
    var wall: Entity?
    
    var wallPosition: SIMD3<Float>?
    
    var previousBW = false
    
    var timer: Timer?
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            print("BLE powered on")
            // Turned on
            central.scanForPeripherals(withServices: nil, options: nil)
        }
        else {
            print("Something wrong with BLE")
            // Not on, but can have different issues
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Services Discovered")
        
        guard myPeripheral.services != nil else { return }
        
        for service in myPeripheral.services! {
            myPeripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard hand != nil && wallPosition != nil && wall != nil else { return }
        
        let worldTransform = hand!.anchor!.convert(position: [0, 0, -0.05], to: wall?.anchor)
        
        guard worldTransform != [0, 0, -0.05] else { return }
        
        let beyondWall = worldTransform.z < wallPosition!.z
        
        guard beyondWall != previousBW else { return }
        
        if beyondWall == true {
            writeValueToChar(withValue: Data([UInt8(255)]))
        } else {
            writeValueToChar(withValue: Data([UInt8(0)]))
        }
        
        previousBW = beyondWall
    }
    
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard writeCharacteristic == nil else { return }
        guard let characteristics = service.characteristics else { return }
        
        
          for characteristic in characteristics {
              if characteristic.properties.contains(.writeWithoutResponse) {
                  canWrite = true
                  writeCharacteristic = characteristic
              }
          }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
        myPeripheral = nil
        writeCharacteristic = nil
        canWrite = false
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        
        if peripheral.name == "MLT-BT05" {
            self.centralManager.stopScan()
            self.myPeripheral = peripheral
            self.myPeripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.myPeripheral.discoverServices(nil)
    }
    
    private func writeValueToChar(withValue value: Data) {
        guard canWrite else { return }
        
        // Check if it has the write property
        if writeCharacteristic.properties.contains(.writeWithoutResponse) && myPeripheral != nil {
            myPeripheral.writeValue(value, for: writeCharacteristic, type: .withoutResponse)
        }

    }
    
    @objc func resend() {
        if previousBW == true {
            writeValueToChar(withValue: Data([UInt8(255)]))
        } else {
            writeValueToChar(withValue: Data([UInt8(0)]))
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(resend), userInfo: nil, repeats: true)
        timer?.tolerance = 0.5

        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Load the "Box" scene from the "Experience" Reality File
        let Anchor = try! Experience.loadScene()
        let handAnchor = try! Experience.loadHand()
        
        ArView.session.delegate = self
        
        hand = handAnchor.children.first!
        wall = Anchor.children.first
        wallPosition = wall?.position
        
        ArView.scene.anchors.append(Anchor)
        ArView.scene.anchors.append(handAnchor)
        
        let replicatorLayer = CAReplicatorLayer()
        replicatorLayer.frame.size = view.frame.size
        replicatorLayer.masksToBounds = false
        
        replicatorLayer.addSublayer(ArView.layer)
        
        replicatorLayer.instanceCount = 3 // including the original, which doesn't exist anymore
        replicatorLayer.instanceTransform = CATransform3DMakeTranslation(
            ArView.frame.size.width, 0, 0
        )
        replicatorLayer.position.x -= ArView.frame.size.width
        view.layer.addSublayer(replicatorLayer)
        
    }
}
