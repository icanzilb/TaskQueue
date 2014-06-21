//
//  ViewController.swift
//  TaskQueue
//
//  Created by Marin Todorov on 6/19/14.
//  Copyright (c) 2014 Underplot ltd. All rights reserved.
//

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

