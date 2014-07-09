//
//  ViewController.swift
//
// Copyright (c) 2014 Marin Todorov, Underplot ltd.
// This code is distributed under the terms and conditions of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// This class was heavily inspired by Sequencer (objc) https://github.com/berzniz/Sequencer
// but aimed to 1) bring more flow control 2) port to swift

import UIKit

//
// util function to delay code exection by given interval
//
func delay(#seconds:Double, completion:()->()) {
    let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64( Double(NSEC_PER_SEC) * seconds ))
    
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
        completion()
    }
}

class ViewController: UIViewController {
    
    @IBOutlet var text:UITextView
    
    func logToTextView(line:String) {
        dispatch_async(dispatch_get_main_queue(), {
            self.text.text = self.text.text! + "\n" + line
            })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let queue = TaskQueue()

        queue.tasks += {
            self.logToTextView("====== tasks ======")
            self.logToTextView("task #1: run")
        }

        queue.tasks += { result, next in
            self.logToTextView("task #2: begin")
            
            delay(seconds: 2) {
                self.logToTextView("task #2: end")
                next(nil)
            }
            
        }

        var cnt = 1
        queue.tasks += {[weak queue] result, next in
            self.logToTextView("task #3: try #\(cnt)")
            
            if ++cnt > 3 {
                next(nil)
            } else {
                queue!.retry(delay: 1)
            }
        }

        queue.tasks += ({
            self.logToTextView("task #4: run")
            self.logToTextView("task #4: will skip next task")
            
            queue.skip()
            })

        queue.tasks += {
            self.logToTextView("task #5: run")
        }

        queue.tasks += {
            self.logToTextView("task #6: run")
            
            self.logToTextView("task #6: will append one more completion")
            queue.run {
                _ in self.logToTextView("completion: appended completion run")
            }
            
            self.logToTextView("task #6: will skip all remaining tasks")
            queue.removeAll()
        }

        queue.tasks += {
            self.logToTextView("task #7: run")
        }

        queue.run()

        queue.run {result in
            self.logToTextView("====== completions ======")
            self.logToTextView("initial completion: run")
        }
        
        delay(seconds: 1.5) {[weak queue] in
            self.logToTextView("global: will pause the queue...")
            queue!.pause()
        }
        
        delay(seconds: 5) {[weak queue] in
            self.logToTextView("global: resume the queue")
            queue!.run()
        }
        
    }
}

