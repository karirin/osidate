//
//  ImageCacheManager.swift
//  osidate
//
//  Created by Apple on 2025/10/04.
//

import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL? = {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ImageCache")
    }()
    
    private init() {
        // メモリキャッシュの設定
        cache.countLimit = 100  // 最大100枚
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB
        
        // ディスクキャッシュディレクトリを作成
        if let cacheDir = cacheDirectory {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        print("📦 ImageCacheManager初期化完了")
    }
    
    // 画像を取得（キャッシュ優先）
    func loadImage(from urlString: String) async throws -> UIImage {
        let cacheKey = urlString as NSString
        
        // 1. メモリキャッシュをチェック
        if let cachedImage = cache.object(forKey: cacheKey) {
            print("✅ メモリキャッシュヒット: \(urlString.suffix(30))")
            return cachedImage
        }
        
        // 2. ディスクキャッシュをチェック
        if let diskImage = loadFromDisk(urlString: urlString) {
            print("✅ ディスクキャッシュヒット: \(urlString.suffix(30))")
            cache.setObject(diskImage, forKey: cacheKey)
            return diskImage
        }
        
        // 3. ネットワークからダウンロード
        print("📥 ダウンロード開始: \(urlString.suffix(30))")
        guard let url = URL(string: urlString) else {
            throw ImageCacheError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageCacheError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }
        
        // キャッシュに保存
        cache.setObject(image, forKey: cacheKey)
        saveToDisk(image: image, urlString: urlString)
        
        print("✅ ダウンロード完了・キャッシュ保存: \(urlString.suffix(30))")
        return image
    }
    
    // ディスクから読み込み
    private func loadFromDisk(urlString: String) -> UIImage? {
        guard let cacheDir = cacheDirectory else { return nil }
        
        let filename = urlString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = cacheDir.appendingPathComponent(filename)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    // ディスクに保存
    private func saveToDisk(image: UIImage, urlString: String) {
        guard let cacheDir = cacheDirectory,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let filename = urlString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = cacheDir.appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
    }
    
    // キャッシュをクリア
    func clearCache() {
        cache.removeAllObjects()
        
        if let cacheDir = cacheDirectory {
            try? fileManager.removeItem(at: cacheDir)
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        print("🗑️ キャッシュをクリアしました")
    }
    
    // キャッシュサイズを取得
    func getCacheSize() -> String {
        guard let cacheDir = cacheDirectory,
              let files = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 MB"
        }
        
        let totalSize = files.reduce(0) { size, url in
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size + fileSize
        }
        
        let sizeInMB = Double(totalSize) / (1024 * 1024)
        return String(format: "%.2f MB", sizeInMB)
    }
}

enum ImageCacheError: Error {
    case invalidURL
    case downloadFailed
    case invalidImageData
}
