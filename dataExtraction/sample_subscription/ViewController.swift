//
//  ViewController.swift
//  sample_subscription
//
//  Created by KSMAC-MINI-017 on 12/08/25.
//

var apiKey = "AIzaSyBd_cmWrrgQ69kQmH1rgjj_4H7Ou00g9gI"

import UIKit
import Vision
import Speech
import AVFoundation

class ViewController: UIViewController, SFSpeechRecognizerDelegate  {
  
  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    //    extractTextFromImage(UIImage(named: "sample2")!)
    //    callApiDataFromImage()
    
    //    if let image = UIImage(named: "sample2") {
    //        analyzeImageWithGemini(image: image)
    //    }
    speechRecognizer?.delegate = self
    requestSpeechAuth()
  }
  
  
  private func showImageSourceOptions() {
    let alert = UIAlertController(title: "Select Image", message: nil, preferredStyle: .actionSheet)
    
    // Camera Option
    alert.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { _ in
      self.openCamera()
    }))
    
    // Gallery Option
    alert.addAction(UIAlertAction(title: "Choose from Library", style: .default, handler: { _ in
      self.openGallery()
    }))
    
    // Cancel Option
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    // For iPad support
    if let popover = alert.popoverPresentationController {
      popover.sourceView = self.view
      popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
      popover.permittedArrowDirections = []
    }
    
    present(alert, animated: true)
  }
  
  private func openCamera() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      print("Camera not available")
      return
    }
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = self
    picker.allowsEditing = true
    present(picker, animated: true)
  }
  
  private func openGallery() {
    guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
      print("Photo Library not available")
      return
    }
    let picker = UIImagePickerController()
    picker.sourceType = .photoLibrary
    picker.delegate = self
    picker.allowsEditing = true
    present(picker, animated: true)
  }
  
  @IBAction func imageButtonTapped(_ sender: Any) {
    showImageSourceOptions()
  }
  
  @IBAction func micButtonTapped(_ sender: Any) {
    if audioEngine.isRunning {
      stopRecording()
    } else {
      try? startRecording()
    }
  }
  
  //MARK: - Request to speech
  func requestSpeechAuth() {
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        if status != .authorized {
          print("Speech recognition not authorized")
        }
      }
    }
  }
  
  //MARK: - Start recording
  func startRecording() throws {
    recognitionTask?.cancel()
    recognitionTask = nil
    
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create request") }
    
    recognitionRequest.shouldReportPartialResults = true
    
    let inputNode = audioEngine.inputNode
    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
      if let result = result {
        let spokenText = result.bestTranscription.formattedString
        print("Recognized Speech: \(spokenText)")
        
        if result.isFinal {
          self.audioEngine.stop()
          inputNode.removeTap(onBus: 0)
          self.sendToGemini(prompt: spokenText) // Send recognized text to Gemini
        }
      }
      
      if error != nil {
        self.audioEngine.stop()
        inputNode.removeTap(onBus: 0)
      }
    }
    
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
      self.recognitionRequest?.append(buffer)
    }
    
    audioEngine.prepare()
    try audioEngine.start()
  }
  
  //MARK: - stop recording
  func stopRecording() {
    audioEngine.stop()
    recognitionRequest?.endAudio()
  }
  
  //MARK: - need to send prompt to gemini api call
  func sendToGemini(prompt: String) {
    print("Send to Gemini: \(prompt)")
    extractDataFromText(Prompt: prompt) { jsonString in
      if let jsonString = jsonString {
        print("Extracted JSON: \(jsonString)")
      } else {
        print("Failed to extract data")
      }
    }
  }
  
  //MARK: - Data fetch directly from image through gemini api
  func callApiDataFromImage(){
    if let image = UIImage(named: "sample5") {
      extractDataFromImage(image: image) { jsonString in
        if let jsonString = jsonString {
          print("Extracted JSON: \(jsonString)")
        } else {
          print("Failed to extract data")
        }
      }
    }
  }
  
  //MARK: - Gemini api call to get data from image
  func extractDataFromImage(image: UIImage, completion: @escaping (String?) -> Void) {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
      print("Error: Could not convert image to JPEG data")
      completion(nil)
      return
    }
    
    let base64Image = imageData.base64EncodedString()
    
    let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
    
    let requestBody: [String: Any] = [
      "contents": [
        [
          "parts": [
            [
              "text": "Extract subscription provider, plan name, price, period and currency from this image. The currency must always be returned as a valid ISO 4217 currency code. Return only valid JSON in this format: {\"subscriptions\":[{\"provider\":\"string\",\"plans\":[{\"name\":\"string\",\"price\":\"string\",\"period\":\"string\",\"currency\":\"string\"}]}]} If a value is missing, return it as an empty string."
            ],
            [
              "inline_data": [
                "mime_type": "image/jpeg",
                "data": base64Image
              ]
            ]
          ]
        ]
      ]
    ]
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      print("Error encoding request body: \(error)")
      completion(nil)
      return
    }
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        print("Request error: \(error)")
        completion(nil)
        return
      }
      
      guard let data = data else {
        print("No data received")
        completion(nil)
        return
      }
      
      do {
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        let extractedText = decoded.candidates.first?.content.parts.first?.text
        completion(extractedText)
      } catch {
        print("Error decoding response: \(error)")
        if let raw = String(data: data, encoding: .utf8) {
          print("Raw response: \(raw)")
        }
        completion(nil)
      }
    }
    
    task.resume()
  }
  
  //MARK: - Gemini api call to get data from text
  func extractDataFromText(Prompt: String, completion: @escaping (String?) -> Void) {
    
    let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
    
    let requestBody: [String: Any] = [
      "contents": [
        [
          "parts": [
            [
              "text": "\(Prompt)Extract subscription provider, plan name, price, period and currency from this image. The currency must always be returned as a valid ISO 4217 currency code. Return only valid JSON in this format: {\"subscriptions\":[{\"provider\":\"string\",\"plans\":[{\"name\":\"string\",\"price\":\"string\",\"period\":\"string\",\"currency\":\"string\"}]}]} If a value is missing, return it as an empty string."
            ],
          ]
        ]
      ]
    ]
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    } catch {
      print("Error encoding request body: \(error)")
      completion(nil)
      return
    }
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        print("Request error: \(error)")
        completion(nil)
        return
      }
      
      guard let data = data else {
        print("No data received")
        completion(nil)
        return
      }
      
      do {
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        let extractedText = decoded.candidates.first?.content.parts.first?.text
        completion(extractedText)
      } catch {
        print("Error decoding response: \(error)")
        if let raw = String(data: data, encoding: .utf8) {
          print("Raw response: \(raw)")
        }
        completion(nil)
      }
    }
    
    task.resume()
  }
  
  //MARK: - Extract text from image using vision
  func extractTextFromImage(_ image: UIImage) {
    guard let cgImage = image.cgImage else { return }
    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    
    let request = VNRecognizeTextRequest { (request, error) in
      guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
      let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
      print("Extracted text: \(text)")
      // Parse text to detect subscription info
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    
    try? requestHandler.perform([request])
  }
}

extension ViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    
    if let selectedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
      extractDataFromImage(image: selectedImage) { jsonString in
        if let jsonString = jsonString {
          print("Extracted JSON: \(jsonString)")
        } else {
          print("Failed to extract data")
        }
      }
    }
  }
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
  }
}

struct GeminiResponse: Codable {
  let candidates: [Candidate]
}

struct Candidate: Codable {
  let content: Content
}

struct Content: Codable {
  let parts: [Part]
}

struct Part: Codable {
  let text: String?
}

/*
 
 //MARK: - not accurate
 func extractDataFromText(text:String){
   let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!

   let prompt = """
   Return only valid JSON.
   Do not include any text, explanation, or markdown code fences.
   The JSON must follow exactly this schema:
   {
       "subscriptions": [
           {
               "provider": "string",
               "plans": [
                   {
                       "name": "string",
                       "price": "string",
                       "period": "string"
                   }
               ]
           }
       ]
   }
   If any data is missing, use empty String for the value.
   \(text)
   """

   let payload: [String: Any] = [
       "contents": [
           ["parts": [["text": prompt]]]
       ]
   ]

   var request = URLRequest(url: url)
   request.httpMethod = "POST"
   request.setValue("application/json", forHTTPHeaderField: "Content-Type")
   request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

   URLSession.shared.dataTask(with: request) { data, response, error in
       if let data = data, let result = String(data: data, encoding: .utf8) {
           print(result)
//          self.parseGeminiResponse(data)
       }
   }.resume()
 }
 
 func analyzeImageWithGemini(image: UIImage) {
     // Your Gemini API Key
//      let apiKey = "YOUR_GEMINI_API_KEY"
     let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
     
     // Convert image to Base64
     guard let imageData = image.jpegData(compressionQuality: 0.8) else {
         print("Failed to convert image to data")
         return
     }
     let base64Image = imageData.base64EncodedString()
     
     // Prepare JSON payload
     let requestBody: [String: Any] = [
         "contents": [
             [
                 "parts": [
                     ["text": "Extract all readable text from this image and return in JSON format"],
                     ["inlineData": [
                         "mimeType": "image/jpeg",
                         "data": base64Image
                     ]]
                 ]
             ]
         ]
     ]
     
     // Convert to JSON
     guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
         print("Failed to create JSON data")
         return
     }
     
     // Prepare URL Request
     var request = URLRequest(url: url)
     request.httpMethod = "POST"
     request.setValue("application/json", forHTTPHeaderField: "Content-Type")
     request.httpBody = jsonData
     
     // Make API Call
     let task = URLSession.shared.dataTask(with: request) { data, response, error in
         if let error = error {
             print("Request error: \(error.localizedDescription)")
             return
         }
         
         guard let data = data else {
             print("No data received")
             return
         }
         
         // Print raw JSON string
         if let jsonString = String(data: data, encoding: .utf8) {
             print("Raw JSON Response:\n\(jsonString)")
         }
     }
     
     task.resume()
 }
 
 */
