TaskQueue (Swift)
=========

#### ver 0.6

I've been using for a long time in my iOS projects a class called Sequencer which makes executing async processes in synchronious fashion very easy. Here's the source code of [Sequencer by berzniz](https://github.com/berzniz/Sequencer).

However Sequencer lacks any flow control features - i.e. if you would like to add a new tasks to the queue, skip a task, re-try a task (very important when dealing with network calls), etc.

That's why I wrote TaskQueue for Swift - it employees the Sequencer approach in a more flexible way allowing for greater control and more powerful task management.

Simple Example
========

#### Synchronious tasks

Here's the simplest way to use TaskQueue in Swift:

<pre lang="swift">
let queue = TaskQueue()

queue.tasks += {
	... time consuming task ...
}

queue.tasks += {
	... another time consuming task ...
}

queue.run()
</pre>

TaskQueue will execute the tasks one after the other waiting for each task to finish and the will execute the next one.

#### Asynchronious tasks

More interesting of course is when you have to do some asynchronious work in the background in your tasks. Then you can fetch the **next** parameter in your task and call it whenever your async work is done:

<pre lang="swift">
let queue = TaskQueue()

queue.tasks += { result, next in
    
    var url = NSURL(string: "http://jsonmodel.com")

    NSURLSession.sharedSession().dataTaskWithURL(url,
        completionHandler: {_,_,_ in
            //process the response
            next(nil)
        })
}

queue.tasks += { result, next in
    println("execute next task after network call is finished")
}

queue.run {result in
    println("finished")
}
</pre>

Few things to highlight in the example above:

1. The first task closure gets two parameters **result** is the result from the previous task (nil in the case of the first task of course) and **next**. **next** is a closure you need to call whenver your async task has finished executing

2. Task nr.2 doesn't get started until you call **next()** in your previous task

3. The **run** function can also take a closure as a parameter - if you pass one it will always get executed after all other tasks has finished.

Extensive example
========

<pre lang="swift">
let queue = TaskQueue()

//
// Simple sync task, just prints to console
//
queue.tasks += {
    self.logToTextView("====== tasks ======")
    self.logToTextView("task #1: run")
}

//
// A task, which can be asynchronious because it gets
// result and next params and can call next() when ready 
// with async work to tell the queue to continue running
//
queue.tasks += { result, next in
    self.logToTextView("task #2: begin")
    
    delay(seconds: 2) {
        self.logToTextView("task #2: end")
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
    self.logToTextView("task #3: try #\(cnt)")
    
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
    self.logToTextView("task #4: run")
    self.logToTextView("task #4: will skip next task")
    
    queue.skip()
    })

queue.tasks += {
    self.logToTextView("task #5: run")
}

//
// This task removes all remaining tasks in the queue
// i.e. util when an operation fails and the rest of the queueud
// tasks don't make sense anymore
// NB: This does not remove the completions added
//
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
    self.logToTextView("====== completions ======")
    self.logToTextView("initial completion: run")
}
</pre>

Run the included demo app to see some of these examples above in action.

Misc
========
Author: [Marin Todorov](http://www.touch-code-magazine.com/about/)

This code is distributed under the MIT license (included in the repository as LICENSE)

TODO: 1) tests coverage 2) more detailed description in README
