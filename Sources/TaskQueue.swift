//
// TaskQueue.swift
//
// Copyright (c) 2014-2016 Marin Todorov, Underplot ltd.
// This code is distributed under the terms and conditions of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// This class is inspired by Sequencer (objc) https://github.com/berzniz/Sequencer
// but aims to implement 1) flow control, 2) swift code, 3) control of GDC queues, 4) concurrency
//

import Foundation

// MARK: TaskQueue class

open class TaskQueue: CustomStringConvertible {

    //
    // types used by the TaskQueue
    //
    public typealias ClosureNoResultNext = () -> Void
    public typealias ClosureWithResultNext = (Any? , @escaping (Any?) -> Void) -> Void

    //
    // tasks and completions storage
    //
    open var tasks = [ClosureWithResultNext]()
    open lazy var completions = [ClosureNoResultNext]()

    //
    // concurrency
    //
    public fileprivate(set) var numberOfActiveTasks = 0
    open var maximumNumberOfActiveTasks = 1 {
        willSet {
            assert(maximumNumberOfActiveTasks > 0, "Setting less than 1 task at a time not allowed")
        }
    }

    fileprivate var currentTask: ClosureWithResultNext? = nil
    fileprivate(set) var lastResult: Any! = nil

    //
    // queue state
    //
    fileprivate(set) var running = false

    open var paused: Bool = false {
        didSet {
            running = !paused
        }
    }

    fileprivate var cancelled = false
    open func cancel() {
        cancelled = true
    }

    fileprivate var hasCompletions = false

    //
    // start or resume the queue
    //
    public init() {}
    
    open func run(_ completion: ClosureNoResultNext? = nil) {
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

    fileprivate func _runNextTask(_ result: Any? = nil) {
        if (cancelled) {
            tasks.removeAll(keepingCapacity: false)
            completions.removeAll(keepingCapacity: false)
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
        if tasks.count > 0 {
            task = tasks.remove(at: 0)
            numberOfActiveTasks += 1
        }
        objc_sync_exit(self)

        if task == nil {
            if numberOfActiveTasks == 0 {
                _complete()
            }
            return
        }

        currentTask = task

        let executeTask = {
            task!(self.maximumNumberOfActiveTasks > 1 ? nil : result) { nextResult in
                self.numberOfActiveTasks -= 1
                self._runNextTask(nextResult)
            }
        }

        if maximumNumberOfActiveTasks > 1 {
            //parallel queue
            _delay(seconds: 0.001) {
                self._runNextTask(nil)
            }
            _delay(seconds: 0, completion: executeTask)
        } else {
            //serial queue
            executeTask()
        }
    }

    fileprivate func _complete() {
        paused = false
        running = false

        if hasCompletions {
            //synchronized remove completions
            objc_sync_enter(self)
            while completions.count > 0 {
                completions.remove(at: 0)()
            }
            objc_sync_exit(self)
        }
    }

    //
    // skip the next task
    //
    open func skip() {
        if tasks.count > 0 {
            _ = tasks.remove(at: 0)
        }
    }

    //
    // remove all remaining tasks
    //
    open func removeAll() {
        tasks.removeAll(keepingCapacity: false)
    }

    //
    // count of the tasks left to execute
    //
    open var count: Int {
        return tasks.count
    }

    //
    // pause and reset the current task
    //
    open func pauseAndResetCurrentTask() {
        paused = true

        tasks.insert(currentTask!, at: 0)
        currentTask = nil
        self.numberOfActiveTasks -= 1
    }

    //
    // re-run the current task
    //
    open func retry(_ delay: Double = 0) {
        assert(maximumNumberOfActiveTasks == 1, "You can call retry() only on serial queues")

        tasks.insert(currentTask!, at: 0)
        currentTask = nil

        _delay(seconds: delay) {
            self.numberOfActiveTasks -= 1
            self._runNextTask(self.lastResult)
        }
    }

    //
    // Provide description when printed
    //
    open var description: String {
        let state = running ? "runing " : (paused ? "paused ": "stopped")
            let type = maximumNumberOfActiveTasks==1 ? "serial": "parallel"

            return "[TaskQueue] type=\(type) state=\(state) \(tasks.count) tasks"
    }

    deinit {
        // print("queue deinit")
    }

    fileprivate func _delay(seconds:Double, completion:@escaping ()->()) {
        let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * seconds )) / Double(NSEC_PER_SEC)

        DispatchQueue.global(qos: .background).asyncAfter(deadline: popTime) { 
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

infix operator  +=~
infix operator  +=!

// MARK: Add tasks on the current queue

//
// Add a task closure with result and next params
//
public func += (tasks: inout [TaskQueue.ClosureWithResultNext], task: @escaping TaskQueue.ClosureWithResultNext) {
    tasks += [task]
}

//
// Add a task closure that doesn't take result/next params
//
public func += (tasks: inout [TaskQueue.ClosureWithResultNext], task: @escaping TaskQueue.ClosureNoResultNext) {
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
public func +=~ (tasks: inout [TaskQueue.ClosureWithResultNext], task: @escaping TaskQueue.ClosureNoResultNext) {
    tasks += [{
        _, next in
        DispatchQueue.global(qos: .background).async {
            task()
            next(nil)
        }
    }]
}

//
// The task gets executed on a low prio queueu
//
public func +=~ (tasks: inout [TaskQueue.ClosureWithResultNext], task: @escaping TaskQueue.ClosureWithResultNext) {
    tasks += [{
        result, next in
        
        DispatchQueue.global(qos: .utility).async {
            task(result, next)
        }
    }]
}

// MARK: Add tasks on the main queue

//
// Add a task closure that doesn't take result/next params
// The task gets executed on the main queue - update UI, etc.
//
public func +=! (tasks: inout [TaskQueue.ClosureWithResultNext], task: @escaping TaskQueue.ClosureNoResultNext) {
    tasks += [{
        _, next in
        DispatchQueue.main.async {
            task()
            next(nil)
        }
        
    }]
}

//
// The task gets executed on the main queue - update UI, etc.
//
public func +=! (tasks: inout [TaskQueue.ClosureWithResultNext], task: @escaping TaskQueue.ClosureWithResultNext) {
    tasks += [{
        result, next in
        DispatchQueue.main.async {
            task(result, next)
        }
    }]
}

// MARK: Adding sub-queues

//
// Add a queue to the task list
//
public func += (tasks: inout [TaskQueue.ClosureWithResultNext], queue: TaskQueue) {
    tasks += [{
        _, next in
        queue.run {
            next(queue.lastResult)
        }
    }]
}
