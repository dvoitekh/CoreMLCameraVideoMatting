import SwiftUI
import AVFoundation
import Vision
 
struct ContentView: View {
//    Background color of the UI page
    @State var color = Color.white
//    Current image. change in @StateObject property will rerender view
    @StateObject var sharedImage = BMSharedImage()
    
    var body: some View {
        VStack() {
//            In order to update the image we need propagate it to UI controller that encapsulates camera logic
            CustomCameraRepresentable(sharedImage: sharedImage)
            
            Image(uiImage: UIImage(named: sharedImage.emotion)!)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.bottom)
                .overlay(
                    VStack() {
                        if let fgr = sharedImage.fgr, let pha = sharedImage.pha {
                            Image(uiImage: fgr).normalize().mask(
                                Image(uiImage: pha).normalize()
                            )
                        }
                        Text("\(sharedImage.emotion), \(String(format: "%.4f", sharedImage.emotionProbability))")
                            .background(.white, ignoresSafeAreaEdges: .bottom)
                            .padding()
                    }
                )
        }.background(self.color)
    }
}

struct CustomCameraRepresentable: UIViewControllerRepresentable {
    var sharedImage: BMSharedImage
    
    func makeUIViewController(context: Context) -> CustomCameraController {
        let controller = CustomCameraController(sharedImage: sharedImage)
        return controller
    }
    
    func updateUIViewController(_ cameraViewController: CustomCameraController, context: Context) {}
}

class CustomCameraController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let targetFps = Int32(10)
    let videoOutput = AVCaptureVideoDataOutput()
    var captureSession = AVCaptureSession()
    var sharedImage: BMSharedImage?
    var predictor: RVMPredictor?
    var emotionPredictor: EmotionDetector?
    var counter = 0
    
    init(sharedImage: BMSharedImage) {
        self.predictor = RVMPredictor(sharedImage: sharedImage)
        self.emotionPredictor = EmotionDetector(sharedImage: sharedImage)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
//    Get front camera device
    func getDevice() -> AVCaptureDevice {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: .video, position: .front)!
    }
    
    func setup() {
        let device = getDevice()
//        Set camera input stream
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)

//        Set camera output stream. stream is processed by captureOutput function defined below
        self.videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "my.image.handling.queue"))
        self.captureSession.addOutput(self.videoOutput)

//        1280x720 is the dimentionality of the model's input that we'll use
//        the model doesn't contain any built-in preprocessing related to scaling
//        so let's transform a video stream to a desired size beforehand
        self.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        self.captureSession.startRunning()
    }

//    Process output video stream
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if let pixelBuffer = getPixelBufferFromSampleBuffer(buffer: sampleBuffer) {
            if (counter % 2 == 0) {
                predictor?.predict(src: pixelBuffer)
            }
            if (counter % 5 == 0) {
                emotionPredictor?.predict(src: pixelBuffer)
            }
            counter += 1
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
