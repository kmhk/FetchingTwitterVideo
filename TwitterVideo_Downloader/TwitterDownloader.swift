//
//  TwitterDownloader.swift
//  TwitterVideo_Downloader
//
//  Created by user on 3/28/19.
//  Copyright © 2019 KMHK. All rights reserved.
//

import Foundation
import SwiftSoup
import NicooM3u8Downloader


protocol TwitterDownloaderDelegate: AnyObject {
    func downloadingSuccess(url: URL)
    func downloadingFailed(error: Error)
    func downloadingProgress(progress: Float, status: String)
}

extension TwitterDownloaderDelegate {
    func downloadingSuccess(url: URL) { }
    func downloadingFailed(error: Error) { }
    func downloadingProgress(progress: Float, status: String) { }
}

class TwitterDownloader: NSObject {
    
    // MARK: member variables
    
    var twitterUrl: String?
    var tweet_id: String = ""
    var output_dir: String?
    
    weak var delegate: TwitterDownloaderDelegate?
    
    private var error_handler: ((Error) -> ())?
    
    
    // MARK: life cycling
    
    init(urlString: String) {
        super.init()
        
        error_handler = { error in
            if self.delegate != nil {
                self.delegate?.downloadingFailed(error: error)
            }
        }
        
        twitterUrl = urlString
    }
    
    
    // MARK: public methods

    func startDownload(outDir: String?) {
        guard let video_player_url = resolveTwitterURL() else {
            self.error_handler!(NSError(domain: "'Invalid twitter video URL!'", code: 404, userInfo: nil))
            return
        }
        
        grabVideoClient(video_player: video_player_url)
    }
    
    
    // MARK: private methods
    
    private func resolveTwitterURL() -> String? {
        guard let video_url = twitterUrl?.split(separator: "?",
                                                maxSplits: 1,
                                                omittingEmptySubsequences: true)[0] else { return nil }
        guard video_url.split(separator: "/").count > 4 else { return nil }
        
        // parse the tweet ID
        let tweet_user = String(video_url.split(separator: "/")[2])
        tweet_id = String(video_url.split(separator: "/")[4])
        
        output_dir = tweet_user + "/" + tweet_id
        
        let video_player_url = "https://twitter.com/i/videos/tweet/" + tweet_id
        
        return video_player_url
    }
    
    private func grabVideoClient(video_player: String) {
        print("video_player_url: \(video_player)")
        
        let req = URLRequest(url: URL(string: video_player)!)
        URLSession.shared.dataTask(with: req) { (data, response, error) in
            guard error == nil else {
                self.error_handler!(error!)
                return
            }
            
            // grab the video client HTML
            do {
                let doc = try SwiftSoup.parse(String(data: data!, encoding: String.Encoding.utf8)!)
                let link = try doc.select("script").first()
                let text = try link?.attr("src")
                
                print("js link: ", text!)
                self.getBearerToken(src: text!)
                
            } catch let error {
                self.error_handler!(error)
            }
        }.resume()
    }
    
    private func getBearerToken(src: String) {
        let req = URLRequest(url: URL(string: src)!)
        URLSession.shared.dataTask(with: req) { (data, response, error) in
            guard error == nil else {
                self.error_handler!(error!)
                return
            }
            
            // get Bearer token from JS file to talk to the API
            let strings = String(data: data!, encoding: String.Encoding.utf8)!
            let regex = try? NSRegularExpression(pattern: "Bearer ([a-zA-Z0-9%-])+",
                                                 options: NSRegularExpression.Options.caseInsensitive)
            let result = regex!.firstMatch(in: strings,
                                           options: NSRegularExpression.MatchingOptions.reportCompletion,
                                           range: NSRange(strings.startIndex..., in: strings))
            let token = result.map {
                String(strings[Range($0.range, in: strings)!])
            }
            self.getM3U8(token: token!)
        }.resume()
    }
    
    private func getM3U8(token: String) {
        print("talking to api with auth token: \(token)")
        
        let player_config = "https://api.twitter.com/1.1/videos/tweet/config/" + tweet_id
        var req = URLRequest(url: URL(string: player_config)!,
                             cachePolicy: URLRequest.CachePolicy.returnCacheDataElseLoad,
                             timeoutInterval: 10)
        req.addValue(token, forHTTPHeaderField: "Authorization")
        req.addValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        
        // Talk to the API to get m3u8 url
        URLSession.shared.dataTask(with: req) { (data, response, error) in
            guard error == nil else {
                self.error_handler!(error!)
                return
            }
            
            if (response as? HTTPURLResponse)?.statusCode != 200 {
                self.error_handler!(NSError(domain: "'Too many request to twitter!'",
                                            code: ((response as? HTTPURLResponse)?.statusCode)!,
                                            userInfo: nil))
                return
            }
            
            // get video url with m3u8 or vmap
            do {
                let doc = try JSONSerialization.jsonObject(with: data!,
                                                           options: JSONSerialization.ReadingOptions.mutableContainers)
                let dict = (doc as! [String: Any])["track"] as! [String: Any]
                if let url_vmap = (dict["vmapUrl"] as? String) {
                    print("vmap url: ", url_vmap)
                } else if let url_m3u8 = (dict["playbackUrl"] as? String) {
                    print("m3u8 url: ", url_m3u8)
                    self.downloadM3U8(url: url_m3u8)
                } else {
                    print("nothing video url")
                }
                
            } catch let error {
                self.error_handler!(error)
            }
        }.resume()
    }
    
    private func downloadM3U8(url: String) {
        let yagor = NicooYagor()
        yagor.directoryName = tweet_id
        yagor.m3u8URL = url
        yagor.delegate = self
        yagor.parse()
    }
    
    private func mergeTSClip(tmpURL: URL, yagor: NicooYagor) {
        let directoryURL = tmpURL.path + "/" + tweet_id + "/"
        let mergedTS = tmpURL.path + "/" + tweet_id + ".mpg"
        //let mergedTS = directoryURL + tweet_id + ".mpg"
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: directoryURL).sorted()
            
            FileManager.default.createFile(atPath: mergedTS, contents: nil, attributes: nil)
            let writter = FileHandle(forWritingAtPath: mergedTS)
            
            // merge ts clip file
            for file in files {
                if file.lowercased().range(of: ".ts") == nil {
                    continue
                }
                
                let reader = FileHandle(forReadingAtPath: directoryURL + file)
                var data = reader?.readData(ofLength: 0x400)
                while (data?.count)! > 0 {
                    writter?.write(data!)
                    data = reader?.readData(ofLength: 0x400)
                }
                reader?.closeFile()
            }
            writter?.closeFile()
            
            // remove temp ts files
            yagor.deleteDownloadedContents(with: tweet_id)
            
            if self.delegate != nil {
                self.delegate?.downloadingSuccess(url: URL(fileURLWithPath: mergedTS))
            }
            
        } catch let error {
            self.error_handler!(error)
        }
    }
    
}


// MARK: - NicooM3U8Downloader delegate

extension TwitterDownloader: YagorDelegate {
    func videoDownloadSucceeded(by yagor: NicooYagor) {
        let filePath = NicooDownLoadHelper.getDocumentsDirectory().appendingPathComponent(NicooDownLoadHelper.downloadFile)
        //print("downLoadFilePath = \(filePath). videoFileName = \(yagor.directoryName)")
        mergeTSClip(tmpURL: filePath, yagor: yagor)
    }
    
    
    func videoDownloadFailed(by yagor: NicooYagor) {
        //print("Video download failed. \(yagor.directoryName)")
        self.error_handler!(NSError(domain: "Video download failed. \(yagor.directoryName)",
                                    code: 400,
                                    userInfo: nil))
    }
    
    
    func update(progress: Float, yagor: NicooYagor) {
        //print("downloading video \(progress * 100) %...")
        if self.delegate != nil {
            self.delegate?.downloadingProgress(progress: progress, status: "downloading")
        }
    }
}
