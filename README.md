TaskQueue (Swift)
=========

As of 1.0.1 TaskQueue is __Swift 3__, check the instructions at the bottom if you're using it via CocoaPods.

TaskQueue is now __Swift 2.0__. If you need Swift 1.2, checkout version [0.9.6](https://github.com/icanzilb/TaskQueue/releases/tag/0.9.6)

#### ver 0.9.8

Contents of this readme

* <a href="#intro">Intro</a>
* <a href="#simple">Sync and Async Tasks Example</a>
* <a href=“#parallel”>Serial and Concurrent Tasks </a>
* <a href="#gcd">GCD Queue Control</a>
* <a href="#extensive">Extensive Example</a>
* <a href="#credit">Credit</a>
* <a href="#license">License</a>
* <a href="#version">Version History</a>

<a name="intro"></a>
Intro
========

![title](https://raw.githubusercontent.com/icanzilb/TaskQueue/master/etc/readme_schema.png)

TaskQueue is a Swift library which allows you to schedule tasks once and then let the queue execute them in a synchronious matter. The great thing about TaskQueue is that you get to decide on which GCD queue each of your tasks should execute beforehand and leave TaskQueue to do switching of queues as it goes.

Even if your tasks are asynchronious like fetching location, downloading files, etc. TaskQueue will wait until they are finished before going on with the next task.

Last but not least your tasks have full flow control over the queue, depending on the outcome of the work you are doing in your tasks you can skip the next task, abort the queue, or jump ahead to the queue completion. You can further pause, resume, and stop the queue.



Installation
========

Include either as source code or through CocoaPods.

Since TaskQueue is a swift3 library, you got to add this piece of code to your project's Podfile, to update your targets' swift language version:

```
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
            config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
        end
    end
end
```

---
<a name="simple"></a>

Simple Example
========

#### Synchronious tasks

Here's the simplest way to use TaskQueue in Swift:

<pre lang="swift">
let queue = TaskQueue()

queue.tasks +=~ {
	... time consuming task on a background queue...
}

queue.tasks +=! {
	... update UI on main queue ...
}

queue.run()
</pre>

TaskQueue will execute the tasks one after the other waiting for each task to finish and the will execute the next one. By using the operators <code>+=~</code> and <code>+=!</code> you can easily set whether the task should execute in background or on the main queue.

#### Asynchronious tasks

More interesting of course is when you have to do some asynchronious work in the background in your tasks. Then you can fetch the **next** parameter in your task and call it whenever your async work is done:

<pre lang="swift">
let queue = TaskQueue()

queue.tasks +=~ { result, next in
    
    var url = NSURL(string: "http://jsonmodel.com")

    NSURLSession.sharedSession().dataTaskWithURL(url,
        completionHandler: {_,_,_ in
            //process the response
            next(nil)
        })
}

queue.tasks +=! {
    print("execute next task after network call is finished")
}

queue.run {
    print("finished")
}
</pre>

Few things to highlight in the example above:

1. The first task closure gets two parameters **result** is the result from the previous task (nil in the case of the first task of course) and **next**. **next** is a closure you need to call whenver your async task has finished executing

2. Task nr.2 doesn't get started until you call **next()** in your previous task

3. The **run** function can also take a closure as a parameter - if you pass one it will always get executed after all other tasks has finished.

<a name="parallel"></a>
Serial and Concurrent Tasks
========

By default TaskQueue executes its tasks one after another or in other words the queue has up to one active task at a time.

You can however prefer for a number of tasks to execute at the same time (e.g. if you need to download a number of image files from web). To do this just increase the number of active tasks and the queue will automatically start executing tasks concurrently. For example:

<pre lang=“swift”>
queue.maximumNumberOfActiveTasks = 10
</pre>

This will make the queue execute up to 10 tasks at the same time.

**Note**: _As soon as you allow for more than one task at a time certain restrictions apply: you cannot invoke retry(), and you cannot pass result from one task to another._ 

<a name="gcd"></a>
GCD Queue control
========

Do you want to run couple of heavy duty tasks in the background and then switch to the main queue to update your app UI? Easy. Study the example below, which showcases GCD queue control with **TaskQueue**:

<pre lang="swift">
let queue = TaskQueue()

//
// "+=" adds a task to be executed on the current queue
//
queue.tasks += {
    //Update the App UI
}

//
// "+=~" adds a task to be executed in the background, e.g. low prio queue
// "~" stands for so~so priority
//
queue.tasks +=~ {
    //do heavy work
}

//
// "+=!" adds a task to be executed on the main queue
// "!" stands for High! priority
//
queue.tasks +=! {
    //update the UI again
}

// to start the queue on the current GCD queue
queue.run()

</pre>

<a name="extensive"></a>
Extensive example
========

<pre lang="swift">
let queue = TaskQueue()

//
// Simple sync task, just prints to console
//
queue.tasks += {
    print("====== tasks ======")
    print("task #1: run")
}

//
// A task, which can be asynchronious because it gets
// result and next params and can call next() when ready 
// with async work to tell the queue to continue running
//
queue.tasks += { result, next in
    print("task #2: begin")
    
    delay(seconds: 2) {
        print("task #2: end")
        next(nil)
    }
    
}

//
// A task which retries the same task over and over again
// until it succeeds (i.e. util when you make network calls)
// NB! Important to capture **queue** as weak to prevent 
// memory leaks!
//
var cnt = 1
queue.tasks += {[weak queue] result, next in
    print("task #3: try #\(cnt)")
    
    if ++cnt > 3 {
        next(nil)
    } else {
        queue!.retry(delay: 1)
    }
}

//
// This task skips the next task in queue
// (no capture cycle here)
//
queue.tasks += ({
    print("task #4: run")
    print("task #4: will skip next task")
    
    queue.skip()
    })

queue.tasks += {
    print("task #5: run")
}

//
// This task removes all remaining tasks in the queue
// i.e. util when an operation fails and the rest of the queueud
// tasks don't make sense anymore
// NB: This does not remove the completions added
//
queue.tasks += {
    print("task #6: run")
    
    print("task #6: will append one more completion")
    queue.run {
        _ in print("completion: appended completion run")
    }
    
    print("task #6: will skip all remaining tasks")
    queue.removeAll()
}

queue.tasks += {
    print("task #7: run")
}

//
// This either runs or resumes the queue
// If queue is running doesn't do anything
//
queue.run()

//
// This either runs or resumes the queue
// and adds the given closure to the lists of completions.
// You can add as many completions as you want (also half way)
// trough executing the queue.
//
queue.run {result in
    print("====== completions ======")
    print("initial completion: run")
}
</pre>

Run the included demo app to see some of these examples above in action.

<a name="credit"></a>

Credit
========

Author: **Marin Todorov**

* [https://github.com/icanzilb](https://github.com/icanzilb)
* [https://twitter.com/icanzilb](https://twitter.com/icanzilb)
* [http://www.touch-code-magazine.com/about/](http://www.touch-code-magazine.com/about/)

<a name="license"></a> 
License
========
TaskQueue is available under the MIT license. See the LICENSE file for more info.

<a name="version"></a>
Version History
========

**0.9.9:** Xcode 7.3, Swift 2.2., Carthage support

**0.9.8:** TaskQueue is now Swift 2.0

**0.9.1:** Bug fix

**New in 0.9:** <code>TaskQueue</code> allows for concurrent tasks now via the <code>maximumNumberOfActiveTasks</code> property. If it's one the class behaves as a serial queue, if greater then the class becomes a concurrent queue. Check <code>numberOfActiveTasks</code> to see how many tasks run currently.

<code>stop()</code> and <code>pause()</code> are removed - use the paused property and the cancel() method instead.

NB: The completion blocks do not take a parameter anymore, use the <code>lastResult</code> property if you need to check the result of the last task.

Added access restrictions and readonly properties.

**New in 0.8.2:** iOS8 beta 6 compatible, adding subqueues directly to <code>tasks</code>

**New in 0.8:** iOS8 beta 5 compatible, syntax remains unchanged but run(TaskQueueGDC, completion) is removed as it is redundant.
 
**New in 0.7:** GCD queue control - you can select on which GCD queue each of the tasks in the TaskQueue should run. Read about TaskQueue and GCD in the [GCD section below](https://github.com/icanzilb/TaskQueue#gcd-queue-control).
