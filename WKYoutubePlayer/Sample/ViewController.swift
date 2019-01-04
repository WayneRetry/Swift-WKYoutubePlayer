//
//  ViewController.swift
//  WKYoutubePlayer
//
//  Created by Apple on 2019/1/3.
//  Copyright © 2019 wayne. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var playerView: WKYoutubePlayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        playerView.load(videoId: "9thM5gLs2tg")
    }

}
