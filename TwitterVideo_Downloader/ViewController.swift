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
        
        let downloader = TwitterDownloader(urlString: "https://twitter.com/NorthKoreaDPRK/status/1109862876553117698")
        downloader.delegate = self
        downloader.startDownload(outDir: nil)
    }


}

extension ViewController: TwitterDownloaderDelegate {
    func downloadingFailed(error: Error) {
        print("downloading failed with error: %@", error)
    }
    
}
