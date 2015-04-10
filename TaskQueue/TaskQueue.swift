//
// TaskQueue.swift ver. 0.9.6
//
// Copyright (c) 2014 Marin Todorov, Underplot ltd.
// This code is distributed under the terms and conditions of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// This class is inspired by Sequencer (objc) https://github.com/berzniz/Sequencer
// but aims to implement 1) flow control, 2) swift code, 3) control of GDC queues, 4) concurrency

import Foundation

// MARK: TaskQueue class

class TaskQueue: Printable {

    //
    // types used by the TaskQueue
    //
    typealias ClosureNoResultNext = () -> Void
    typealias ClosureWithResult = (AnyObject?) -> Void
    typealias ClosureWithResultNext = (AnyObject? , AnyObject? -> Void) -> Void
    
    //
    // tasks and completions storage
    //
    var tasks: [ClosureWithResultNext] = []
    lazy var completions: [ClosureNoResultNext] = []
    
    //
    // concurrency
    //
    private(set) var numberOfActiveTasks: Int = 0
    var maximumNumberOfActiveTasks: Int = 1 {
        willSet {
            assert(maximumNumberOfActiveTasks>0, "Setting less than 1 task at a time not allowed")
        }
    }
    
    private var currentTask: ClosureWithResultNext? = nil
    private(set) var lastResult: AnyObject! = nil
    
    //
    // queue state
    //
    private(set) var running = false
    
    var paused: Bool = false {
        didSet {
            running = !paused
        }
    }
    
    private var cancelled = false
    func cancel() {
        cancelled = true
    }
    
    private var hasCompletions = false

    //
    // start or resume the queue
    //
    func run(completion: ClosureNoResultNext? = nil) {
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
    
    private func _runNextTask(result: AnyObject? = nil) {
        if (cancelled) {
            tasks.removeAll(keepCapacity: false)
            completions.removeAll(keepCapacity: false)
        }
        
        if (numberOfActiveTasks >= maximumNumberOfActiveTasks) {
            return
        }
        
        lastResult = result
        
        if paused {
            return
        }
        
        var task: ClosureWithResultNext? = nil
        
        //fetch one task synchronized
        objc_sync_enter(self)
        if self.tasks.count > 0 {
            task = self.tasks.removeAtIndex(0)
            self.numberOfActiveTasks++
        }
        objc_sync_exit(self)

        if task == nil {
            if self.numberOfActiveTasks == 0 {
                self._complete()
            }
            return
        }
        
        currentTask = task
        
        let executeTask = {
            task!(self.maximumNumberOfActiveTasks>1 ? nil: result) { (nextResult: AnyObject?) in
                self.numberOfActiveTasks--
                self._runNextTask(result: nextResult)
            }
        }

        if maximumNumberOfActiveTasks>1 {
            //parallel queue
            _delay(seconds: 0.001) {
                self._runNextTask(result: nil)
            }
            _delay(seconds: 0, completion: executeTask)
        } else {
            //serial queue
            executeTask()
        }
    }
    
    private func _complete() {
        paused = false
        running = false
        
        if hasCompletions {
            //synchronized remove completions
            objc_sync_enter(self)
            while completions.count > 0 {
                (completions.removeAtIndex(0) as ClosureNoResultNext)()
            }
            objc_sync_exit(self)
        }
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
    var count: Int {
        return tasks.count
    }
    
    //
    // re-run the current task
    //
    func retry(delay: Double = 0) {
        assert(maximumNumberOfActiveTasks==1, "You can call retry() only on serial queues")
        
        tasks.insert(currentTask!, atIndex: 0)
        currentTask = nil
        
        self._delay(seconds: delay) {
            self.numberOfActiveTasks--
            self._runNextTask(result: self.lastResult)
        }
    }

    //
    // Provide description when printed
    //
    var description: String {
        let state = running ? "runing " : (paused ? "paused ": "stopped")
            let type = maximumNumberOfActiveTasks==1 ? "serial": "parallel"
            
            return "[TaskQueue] type=\(type) state=\(state) \(tasks.count) tasks"
    }

    deinit {
        //println("queue deinit")
    }
    
    private func _delay(#seconds:Double, completion:()->()) {
        let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64( Double(NSEC_PER_SEC) * seconds ))
        
        dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
            completion()
        }
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

// MARK: Adding sub-queues

//
// Add a queue to the task list
//
func += (inout tasks: [TaskQueue.ClosureWithResultNext], queue: TaskQueue) {
    tasks += [{
        _, next in
        queue.run {
            next(queue.lastResult)
        }
    }]
}

