//
//  ViewController.swift
//  focusCheck
//
//  Created by 直井翔汰 on 2018/06/20.
//  Copyright © 2018年 直井翔汰. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    var camera: AVCaptureDevice!
    var session: AVCaptureSession!
    var input: AVCaptureInput!
    var output: AVCapturePhotoOutput!
    
    @IBOutlet weak var preView: UIView!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var isoPickerView: UIPickerView!
    
    var timeValues: [CMTimeValue] = [0] {
        didSet {
            self.pickerView.reloadAllComponents()
        }
    }
    
    var isoValues: [Float] = [0] {
        didSet {
            self.pickerView.reloadAllComponents()
        }
    }
    
    var beforeTouchPosition: CGPoint = CGPoint(x: 0, y: 0)
    
    //設定不可能
//    var aperture: Float = 0.5 {
//        didSet {
//            self.camera.
//        }
//    }
    
    @IBOutlet weak var focusSlider: UISlider!
    //@IBOutlet weak var exposureSlider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        
        pickerView.dataSource = self
        pickerView.delegate = self
        pickerView.tag = 0
        
        isoPickerView.dataSource = self
        isoPickerView.delegate = self
        isoPickerView.tag = 1
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // camera stop メモリ解放
        session.stopRunning()
        
        for output in session.outputs {
            //session.removeOutput((output as? AVCaptureOutput)!)
            session.removeOutput(output)
        }
        
        for input in session.inputs {
            //session.removeInput((input as? AVCaptureInput)!)
            session.removeInput(input)
        }
        session = nil
        camera = nil
    }

    //時間やバッテリーなどが表示されている上のバー消す
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // camera initialize
    func setupCamera() {
        // セッション
        session = AVCaptureSession()
        
        // 背面・前面カメラの選択
        camera = AVCaptureDevice.default(
            AVCaptureDevice.DeviceType.builtInWideAngleCamera,
            for: AVMediaType.video,
            position: .back) // position: .front
        
        // カメラからの入力データ
        do {
            input = try AVCaptureDeviceInput(device: camera)
            
        } catch let error as NSError {
            print(error)
        }
        
        // 入力をセzッションに追加
        if(session.canAddInput(input)) {
            session.addInput(input)
        }
        
        // 静止画出力のインスタンス生成
        output = AVCapturePhotoOutput()
        // 出力をセッションに追加
        if(session.canAddOutput(output)) {
            session.addOutput(output)
        }
        // セッションからプレビューを表示を
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)

        previewLayer.frame = self.view.frame
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // レイヤーをViewに設定
        // これを外すとプレビューが無くなる、けれど撮影はできる
        preView.layer.addSublayer(previewLayer)
        session.startRunning()

//        exposureSliderSetUp()
        exposurePickerSetUp()
        isoPickerViewSetUp()
    }
    
    func isoPickerViewSetUp() {
        let maxISO = camera.activeFormat.maxISO
        let minISO = camera.activeFormat.minISO
        
        print("maxISO = \(maxISO)")
        print("miISO = \(minISO)")
        
        self.isoValues = (Int(minISO*10)...Int(maxISO*10)).map { num in
            let returnNum = Float(num) / 10.0
            return returnNum
        }
    }
    
    func exposurePickerSetUp() {
        let activeFormatMin = camera.activeFormat.minExposureDuration
        let activeFormatMax = camera.activeFormat.maxExposureDuration
        
        let maxValue: Int64 = Int64(activeFormatMax.value) * Int64((activeFormatMin.timescale / activeFormatMax.timescale))
        
        let loopNum = (maxValue - activeFormatMin.value) / 5
        
        self.timeValues =  (1...loopNum).map { num in
            return CMTimeValue(num * 5)
        }
        
    }
    
//    func exposureSliderSetUp() {
//        let activeFormatMin = camera.activeFormat.minExposureDuration
//        let activeFormatMax = camera.activeFormat.maxExposureDuration
//        //min value setup
//        exposureSlider.minimumValue = Float(activeFormatMin.value)
//
//        //max value setup
//        let maxValue: Int32 = Int32(activeFormatMax.value) * Int32((activeFormatMin.timescale / activeFormatMax.timescale))
//        exposureSlider.maximumValue = Float(abs(maxValue - Int32(activeFormatMin.value))) / 100 // 単純に明るすぎるところいらんのでmax値を低くする
//    }
    
    
    //value 0.0 ~ 1.0
    @IBAction func focusSliderAction(sender: UISlider) {
        do {
            // https://developer.apple.com/documentation/avfoundation/avcapturedevice/1387810-lockforconfiguration 参考　Note部分
            try camera.lockForConfiguration()
            self.camera.setFocusModeLocked(lensPosition: sender.value, completionHandler: nil)
            
            session.startRunning()
            camera.unlockForConfiguration()
        } catch {
            print("device lock failled")
        }
    }
    
    
    
//    @IBAction func exposureSliderSliderAction(sender: UISlider) {
//        do {
//            try camera.lockForConfiguration()
//
//            let duration = CMTime(value: CMTimeValue(sender.value), timescale: camera.activeFormat.minExposureDuration.timescale)
//            camera.setExposureModeCustom(duration: duration, iso: camera.iso, completionHandler: nil)
//
//            session.startRunning()
//            camera.unlockForConfiguration()
//        } catch {
//            print("device lock failled")
//        }
//
//    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }

        let location = touch.location(in: self.view)

        let normalizePoint = locationNormalize(location)

        if camera.isExposurePointOfInterestSupported {
            do {
                try camera.lockForConfiguration()
                camera.exposureMode = .continuousAutoExposure
//                camera.configureExposurePointOfInterest(exposurePointOfInterest: normalizePoint, exposureMode: .continuousAutoExposure)
                camera.exposurePointOfInterest = normalizePoint

//                print(camera.exposurePointOfInterest)
//                print(camera.exposureMode.rawValue)
//                print(camera.isAdjustingExposure)
                session.startRunning()
                camera.unlockForConfiguration()
            } catch {
                print("device lock failled")
            }
        }
        
        if camera.isFocusModeSupported(.autoFocus) {
            do {
                try camera.lockForConfiguration()
                camera.focusMode = .autoFocus
                //                camera.configureExposurePointOfInterest(exposurePointOfInterest: normalizePoint, exposureMode: .continuousAutoExposure)
                camera.focusPointOfInterest = normalizePoint
                
                //                print(camera.exposurePointOfInterest)
                //                print(camera.exposureMode.rawValue)
                //                print(camera.isAdjustingExposure)
                session.startRunning()
                camera.unlockForConfiguration()
            } catch {
                print("device lock failled")
            }
            
        }
    }
    
    func locationNormalize(_ point: CGPoint) -> CGPoint {
        var normalizePoint = point
        
        normalizePoint.x = normalizePoint.x / self.view.bounds.width
        normalizePoint.y = normalizePoint.y / self.view.bounds.height
        
        return normalizePoint
    }
}

extension AVCaptureDevice {
    func configureFocusPointOfInterest(focusPointOfInterest: CGPoint, focusMode: FocusMode) {
        if isFocusPointOfInterestSupported {
            self.focusPointOfInterest = focusPointOfInterest
            self.focusMode = focusMode
        }
    }
    func configureExposurePointOfInterest(exposurePointOfInterest: CGPoint, exposureMode: ExposureMode) {
        if isExposurePointOfInterestSupported {
            self.exposurePointOfInterest = exposurePointOfInterest
            self.exposureMode = exposureMode
        }
    }
}

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return timeValues.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView.tag == 0 {
            return String(timeValues[row])
        } else if pickerView.tag == 1 {
            return String(isoValues[row])
        } else {
            return "nnonononononondofasoufnopiuawrf"
        }
        
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        if pickerView.tag == 0 {
            do {
                try camera.lockForConfiguration()
                
                let duration = CMTime(value: timeValues[row], timescale: camera.activeFormat.minExposureDuration.timescale)
                camera.setExposureModeCustom(duration: duration, iso: camera.iso, completionHandler: nil)
                
                session.startRunning()
                camera.unlockForConfiguration()
            } catch {
                print("device lock failled")
            }
        } else if pickerView.tag == 1 {
            do {
                try camera.lockForConfiguration()

                camera.setExposureModeCustom(duration: camera.exposureDuration, iso: isoValues[row], completionHandler: nil)

                session.startRunning()
                camera.unlockForConfiguration()
            } catch {
                print("device lock failled")
            }
        }
        
    }
}
