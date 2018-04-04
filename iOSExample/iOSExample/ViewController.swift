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
import TaskQueue

class ViewController: UIViewController {
    func delay(seconds:Double, completion: @escaping ()-> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: completion)
    }
    
    @IBOutlet var text:UITextView!
    
    func logToTextView(_ line:String) {
        DispatchQueue.main.async {
            self.text.text = line + "\n" + self.text.text!
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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

            UIView.animate(
                withDuration: 3,
                animations: {
                    self.text.backgroundColor = UIColor.red
                }
            ) { _ in next(nil) }
        }
        
        // switch to background queue, heavy work, etc.
        queue.tasks +=~ {
            self.logToTextView("task #3: heavy work on low prio queue for 5 secs")
            sleep(5)
        }
        
        // switch back to the main queue - work with UI, etc.
        queue.tasks +=! { result, next in
            self.logToTextView("task #4: animate UI from main queue")
            
            UIView.animate(
                withDuration: 1,
                animations: {
                    self.text.backgroundColor = UIColor.white
                }
            ) { _ in next(nil) }
        }

        // when finished with tasks, call the second demo method
        queue.run { [weak self] in
            guard let `self` = self else {return}
            
            self.logToTextView("queue finished")
            self.logToTextView("")
            self.delay(seconds: 1, completion: self.demoAllMethods)
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

        queue.tasks += { [weak self] result, next in
            guard let `self` = self else {return}

            self.logToTextView("task #2: begin")
            self.delay(seconds: 2) {
                self.logToTextView("task #2: end")
                next(nil)
            }
        }

        var cnt = 1
        queue.tasks += { [weak queue] result, next in
            self.logToTextView("task #3: try #\(cnt)")
            
            cnt += 1
            if cnt > 3 {
                next(nil)
            } else {
                queue!.retry(1)
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
            
            queue.run { [weak self] in
                guard let `self` = self else {return}
                self.logToTextView("completion: appended completion run")
                self.delay(seconds: 1.5, completion: self.demoNestedQueues)
            }
            
            self.logToTextView("task #6: will skip all remaining tasks")
            queue.removeAll()
        }

        queue.tasks += {
            self.logToTextView("task #7: run")
        }

        queue.run()

        queue.run {
            self.logToTextView("====== completions ======")
            self.logToTextView("initial completion: run")
        }
        
        delay(seconds: 1.5) { [weak queue] in
            self.logToTextView("global: will pause the queue...")
            queue!.paused = true
        }
        
        delay(seconds: 5) { [weak queue] in
            self.logToTextView("global: resume the queue")
            queue!.run()
        }
    }
    
    //
    // Demo method #3
    // Show nested queues
    //
    func demoNestedQueues() {
        let masterQueue = TaskQueue()
        
        masterQueue.tasks += {
            self.logToTextView("====== nested queues ======")
            self.logToTextView("started master queue");
        }
        
        //define nested queue
        let nestedQueue = TaskQueue()
        nestedQueue.tasks += { [weak self] _, next in
            guard let `self` = self else {return}
            
            self.logToTextView("execute nested task #1")
            self.delay(seconds: 2.0) {
                next(nil)
            }
        }

        nestedQueue.tasks += { [weak self] _, next in
            guard let `self` = self else {return}
            self.logToTextView("execute nested task #2")
            self.delay(seconds: 2.0) {
                next(nil)
            }
        }

        nestedQueue.completions.append({
            self.logToTextView("completed nested queue")
        })
        //end of nested queue
        
        masterQueue.tasks += nestedQueue
            
        masterQueue.tasks += {
            self.logToTextView("back to master queue");
        }

        masterQueue.run { [weak self] in
            guard let `self` = self else {return}
            
            self.logToTextView("master queue completed");
            self.delay(seconds: 1, completion: self.demoConcurrentTasks)
        }
    }
    
    //
    // Demo method #4
    // Concurrent tasks queue
    //
    var concurrentTaskInc = 0
    func demoConcurrentTasks() {
        
        let queue = TaskQueue()
        queue.maximumNumberOfActiveTasks = 3
        
        self.logToTextView("\nfunc demoConcurrentTasks()")
        self.logToTextView("====== concurrent tasks ======")
        
        for _ in 0...10 {
            queue.tasks += {
                self.concurrentTaskInc += 1
                let localInc = self.concurrentTaskInc
                
                self.logToTextView("start  #\(localInc), \(queue.numberOfActiveTasks) running, \(queue.tasks.count) left")
                sleep(2)
                self.logToTextView("finish #\(localInc), \(queue.numberOfActiveTasks) running, \(queue.tasks.count) left")
            }
        }
        
        queue.run {
            self.logToTextView("all concurrent tasks finished\n")
            self.logToTextView("\n---- demo completed ----\n")
        }
    }
}
