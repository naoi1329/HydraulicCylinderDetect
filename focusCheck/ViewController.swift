//
//  ViewController.swift
//  focusCheck
//
//  Created by 直井翔汰 on 2018/06/20.
//  Copyright © 2018年 直井翔汰. All rights reserved.
//

import UIKit
import AVFoundation

enum DetectMode: Int {
    case nature = 0
    case canny = 1
    case sobel = 2
}

class ViewController: UIViewController {

    var camera: AVCaptureDevice!
    var session: AVCaptureSession!
    var input: AVCaptureInput!
    var output: AVCaptureVideoDataOutput!
    var timeValues: [CMTimeValue] = [0] {
        didSet {
            pickerView.reloadAllComponents()
        }
    }
    
    var isoValues: [Float] = [0] {
        didSet {
            pickerView.reloadAllComponents()
        }
    }
    
    var beforeTouchPosition: CGPoint = CGPoint(x: 0, y: 0)
    var oldZoomScale: CGFloat = 1.0
    var tmpSaveImage: UIImage = UIImage()
    
    @IBOutlet weak var preView: UIImageView!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var isoPickerView: UIPickerView!
    @IBOutlet weak var cannySegmentedControl: UISegmentedControl!
    @IBOutlet weak var focusSlider: UISlider!
    
    @IBOutlet weak var cannyMinValueSlider: UISlider!
    @IBOutlet weak var cannyMaxValueSlider: UISlider!
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
        
        preView.image = #imageLiteral(resourceName: "IMG_5603.JPG")
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchedGesture(gestureRecgnizer:)))
        view.addGestureRecognizer(pinchGesture)
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
        output = AVCaptureVideoDataOutput()
        
        // 出力をセッションに追加
        if(session.canAddOutput(output)) {
            session.addOutput(output)
        }
        
        // ピクセルフォーマットを 32bit BGR + A とする
        output.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as AnyHashable as!
                String : Int(kCVPixelFormatType_32BGRA)]
        
        // フレームをキャプチャするためのサブスレッド用のシリアルキューを用意
        output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        
        output.alwaysDiscardsLateVideoFrames = true
        // セッションからプレビューを表示を
//        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
//
//        previewLayer.frame = view.frame
//        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // レイヤーをViewに設定
        // これを外すとプレビューが無くなる、けれど撮影はできる
//        preView.layer.addSublayer(previewLayer)
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
        
        isoValues = (Int(minISO*10)...Int(maxISO*10)).map { num in
            let returnNum = Float(num) / 10.0
            return returnNum
        }
    }
    
    func exposurePickerSetUp() {
        let activeFormatMin = camera.activeFormat.minExposureDuration
        let activeFormatMax = camera.activeFormat.maxExposureDuration
        
        let maxValue: Int64 = Int64(activeFormatMax.value) * Int64((activeFormatMin.timescale / activeFormatMax.timescale))
        
        let loopNum = (maxValue - activeFormatMin.value) / 5
        
        timeValues =  (1...loopNum).map { num in
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
            camera.setFocusModeLocked(lensPosition: sender.value, completionHandler: nil)
            
            session.startRunning()
            camera.unlockForConfiguration()
        } catch {
            print("device lock failled")
        }
    }
    
    @IBAction func imageSaveButtonAction(_ sender: UIButton) {
        UIImageWriteToSavedPhotosAlbum(tmpSaveImage, self, nil, nil)
        
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

        let location = touch.location(in: view)

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
        
        normalizePoint.x = normalizePoint.x / view.bounds.width
        normalizePoint.y = normalizePoint.y / view.bounds.height
        
        return normalizePoint
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // 新しいキャプチャの追加で呼ばれる
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var image: UIImage = UIImage()
        
        
        // キャプチャしたsampleBufferからUIImageを作成
        // segmentedcontrolにyottekaeru
        switch DetectMode(rawValue: cannySegmentedControl.selectedSegmentIndex)! {
        case .nature:
            image = captureImage(sampleBuffer)
        case .canny:
            
            var intMinValue = Int32(cannyMinValueSlider.value)
            var intMaxvalue = Int32(cannyMaxValueSlider.value)
            let minPointer = withUnsafeMutablePointer(to: &intMinValue) { $0 }
            let maxPointer = withUnsafeMutablePointer(to: &intMaxvalue) { $0 }
            
            image = OpenCVWrapper.cannyImage(captureImage(sampleBuffer), maxValue: maxPointer, minValue: minPointer)
        case .sobel:
            image = OpenCVWrapper.sobelImage(captureImage(sampleBuffer))
        }

        // 画像を画面に表示
        DispatchQueue.main.async {
            self.preView.image = image
            self.tmpSaveImage = image
        }
    }
    
    // sampleBufferからUIImageを作成
    func captureImage(_ sampleBuffer:CMSampleBuffer) -> UIImage{
        
        // Sampling Bufferから画像を取得
        let imageBuffer:CVImageBuffer =
            CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        // pixel buffer のベースアドレスをロック
        CVPixelBufferLockBaseAddress(imageBuffer,
                                     CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        let baseAddress:UnsafeMutableRawPointer =
            CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        
        let bytesPerRow:Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width:Int = CVPixelBufferGetWidth(imageBuffer)
        let height:Int = CVPixelBufferGetHeight(imageBuffer)
        
        // 色空間
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        
        //let bitsPerCompornent:Int = 8
        // swift 2.0
        let newContext:CGContext = CGContext(data: baseAddress,
                                             width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: bytesPerRow, space: colorSpace,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
        
        let imageRef:CGImage = newContext.makeImage()!
        let resultImage = UIImage(cgImage: imageRef,
                                  scale: 1.0, orientation: UIImageOrientation.right)
        
        return resultImage
    }
}

// MARK: Picker
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

// MARK: Zoom
extension ViewController {
    
    @objc func pinchedGesture(gestureRecgnizer: UIPinchGestureRecognizer) {
        do {
            try camera.lockForConfiguration()
            // ズームの最大値
            let maxZoomScale: CGFloat = 6.0
            // ズームの最小値
            let minZoomScale: CGFloat = 1.0
            // 現在のカメラのズーム度
            var currentZoomScale: CGFloat = camera.videoZoomFactor
            // ピンチの度合い
            let pinchZoomScale: CGFloat = gestureRecgnizer.scale
            
            // ピンチアウトの時、前回のズームに今回のズーム-1を指定
            // 例: 前回3.0, 今回1.2のとき、currentZoomScale=3.2
            if pinchZoomScale > 1.0 {
                currentZoomScale = oldZoomScale+pinchZoomScale-1
            } else {
                currentZoomScale = oldZoomScale-(1-pinchZoomScale)*oldZoomScale
            }
            
            // 最小値より小さく、最大値より大きくならないようにする
            if currentZoomScale < minZoomScale {
                currentZoomScale = minZoomScale
            }
            else if currentZoomScale > maxZoomScale {
                currentZoomScale = maxZoomScale
            }
            
            // 画面から指が離れたとき、stateがEndedになる。
            if gestureRecgnizer.state == .ended {
                oldZoomScale = currentZoomScale
            }
            
            camera.videoZoomFactor = currentZoomScale
            camera.unlockForConfiguration()
        } catch {
            // handle error
            return
        }
    }
}

extension ViewController {
    @IBAction func segmentChanged(sender: UISegmentedControl) {
        guard let type = DetectMode(rawValue: sender.selectedSegmentIndex) else {
            return
        }
        
        switch type {
        case .nature:
            pickerView.isHidden = false
            isoPickerView.isHidden = false
            focusSlider.isHidden = false
            
            cannyMaxValueSlider.isHidden = true
            cannyMinValueSlider.isHidden = true
        case .canny:
            pickerView.isHidden = true
            isoPickerView.isHidden = true
            focusSlider.isHidden = true
            
            cannyMaxValueSlider.isHidden = false
            cannyMinValueSlider.isHidden = false
        case .sobel:
            break
        }
    }
}
