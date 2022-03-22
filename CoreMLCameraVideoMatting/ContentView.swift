import SwiftUI
import AVFoundation
import Vision
 
struct ContentView: View {
    let colors = [Color.white, Color.green, Color.red, Color.blue, Color.orange, Color.brown, Color.gray, Color.cyan, Color.indigo]
//    Background color of the UI page
    @State var color = Color.white
//    Current image. change in @StateObject property will rerender view
    @StateObject var sharedImage = BMSharedImage()
    
    var body: some View {
        VStack() {
//            In order to update the image we need propagate it to UI controller that encapsulates camera logic
            CustomCameraRepresentable(sharedImage: sharedImage)
            
            Group {
                if let fgr = sharedImage.fgr, let pha = sharedImage.pha {
                    Image(uiImage: fgr).normalize().mask(
                        Image(uiImage: pha).normalize()
                    )
                }
            }.overlay(
                Button("Shuffle Color") {
                    color = colors.randomElement()!
                }.padding()
                 .font(.system(size: 20, weight: Font.Weight.bold))
                 .foregroundColor(Color.white)
                 .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                 .buttonStyle(PlainButtonStyle()), alignment: .bottom)
        }.padding(.bottom, 200).background(self.color)
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
    
    init(sharedImage: BMSharedImage) {
        self.predictor = RVMPredictor(sharedImage: sharedImage)
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
            predictor?.predict(src: pixelBuffer)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
