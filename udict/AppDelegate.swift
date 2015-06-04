//
//  AppDelegate.swift
//  udict
//
//  Created by ning on 6/4/15.
//  Copyright (c) 2015 ning. All rights reserved.
//

import Foundation
import Cocoa
import AppKit
import WebKit
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    var webView: WebView!
 
    var lastWrod: String = ""
    var word: String = ""
    
    func startMonitorDoubleClick() {
        NSEvent.addGlobalMonitorForEventsMatchingMask(
            .LeftMouseDownMask,
            handler: { (event: NSEvent!) -> Void in
                if event.clickCount != 2 {
                    self.lastWrod = ""
                    self.window.orderOut(nil)
                    return
                }
                NSLog("---------Double Click: %@", event);
                self.checkSelection()
        })
        
        NSLog("Started monitoring.")
    }
    
    func showWin(html: String) {
        NSLog("showWin")
        let p:NSPoint = NSEvent.mouseLocation()
        window.setFrameTopLeftPoint(NSPoint(x: p.x + 5, y: p.y-15))
        
        window.makeKeyAndOrderFront(nil)
        
        let baseURL = NSURL(string: "http://www.baidu.com")
        webView.mainFrame.loadHTMLString(html, baseURL: baseURL!)
    }
    
    func checkSelection() -> String {
        var oldValue: String = getPasteboard()
        
        sendCmdC()
        
        NSTimer.scheduledTimerWithTimeInterval(0.2, target: self, selector: "getWordToQuery", userInfo:nil, repeats: false)
        return ""
    }
    
    func sendCmdC() {
        var keyDown : CGEvent = CGEventCreateKeyboardEvent (nil, CGKeyCode(8), true).takeUnretainedValue()
        CGEventSetFlags(keyDown, UInt64(kCGEventFlagMaskCommand|0x000008)) //0008 for iterm2
        CGEventPost(UInt32(kCGHIDEventTap), keyDown)
        
        var keyUp : CGEvent = CGEventCreateKeyboardEvent (nil, CGKeyCode(8), false).takeUnretainedValue()
        CGEventSetFlags(keyUp, UInt64(kCGEventFlagMaskCommand))
        CGEventPost(UInt32(kCGHIDEventTap), keyUp)
    }
    
    func getPasteboard() -> String {
        var pb: NSPasteboard = NSPasteboard.generalPasteboard()
        var targetType: String?
        var value: String? = ""
        
        targetType = pb.availableTypeFromArray([NSPasteboardTypeString])
        if (targetType != nil) {
            value = pb.stringForType(targetType!)
            NSLog("pasteboard.value: %@", value!)
            return value!
        }
        return ""
    }
    
    func getSelectedWord() -> String {
        var value = getPasteboard()
        var word = value.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        
        word = firstMatch("[a-zA-Z]*", text: word)
        
        word = word.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        
        return word
    }
    
    func firstMatch(regex: String!, text: String!) -> String {
        let re = NSRegularExpression(pattern: regex, options: nil, error: nil)!
        let nsString = text as NSString
        
        let match = re.firstMatchInString(text, options: .WithoutAnchoringBounds,
            range: NSMakeRange(0, nsString.length))
        if match != nil {
            return nsString.substringWithRange(match!.rangeAtIndex(0))
        }
        return ""
    }
    
    func getWordToQuery() {
        var word = getSelectedWord()
        
        if word == "" {
            window.orderOut(nil)
            lastWrod = ""
            return
        }
        
        NSLog("query word: %@", word)
        
        self.query(word)
        self.play(word)
    }
    
    func query(word: String){
        let url = NSURL(string: "http://fanyi.youdao.com/openapi.do?keyfrom=tinxing&key=1312427901&type=data&doctype=json&version=1.1&q=" + word)
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            //println(NSString(data: data, encoding: NSUTF8StringEncoding))
            
            let js = JSON(data: data)
            let translation = js["translation"][0].stringValue
            let explains = js["basic"]["explains"][0].stringValue
            let html = String(format: "<h2>%@</h2> <hr> %@", translation, explains)
            
            dispatch_async(dispatch_get_main_queue()) {
                self.showWin(html)
            }
        }
        task.resume()
    }
    
    func play(word: String) {
        self.word = word
        let thread = NSThread(target:self, selector:"play2", object:nil)
        thread.start()
    }
    
    func play2() {
        var word = self.word
        var player : AVAudioPlayer! = nil
        
        let url = NSURL(string: "http://dict.youdao.com/dictvoice?audio=" + word)
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            
            data.writeToFile("/private/tmp/xx.mp3", atomically: false)
            
            let url = NSURL(fileURLWithPath: "/private/tmp/xx.mp3")
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                var error: NSError? = nil
                player = AVAudioPlayer(contentsOfURL: url, error: &error)
                if error != nil {
                    NSLog("error != nil")
                    return
                }
                NSLog("player %@", player)
                
                player.play()
                //sleep(1)
                NSThread.sleepForTimeInterval(player.duration)
                NSLog("play %@", url!)
            })
        }
        task.resume()
    }
    
    func initWindow() {
        window.opaque = false
        window.alphaValue = 0.88
        window.level = Int(CGWindowLevelForKey(Int32(kCGStatusWindowLevelKey)))
        window.ignoresMouseEvents = true
        window.collectionBehavior =  NSWindowCollectionBehavior.CanJoinAllSpaces

        var frame = window.frame
        frame.size.width = 200
        frame.size.height = 70
        window.setFrame(frame, display: true)
        
        window.alphaValue = 0.9
        
        window.styleMask = NSBorderlessWindowMask
        
        window.title = "title"
        webView = WebView(frame: self.window.contentView.frame)
        self.window.contentView.addSubview(webView)
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        initWindow()
        
        // method 1
        startMonitorDoubleClick()
        
        // method 2
        //NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "getSelection", userInfo:nil, repeats: true)
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}