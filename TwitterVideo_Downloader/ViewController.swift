//
//  ViewController.swift
//  TwitterVideo_Downloader
//
//  Created by user on 3/28/19.
//  Copyright © 2019 KMHK. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        let url = "https://twitter.com/futurism/status/882987478541533189"
        let url = "https://twitter.com/Ubisoft/status/1110950258912256001"
//        let url = "https://twitter.com/i/status/1110950258912256001"
        
        let downloader = TwitterDownloader(urlString: url)
        downloader.delegate = self
        downloader.startDownload(outDir: nil)
    }


}

extension ViewController: TwitterDownloaderDelegate {
    func downloadingFailed(error: Error) {
        print("downloading failed with error: ", error)
    }


    func downloadingSuccess(url: URL) {
        print("downloading finished")
    }


    func downloadingProgress(progress: Float, status: String)
        
    }
    
}
