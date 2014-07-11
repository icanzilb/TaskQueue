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
            self.text.text = line + "\n" + self.text.text!
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        demoSwitchingQueues()
    }
    
    //
    // Demo method #1
    // Show switching between queues
    //
    func demoSwitchingQueues() {
        let queue = TaskQueue()
        
        queue.tasks += {
            self.logToTextView("\nfunc demoSwitchingQueues()")
            self.logToTextView("====== tasks ======")
            self.logToTextView("task #1: do work on main queue")
        }
        
        // add queue on the main queue - work with UI, etc.
        queue.tasks +=! { result, next in
            self.logToTextView("task #2: animate UI from main queue")

            UIView.animateWithDuration(3, animations: {
                self.text.backgroundColor = UIColor.redColor()
            }) {_ in
                next(nil)
            }
            
        }
        
        // switch to background queue, heavy work, etc.
        queue.tasks +=~ {
            self.logToTextView("task #3: heavy work on low prio queue for 5 secs")
            sleep(5)
        }
        
        // switch back to the main queue - work with UI, etc.
        queue.tasks +=! { result, next in
            self.logToTextView("task #4: animate UI from main queue")
            
            UIView.animateWithDuration(1, animations: {
                self.text.backgroundColor = UIColor.whiteColor()
            }) {_ in
                next(nil)
            }
            
        }

        // when finished with tasks, call the second demo method
        queue.run {_ in
            self.logToTextView("queue finished")
            self.logToTextView("")
            delay(seconds: 1, self.demoRunQueues)
        }
    }

    //
    // Demo method #2
    // Show how to run the queue on different GCD queues
    //
    func demoRunQueues() {
        //main queue taskqueue
        self.logToTextView("\nfunc demoRunQueues()")
        self.logToTextView("create queue on main GCD queue")
        let queueMain = TaskQueue()
        queueMain.tasks += {
            sleep(3)
            return
        }
        queueMain.run(.MainQueue) {_ in
            self.logToTextView("finished queue on main GCD queue")
        }

        //bg queue taskqueue
        self.logToTextView("create queue on low prio GCD queue")
        let queueBg = TaskQueue()
        queueBg.tasks += {
            sleep(3)
            return
        }
        queueBg.run(.BackgroundQueue) {_ in
            self.logToTextView("finished queue on low prio GCD queue")
            delay(seconds: 1, self.demoAllMethods)
        }
        
    }
    
    //
    // Demo method #2
    // Show different flow control methods
    //
    func demoAllMethods() {
        
        let queue = TaskQueue()

        queue.tasks += {
            self.logToTextView("\nfunc demoAllMethods()\n")
            self.logToTextView("====== tasks ======")
            self.logToTextView("task #1: run")
        }

        queue.tasks += {result, next in
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
            queue.run {_ in
                self.logToTextView("completion: appended completion run")
                self.logToTextView("\n---- demo completed ----\n")
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

