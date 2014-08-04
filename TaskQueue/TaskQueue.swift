//
// TaskQueue.swift
//
// Copyright (c) 2014 Marin Todorov, Underplot ltd.
// This code is distributed under the terms and conditions of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// This class was heavily inspired by Sequencer (objc) https://github.com/berzniz/Sequencer
// but aimed to 1) bring more flow control, 2) port to swift, 3) control of GDC queues

import Foundation

// MARK: TaskQueue class

class TaskQueue {
    
    //
    // types used by the TaskQueue
    //
    typealias ClosureNoResultNext = () -> Void
    typealias ClosureWithResult = (AnyObject?) -> Void
    typealias ClosureWithResultNext = (AnyObject? , AnyObject? -> Void) -> Void
    
    //
    // tasks and completions storage
    //
    var tasks:[ClosureWithResultNext] = []
    lazy var completions: [ClosureWithResult] = []

    //
    // queue state
    //
    var running = false
    var paused  = false
    var stopped = false
    
    var currentTask: ClosureWithResultNext? = nil
    var currentResult: AnyObject! = nil
    
    var hasCompletions = false
    var delayUntilNextTask:Double = 0

    //
    // start or resume the queue
    //
    func run(completion:ClosureWithResult? = nil) {
        if completion != nil {
            hasCompletions = true
            completions += [completion!]
        }
        
        if (paused) {
            paused = false
            _runNextTask()
            return
        }
        
        if running {
            return
        }
        
        running = true
        _runNextTask()
    }
    
    //
    // pause the queue execution
    //
    func pause() {
        paused = true
    }
    
    //
    // remove all tasks and completions
    //
    func stop () {
        stopped = true
    }
    
    private func _runNextTask(result: AnyObject? = nil) {
        if (stopped) {
            tasks.removeAll(keepCapacity: false)
            completions.removeAll(keepCapacity: false)
        }
        
        currentResult = result
        
        if paused {
            return
        }
        
        if tasks.count == 0 {
            _complete()
            return
        }
        
        if delayUntilNextTask > 0 {
            
            let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64( Double(NSEC_PER_SEC) * delayUntilNextTask ))
            
            dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
                self._runNextTask(result: result)
            }
            
            delayUntilNextTask = 0
            return
        }
        
        currentTask = tasks.removeAtIndex(0)
        currentTask!(result) { (nextResult:AnyObject?) in
            self._runNextTask(result: nextResult)
        }
        
    }
    
    private func _complete() {
        running = false
        paused = false
        currentTask = nil
        
        if hasCompletions {
            for _ in completions {
                (completions.removeAtIndex(0))(currentResult)
            }
        }
        
        currentResult = nil
    }
    
    //
    // skip the next task
    //
    func skip() {
        if tasks.count>0 {
            _ = tasks.removeAtIndex(0) //better way?
        }
    }
    
    //
    // remove all remaining tasks
    //
    func removeAll() {
        tasks.removeAll(keepCapacity: false)
    }
    
    //
    // count of the tasks left to execute
    //
    var count:Int {
        return tasks.count
    }
    
    //
    // re-run the current task
    //
    func retry(delay:Double = 0) {
        tasks.insert(currentTask!, atIndex: 0)
        currentTask = nil
        
        if delay > 0 {
            delayUntilNextTask = delay
        }
        
        _runNextTask(result: currentResult)
    }

    deinit {
        //println("queue deinit")
    }
}

//
// Operator overlaoding helps to make adding tasks to the queue
// more readable and easy to understand. You just keep adding closures
// to the tasks array and the operators adjust your task to the desired
// ClosureWithResultNext type.
//

infix operator  +=~ {}
infix operator  +=! {}

// MARK: Add tasks on the current queue

//
// Add a task closure with result and next params
//
func += (inout tasks: [TaskQueue.ClosureWithResultNext], task: TaskQueue.ClosureWithResultNext) {
    tasks += [task]
}

//
// Add a task closure that doesn't take result/next params
//
func += (inout tasks: [TaskQueue.ClosureWithResultNext], task: TaskQueue.ClosureNoResultNext) {
    tasks += [{
        _, next in
        task()
        next(nil)
    }]
}

// MARK: Add tasks on a background queueu

//
// Add a task closure that doesn't take result/next params
// The task gets executed on a low prio queueu
//
func +=~ (inout tasks: [TaskQueue.ClosureWithResultNext], task: TaskQueue.ClosureNoResultNext) {
    tasks += [{
        _, next in
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), {
            task()
            next(nil)
        })
    }]
}

//
// The task gets executed on a low prio queueu
//
func +=~ (inout tasks: [TaskQueue.ClosureWithResultNext], task: TaskQueue.ClosureWithResultNext) {
    tasks += [{result, next in
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), {
            task(result, next)
        })
    }]
}

// MARK: Add tasks on the main queue

//
// Add a task closure that doesn't take result/next params
// The task gets executed on the main queue - update UI, etc.
//
func +=! (inout tasks: [TaskQueue.ClosureWithResultNext], task: TaskQueue.ClosureNoResultNext) {
    tasks += [{
        _, next in
        dispatch_async(dispatch_get_main_queue(), {
            task()
            next(nil)
        })
    }]
}

//
// The task gets executed on the main queue - update UI, etc.
//
func +=! (inout tasks: [TaskQueue.ClosureWithResultNext], task: TaskQueue.ClosureWithResultNext) {
    tasks += [{
        result, next in
        dispatch_async(dispatch_get_main_queue(), {
            task(result, next)
        })
    }]
}