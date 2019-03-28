//
//  TwitterDownloader.swift
//  TwitterVideo_Downloader
//
//  Created by user on 3/28/19.
//  Copyright © 2019 KMHK. All rights reserved.
//

//import UIKit
import Foundation
import SwiftSoup


protocol TwitterDownloaderDelegate: AnyObject {
    func downloadingFailed(error: Error)
}

extension TwitterDownloaderDelegate {
    func downloadingFailed(error: Error) { }
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
        
        //twitterUrl = urlString
        twitterUrl = "https://twitter.com/NorthKoreaDPRK/status/1111018049656758272"
    }
    
    
    // MARK: public methods

    func startDownload(outDir: String?) {
        guard let video_player_url = resolveTwitterURL() else {
            self.error_handler!(NSError(domain: "'Invalid twitter URL!'", code: 404, userInfo: nil))
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
        print("video_player_url: ", video_player)
        
        let req = URLRequest(url: URL(string: video_player)!)
        URLSession.shared.dataTask(with: req) { (data, response, error) in
            if error != nil {
                self.error_handler!(error!)
                return
            }
            
            // grab the video client HTML
            //print(String(data: data!, encoding: String.Encoding.utf8)!)
            do {
                let doc = try SwiftSoup.parse(String(data: data!, encoding: String.Encoding.utf8)!)
                let link = try doc.select("script").first()
                let text = try link?.attr("src")
                
                print("js linke: ", text!)
                self.getBearerToken(src: text!)
                
            } catch let error {
                self.error_handler!(error)
            }
        }.resume()
    }
    
    private func getBearerToken(src: String) {
        let req = URLRequest(url: URL(string: src)!)
        URLSession.shared.dataTask(with: req) { (data, response, error) in
            if error != nil {
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
        let player_config = "https://api.twitter.com/1.1/videos/tweet/config/" + tweet_id
        var req = URLRequest(url: URL(string: player_config)!,
                             cachePolicy: URLRequest.CachePolicy.returnCacheDataElseLoad,
                             timeoutInterval: 10)
        req.addValue(token, forHTTPHeaderField: "Authorization")
        
        // Talk to the API to get m3u8 url
        URLSession.shared.dataTask(with: req) { (data, response, error) in
            if error != nil {
                self.error_handler!(error!)
                return
            }
            
            // get m3u8 url
            //print(String(data: data!, encoding: String.Encoding.utf8)!)
            do {
                let doc = try JSONSerialization.jsonObject(with: data!,
                                                           options: JSONSerialization.ReadingOptions.mutableContainers)
                let dict = (doc as! [String: Any])["track"]
                let url = (dict as! [String: Any])["playbackUrl"] as! String
                print("m3u8 url: ", url)
            } catch let error {
                self.error_handler!(error)
            }
        }.resume()
    }
}
