//
//  WKYoutubePlayer.swift
//  WKYoutubePlayer
//
//  Created by Wayne on 2019/1/2.
//  Copyright © 2019 wayne. All rights reserved.
//

import Foundation
import WebKit

public protocol WKYoutubePlayerDelegate: class {
    func didBecomeReady(playerView: WKYoutubePlayer)
    func didChangeToState(playerView: WKYoutubePlayer, state: WKYoutubePlayerState)
    func didPlayTime(playerView: WKYoutubePlayer, time: Float)
    func receivedError(playerView: WKYoutubePlayer, error: WKYoutubePlayerErrorCode)
    func initialLoadingView() -> UIView?
    func openToLink(playerView: WKYoutubePlayer, url: URL?)
}

public extension WKYoutubePlayerDelegate {
    func didBecomeReady(playerView: WKYoutubePlayer) {}
    func didChangeToState(playerView: WKYoutubePlayer, state: WKYoutubePlayerState) {}
    func didPlayTime(playerView: WKYoutubePlayer, time: Float) {}
    func receivedError(playerView: WKYoutubePlayer, error: WKYoutubePlayerErrorCode) {}
    func initialLoadingView() -> UIView? { return nil }
    func openToLink(playerView: WKYoutubePlayer, url: URL?) {}
}

public enum WKYoutubePlayerState: String {
    case unstarted = "-1"
    case ended = "0"
    case playing = "1"
    case paused = "2"
    case buffering = "3"
    case cued = "5"
    case unknown = "unknown"
    
    init(state: String) {
        switch state {
        case WKYoutubePlayerState.unstarted.rawValue:
            self = .unstarted
        case WKYoutubePlayerState.ended.rawValue:
            self = .ended
        case WKYoutubePlayerState.playing.rawValue:
            self = .playing
        case WKYoutubePlayerState.paused.rawValue:
            self = .paused
        case WKYoutubePlayerState.cued.rawValue:
            self = .cued
        default:
            self = .unknown
        }
    }
}

public enum WKYoutubePlayerPlaybackQuality: String {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case h720 = "hd720"
    case h1080 = "hd1080"
    case highRes = "highres"
    case auto = "auto"
    case `default` = "default"
    case unknown = "unknown"
    
    init(quality: String) {
        switch quality {
        case WKYoutubePlayerPlaybackQuality.small.rawValue:
            self = .small
        case WKYoutubePlayerPlaybackQuality.medium.rawValue:
            self = .medium
        case WKYoutubePlayerPlaybackQuality.large.rawValue:
            self = .large
        case WKYoutubePlayerPlaybackQuality.h720.rawValue:
            self = .h720
        case WKYoutubePlayerPlaybackQuality.h1080.rawValue:
            self = .h1080
        case WKYoutubePlayerPlaybackQuality.highRes.rawValue:
            self = .highRes
        case WKYoutubePlayerPlaybackQuality.auto.rawValue:
            self = .auto
        case WKYoutubePlayerPlaybackQuality.default.rawValue:
            self = .default
        default:
            self = .unknown
        }
    }
}

public enum WKYoutubePlayerErrorCode: String {
    case invalidParam = "2"
    case html5Error = "5"
    case videoNotFound = "100"
    case notEmbeddable = "101"
    case cannotFindVideo = "105"
    case sameAsNotEmbeddable = "150"
    case unknown = "unknown"
}

private enum WKYoutubePlayerCallback: String {
    case onReady = "onReady"
    case onStateChange = "onStateChange"
    case onPlaybackQualityChange = "onPlaybackQualityChange"
    case onError = "onError"
    case onPlayTime = "onPlayTime"
    case onYouTubeIframeAPIReady = "onYouTubeIframeAPIReady"
    case onYouTubeIframeAPIFailedToLoad = "onYouTubeIframeAPIFailedToLoad"
}

private enum WKYoutubePlayerRegexPattern: String {
    case embedUrl = "^http(s)://(www.)youtube.com/embed/(.*)$"
    case adUrl = "^http(s)://pubads.g.doubleclick.net/pagead/conversion/"
    case oAuth = "^http(s)://accounts.google.com/o/oauth2/(.*)$"
    case staticProxy = "^https://content.googleapis.com/static/proxy.html(.*)$"
    case syndication = "^https://tpc.googlesyndication.com/sodar/(.*).html$"
}

public class WKYoutubePlayer: UIView {
    
    public weak var delegate: WKYoutubePlayerDelegate?
    
    private var config: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        return config
    }()
    private var originUrl: URL?
    private var webView: WKWebView!
    private var loadingView: UIView?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setWebView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setWebView()
    }
    
    //MARK: - Public func
    
    public func load(videoId: String) {
        load(videoId: videoId, playerVars: [:])
    }
    
    public func load(playlistId: String) {
        load(playlistId: playlistId, playerVars: [:])
    }
    
    public func load(videoId: String, playerVars: [String: Any]) {
        let playerParams = ["videoId": videoId, "playerVars": playerVars] as [String : Any]
        loadPlayer(params: playerParams)
    }
    
    public func load(playlistId: String, playerVars: [String: Any]) {
        var temp = [String: Any]()
        temp["listType"] = "playlist"
        temp["list"] = playlistId
        playerVars.forEach{temp[$0] = $1}
        let playerParams = ["playerVars": temp] as [String : Any]
        loadPlayer(params: playerParams)
    }
    
    public func cue(videoId: String, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.cueVideoById('\(videoId)', '\(startSeconds)', '\(quality.rawValue)');", completionHandler: nil)
    }
    
    public func cue(videoId: String, startSeconds: Float, endSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.cueVideoById({'videoId': '\(videoId)', 'startSeconds': '\(startSeconds)', 'endSeconds': '\(endSeconds), 'suggestedQuality': '\(quality.rawValue)'});", completionHandler: nil)
    }
    
    public func load(videoId: String, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.loadVideoById('\(videoId)', '\(startSeconds)', '\(quality.rawValue)');", completionHandler: nil)
    }
    
    public func load(videoId: String, startSeconds: Float, endSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.loadVideoById({'videoId': '\(videoId)', 'startSeconds': '\(startSeconds)', 'endSeconds': '\(endSeconds), 'suggestedQuality': '\(quality.rawValue)'});", completionHandler: nil)
    }
    
    public func cue(videoUrl: String, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.cueVideoByUrl('\(videoUrl)', '\(startSeconds)', '\(quality.rawValue)');", completionHandler: nil)
    }
    
    public func cue(videoUrl: String, startSeconds: Float, endSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.cueVideoByUrl('\(videoUrl)', '\(startSeconds)', '\(endSeconds)', '\(quality.rawValue)');", completionHandler: nil)
    }
    
    public func load(videoUrl: String, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.loadVideoByUrl('\(videoUrl)', '\(startSeconds)', '\(quality.rawValue)');", completionHandler: nil)
    }
    
    public func load(videoUrl: String, startSeconds: Float, endSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.loadVideoByUrl('\(videoUrl)', '\(startSeconds)', '\(endSeconds)', '\(quality.rawValue)');", completionHandler: nil)
    }
    
    public func cue(playlistId: String, index: Int, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        cue(playlist: playlistId, index: index, startSeconds: startSeconds, suggestedQuality: quality)
    }
    
    public func cue(videoIds: [String], index: Int, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        cue(playlist: stringForm(videoIDs: videoIds), index: index, startSeconds: startSeconds, suggestedQuality: quality)
    }
    
    public func load(playlistId: String, index: Int, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        load(playlist: playlistId, index: index, startSeconds: startSeconds, suggestedQuality: quality)
    }
    
    public func load(videoIds: [String], index: Int, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        load(playlist: stringForm(videoIDs: videoIds), index: index, startSeconds: startSeconds, suggestedQuality: quality)
    }
    
    //MARK: - Player action
    
    public func playVideo() {
        webView.evaluateJavaScript("player.playVideo();", completionHandler: nil)
    }
    
    public func pauseVideo() {
        webView.evaluateJavaScript("player.pauseVideo();", completionHandler: nil)
    }
    
    public func stopVideo() {
        webView.evaluateJavaScript("player.stopVideo();", completionHandler: nil)
    }
    
    public func mute() {
        webView.evaluateJavaScript("player.mute();", completionHandler: nil)
    }
    
    public func unMute() {
        webView.evaluateJavaScript("player.unMute();", completionHandler: nil)
    }
    
    public func setLoop(loop: Bool) {
        webView.evaluateJavaScript("player.setLoop(\(stringForBool(boolValue: loop)));", completionHandler: nil)
    }
    
    public func setShuffle(loop: Bool) {
        webView.evaluateJavaScript("player.setShuffle(\(stringForBool(boolValue: loop)));", completionHandler: nil)
    }
    
    public func setPlaybackQuality(quality: WKYoutubePlayerPlaybackQuality) {
        //no supported
        webView.evaluateJavaScript("player.setPlaybackQuality('\(quality.rawValue)');", completionHandler: nil)
    }
    
    public func nextVideo() {
        webView.evaluateJavaScript("player.nextVideo();", completionHandler: nil)
    }
    
    public func previousVideo() {
        webView.evaluateJavaScript("player.previousVideo();", completionHandler: nil)
    }
    
    public func playVideo(AtIndex index: Int) {
        webView.evaluateJavaScript("player.playVideoAt(\(index));", completionHandler: nil)
    }
    
    /*
     The allowSeekAhead parameter determines whether the player will make a new request to the server if the seconds parameter specifies a time outside of the currently buffered video data.
     We recommend that you set this parameter to false while the user drags the mouse along a video progress bar and then set it to true when the user releases the mouse. This approach lets a user scroll to different points of a video without requesting new video streams by scrolling past unbuffered points in the video. When the user releases the mouse button, the player advances to the desired point in the video and requests a new video stream if necessary.
    */
    public func seekToSeconds(seconds: Float, allowSeekAhead: Bool) {
        webView.evaluateJavaScript("player.seekTo(\(seconds), \(stringForBool(boolValue: allowSeekAhead)));", completionHandler: nil)
    }
    
    //MARK: - Player Value
    
    public func getVideoLoadedFraction(completed: @escaping (Float) -> Void) {
        webView.evaluateJavaScript("player.getVideoLoadedFraction();") { (response, error) in
            if error != nil {
                //print("getVideoLoadedFraction error: \(error.debugDescription)")
            } else {
                if let fraction = response as? Float {
                    completed(fraction)
                    //print("getVideoLoadedFraction \(fraction)")
                    return
                }
            }
            completed(0)
        }
    }
    
    public func getPlayerState(completed: @escaping (WKYoutubePlayerState) -> Void) {
        webView.evaluateJavaScript("player.getPlayerState();") { (response, error) in
            if error != nil {
                //print("getPlayerState error: \(error.debugDescription)")
            } else {
                if let response = response as? Int {
                    let state = WKYoutubePlayerState(state: String(response))
                    completed(state)
                    //print("getPlayerState \(state)")
                    return
                }
            }
            completed(.unknown)
        }
    }
    
    public func getCurrentTime(completed: @escaping (Float) -> Void) {
        webView.evaluateJavaScript("player.getCurrentTime();") { (response, error) in
            if error != nil {
                //print("getCurrentTime error: \(error.debugDescription)")
            } else {
                if let response = response as? Float {
                    completed(response)
                    //print("getCurrentTime \(response)")
                    return
                }
            }
            completed(0)
        }
    }
    
    public func getPlaybackQuality(completed: @escaping (WKYoutubePlayerPlaybackQuality) -> Void) {
        webView.evaluateJavaScript("player.getPlaybackQuality();") { (response, error) in
            if error != nil {
                //print("getPlaybackQuality error: \(error.debugDescription)")
            } else {
                if let response = response as? Int {
                    let quality = WKYoutubePlayerPlaybackQuality(quality: String(response))
                    completed(quality)
                    //print("getPlaybackQuality \(quality)")
                    return
                }
            }
            completed(.unknown)
        }
    }
    
    public func getDuration(completed: @escaping (TimeInterval) -> Void) {
        webView.evaluateJavaScript("player.getDuration();") { (response, error) in
            if error != nil {
                //print("getDuration error: \(error.debugDescription)")
            } else {
                if let response = response as? Double {
                    completed(response)
                    //print("getDuration \(response)")
                    return
                }
            }
            completed(0)
        }
    }
    
    public func isMuted(completed: @escaping (Bool) -> Void) {
        webView.evaluateJavaScript("player.isMuted();") { (response, error) in
            if error != nil {
                //print("isMuted error: \(error.debugDescription)")
            } else {
                if let response = response as? Bool {
                    completed(response)
                    //print("isMuted \(response)")
                    return
                }
            }
            completed(false)
        }
    }
    
    public func getVideoUrl(completed: @escaping (URL?) -> Void) {
        webView.evaluateJavaScript("player.getVideoUrl();") { (response, error) in
            if error != nil {
                //print("getVideoUrl error: \(error.debugDescription)")
            } else {
                if let response = response as? String {
                    completed(URL(string: response))
                    //print("getVideoUrl \(response)")
                    return
                }
            }
            completed(nil)
        }
    }
    
    public func getAvailableQualityLevels(completed: @escaping ([WKYoutubePlayerPlaybackQuality]) -> Void) {
        webView.evaluateJavaScript("player.getAvailableQualityLevels().toString();") { (response, error) in
            if error != nil {
                //print("getAvailableQualityLevels error: \(error.debugDescription)")
            } else {
                if let response = response as? String {
                    let rawQualityValues = response.components(separatedBy: ",")
                    var levels = [WKYoutubePlayerPlaybackQuality]()
                    for value in rawQualityValues {
                        let quality = WKYoutubePlayerPlaybackQuality(quality: value)
                        levels.append(quality)
                    }
                    completed(levels)
                    //print("getAvailableQualityLevels \(response)")
                    return
                }
            }
            completed([])
        }
    }
    
    public func getVideoEmbedCode(completed: @escaping (String?) -> Void) {
        webView.evaluateJavaScript("player.getVideoEmbedCode();") { (response, error) in
            if error != nil {
                //print("getVideoEmbedCode error: \(error.debugDescription)")
            } else {
                if let response = response as? String {
                    completed(response)
                    //print("getVideoEmbedCode \(response)")
                    return
                }
            }
            completed(nil)
        }
    }
    
    public func getPlaylist(completed: @escaping ([String]?) -> Void) {
        webView.evaluateJavaScript("player.getPlaylist();") { (response, error) in
            if error != nil {
                //print("getPlaylist error: \(error.debugDescription)")
            } else {
                if let response = response as? [String] {
                    completed(response)
                    //print("getPlaylist \(response)")
                    return
                }
                if let response = response as? String {
                    if let data = response.data(using: .utf8) {
                        if let videos = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String] {
                            completed(videos)
                            //print("getPlaylist \(response)")
                            return
                        }
                    }
                }
            }
            completed(nil)
        }
    }
    
    public func getPlaylistIndex(completed: @escaping (Int) -> Void) {
        webView.evaluateJavaScript("player.getPlaylistIndex();") { (response, error) in
            if error != nil {
                //print("getPlaylistIndex error: \(error.debugDescription)")
            } else {
                if let response = response as? Int {
                    completed(response)
                    //print("getPlaylistIndex \(response)")
                    return
                }
            }
            completed(0)
        }
    }

    //MARK: - Private func
    
    private func setWebView() {
        let webView = WKWebView(frame: .zero, configuration: config)
        self.webView = webView
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.isScrollEnabled = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0)
            ])
    }
    
    private func loadPlayer(params: [String: Any]) {
        let callback = [
            "onReady": "onReady",
            "onStateChange": "onStateChange",
            "onError": "onError"
        ]
        
        var parameters = params
        if parameters["height"] == nil {
            parameters["height"] = "100%"
        }
        if parameters["width"] == nil {
            parameters["width"] = "100%"
        }
        parameters["events"] = callback
        
        if let playerVars = parameters["playerVars"] as? [String: Any] {
            if let origin = playerVars["origin"] as? String {
                originUrl = URL(string: origin)
            } else {
                originUrl = URL(string: "about:blank")
            }
        } else {
            parameters["playerVars"] = [String: Any]()
        }
        
        let embedHtml = embedHTMLTemplate()
        let jsonParamster = serializedJSON(parameters: parameters)
        
        let htmlString = embedHtml.replacingOccurrences(of: "%@", with: jsonParamster)
        webView?.loadHTMLString(htmlString, baseURL: originUrl)
        
        var loadingView = delegate?.initialLoadingView()
        if loadingView == nil {
            loadingView = defaultInitialLoadingView()
        }
        self.insertSubview(loadingView!, at: 0)
        loadingView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingView!.topAnchor.constraint(equalTo: webView!.topAnchor, constant: 0),
            loadingView!.leadingAnchor.constraint(equalTo: webView!.leadingAnchor, constant: 0),
            loadingView!.bottomAnchor.constraint(equalTo: webView!.bottomAnchor, constant: 0),
            loadingView!.trailingAnchor.constraint(equalTo: webView!.trailingAnchor, constant: 0)
        ])
        self.loadingView = loadingView
        
    }
    
    private func embedHTMLTemplate() -> String {
        guard let path = Bundle(for: WKYoutubePlayer.self).path(forResource: "YTPlayerView", ofType: "html") else {
            assertionFailure("no HTML file found!")
            return ""
        }
        do {
            let htmlString = try NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
            return htmlString as String
        } catch {
            assertionFailure("no HTML file found!")
            return ""
        }
    }
    
    private func serializedJSON(parameters: [String : Any]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            return NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
        } catch {
            assertionFailure("parsing JSON Error")
            return ""
        }
    }
    
    private func notifyDelegateOfYoutubeCallback(url: URL?) {
        guard let url = url, let action = url.host else {
            return
        }
        let query = url.query
        var data = ""
        if let value = query?.components(separatedBy: "=").last {
            data = value
        }
        
        switch action {
        case WKYoutubePlayerCallback.onReady.rawValue:
            delegate?.didBecomeReady(playerView: self)
            loadingView?.removeFromSuperview()
            //print("didBecomReady")
        case WKYoutubePlayerCallback.onStateChange.rawValue:
            var state = WKYoutubePlayerState.unknown
            switch data {
            case WKYoutubePlayerState.ended.rawValue:
                state = .ended
            case WKYoutubePlayerState.playing.rawValue:
                state = .playing
            case WKYoutubePlayerState.paused.rawValue:
                state = .paused
            case WKYoutubePlayerState.buffering.rawValue:
                state = .buffering
            case WKYoutubePlayerState.cued.rawValue:
                state = .cued
            case WKYoutubePlayerState.unstarted.rawValue:
                state = .unstarted
            default:
                break
            }
            delegate?.didChangeToState(playerView: self, state: state)
            //print("didChangeToState \(state)")
            
        case WKYoutubePlayerCallback.onError.rawValue:
            var error = WKYoutubePlayerErrorCode.unknown
            
            switch data {
            case WKYoutubePlayerErrorCode.invalidParam.rawValue:
                error = .invalidParam
            case WKYoutubePlayerErrorCode.html5Error.rawValue:
                error = .html5Error
            case WKYoutubePlayerErrorCode.notEmbeddable.rawValue, WKYoutubePlayerErrorCode.sameAsNotEmbeddable.rawValue:
                error = .notEmbeddable
            case WKYoutubePlayerErrorCode.videoNotFound.rawValue, WKYoutubePlayerErrorCode.cannotFindVideo.rawValue:
                error = .videoNotFound
            default:
                break
            }
            delegate?.receivedError(playerView: self, error: error)
            //print("receivedError \(error)")
            
        case WKYoutubePlayerCallback.onPlayTime.rawValue:
            if let time = Float(data) {
                delegate?.didPlayTime(playerView: self, time: time)
                //print("didPlayTime \(time)")
            }
            
        case WKYoutubePlayerCallback.onYouTubeIframeAPIFailedToLoad.rawValue:
            //print("onYouTubeIframeAPIFailedToLoad")
        
        case WKYoutubePlayerCallback.onYouTubeIframeAPIReady.rawValue:
            //print("onYouTubeIframeAPIReady")
            
        default:
            break
        }
    }
    
    private func handleHttpNavigation(url: URL?) -> Bool {
        guard let url = url else {
            return false
        }
        let ytMatch = matchRegular(url: url.absoluteString, pattern: WKYoutubePlayerRegexPattern.embedUrl.rawValue)
        let adMatch = matchRegular(url: url.absoluteString, pattern: WKYoutubePlayerRegexPattern.adUrl.rawValue)
        let syndicationMatch = matchRegular(url: url.absoluteString, pattern: WKYoutubePlayerRegexPattern.syndication.rawValue)
        let oauthMatch = matchRegular(url: url.absoluteString, pattern: WKYoutubePlayerRegexPattern.oAuth.rawValue)
        let staticProxyMatch = matchRegular(url: url.absoluteString, pattern: WKYoutubePlayerRegexPattern.staticProxy.rawValue)
        
        if ytMatch != nil || adMatch != nil || syndicationMatch != nil || oauthMatch != nil || staticProxyMatch != nil {
            return true
        } else {
            return false
        }
    }
    
    private func cue(playlist: String, index: Int, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.cuePlaylist('\(playlist)', '\(index)', '\(startSeconds)', '\(quality.rawValue)');", completionHandler: nil)
    }
    
    private func load(playlist: String, index: Int, startSeconds: Float, suggestedQuality quality: WKYoutubePlayerPlaybackQuality) {
        webView.evaluateJavaScript("player.loadPlaylist('\(playlist)', '\(index)', '\(startSeconds)', '\(quality.rawValue)');", completionHandler: nil)
    }
    
    private func stringForm(videoIDs: [String]) -> String {
        let formatted = videoIDs.map{"'\($0)'"}
        return formatted.joined(separator: ", ")
    }
    
    private func matchRegular(url: String, pattern: String) -> String? {
        let regExp = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsLink = url as NSString
        let options = NSRegularExpression.MatchingOptions(rawValue: 0)
        let range = NSRange(location: 0, length: nsLink.length)
        let matches = regExp?.matches(in: url, options:options, range:range)
        if let firstMatch = matches?.first {
            return nsLink.substring(with: firstMatch.range)
        }
        return nil
    }
    
    private func stringForBool(boolValue: Bool) -> String {
        return boolValue ? "true" : "false"
    }
    
    private func defaultInitialLoadingView() -> UIView {
        let emptyView = UIView()
        emptyView.backgroundColor = .clear
        let activity = UIActivityIndicatorView(style: .gray)
        activity.startAnimating()
        activity.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(activity)
        activity.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor, constant: 0).isActive = true
        activity.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor, constant: 0).isActive = true
        return emptyView
    }
    
    private func defaultOpenToLink(url: URL?) {
        if let url = url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

extension WKYoutubePlayer: WKUIDelegate, WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingView?.removeFromSuperview()
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let request = navigationAction.request

        if request.url?.host == originUrl?.host {
            decisionHandler(.allow)
            return
        } else if request.url?.scheme == "ytplayer" {
            notifyDelegateOfYoutubeCallback(url: request.url)
            decisionHandler(.cancel)
            return
        } else if request.url?.scheme == "http" || request.url?.scheme == "https" {
            if handleHttpNavigation(url: request.url) {
                decisionHandler(.allow)
            } else {
                if delegate == nil {
                    defaultOpenToLink(url: request.url)
                } else {
                    delegate?.openToLink(playerView: self, url: request.url)
                }
                decisionHandler(.cancel)
            }
            return
        }
        
        decisionHandler(.allow)
    }
    
}
