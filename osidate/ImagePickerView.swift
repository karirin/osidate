//
//  ImagePickerView.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

// MARK: - Binding版のImagePickerView（既存コードとの互換性のため）
struct ImagePickerViewBinding: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 更新処理は不要
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerViewBinding
        
        init(_ parent: ImagePickerViewBinding) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Firebase Storage Manager for Images

class ImageStorageManager: ObservableObject {
    private let storage = Storage.storage()
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    
    func uploadImage(_ image: UIImage, path: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])))
            return
        }
        
        isUploading = true
        uploadProgress = 0.0
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let uploadTask = storageRef.putData(imageData, metadata: metadata) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isUploading = false
                self?.uploadProgress = 0.0
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(NSError(domain: "StorageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "ダウンロードURLの取得に失敗しました"])))
                }
            }
        }
        
        // アップロードの進捗を監視
        uploadTask.observe(.progress) { [weak self] snapshot in
            if let progress = snapshot.progress {
                DispatchQueue.main.async {
                    self?.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                }
            }
        }
    }
    
    func deleteImage(at path: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let storageRef = storage.reference().child(path)
        
        storageRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func loadImage(from url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let imageURL = URL(string: url) else {
            completion(.failure(NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "無効なURL"])))
            return
        }
        
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "画像の読み込みに失敗しました"])))
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(image))
            }
        }.resume()
    }
}
