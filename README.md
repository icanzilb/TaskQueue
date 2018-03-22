# TaskQueue

[![Platform](https://img.shields.io/cocoapods/p/TaskQueue.svg?style=flat)](http://cocoadocs.org/docsets/TaskQueue)
[![Cocoapods Compatible](https://img.shields.io/cocoapods/v/TaskQueue.svg)](https://img.shields.io/cocoapods/v/TaskQueue.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/icanzilb/TaskQueue/master/LICENSE.md)


## Table of Contents

* [Intro](#intro)
* [Installation](#installation)
  * [CocoaPods](#cocoapods)
  * [Carthage](#carthage)
* [Simple Examples](#simple-examples)
  * [Synchronous tasks](#synchronous-tasks)
  * [Asynchronous tasks](#asynchronous-tasks)
* [Serial and Concurrent Tasks](#serial-and-concurrent-tasks)
* [GCD Queue Control](#gcd-queue-control)
* [Extensive Example](#extensive-example)
* [Credit](#credit)
* [License](#license)


## Intro

![title](https://raw.githubusercontent.com/icanzilb/TaskQueue/master/etc/readme_schema.png)

TaskQueue is a Swift library which allows you to schedule tasks once and then let the queue execute them in a synchronous manner. The great thing about TaskQueue is that you get to decide on which GCD queue each of your tasks should execute beforehand and leave TaskQueue to do switching of the queues as it goes.

Even if your tasks are asynchronious like fetching location, downloading files, etc. TaskQueue will wait until they are finished before going on with the next task.

Last but not least your tasks have full flow control over the queue, depending on the outcome of the work you are doing in your tasks you can skip the next task, abort the queue, or jump ahead to the queue completion. You can further pause, resume, and stop the queue.


## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects.

If you don't already have the Cocoapods gem installed, run the following command:

```bash
$ gem install cocoapods
```

To integrate TaskQueue into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'TaskQueue'
```

Then, run the following command:

```bash
$ pod install
```

If you find that you're not having the most recent version installed when you run `pod install` then try running:

```bash
$ pod cache clean
$ pod repo update TaskQueue
$ pod install
```

Also you'll need to make sure that you've not got the version of TaskQueue locked to an old version in your `Podfile.lock` file.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that automates the process of adding frameworks to your Cocoa application.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate TaskQueue into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "icanzilb/TaskQueue"
```

## Simple Example

### Synchronous tasks

Here's the simplest way to use TaskQueue in Swift:

```swift
let queue = TaskQueue()

queue.tasks +=~ {
	... time consuming task on a background queue...
}

queue.tasks +=! {
	... update UI on main queue ...
}

queue.run()
```

TaskQueue will execute the tasks one after the other waiting for each task to finish and the will execute the next one. By using the operators `+=~` and `+=!` you can easily set whether the task should execute in background or on the main queue.

### Asynchronous tasks

More interesting of course is when you have to do some asynchronous work in the background of your tasks. Then you can fetch the `next` parameter in your task and call it whenever your async work is done:

```swift
let queue = TaskQueue()

queue.tasks +=~ { result, next in

    var url = URL(string: "http://jsonmodel.com")

    URLSession.shared.dataTask(with: url,
        completionHandler: { _, _, _ in
            // process the response
            next(nil)
        })
}

queue.tasks +=! {
    print("execute next task after network call is finished")
}

queue.run {
    print("finished")
}
```

There are a few things to highlight in the example above:

1. The first task closure gets two parameters: `result` is the result from the previous task (`nil` in the case of the first task) and `next`. `next` is a closure you need to call whenver your async task has finished executing.

2. Task nr.2 doesn't get started until you call `next()` in your previous task.

3. The `run` function can also take a closure as a parameter - if you pass one it will always get executed after all other tasks has finished.


## Serial and Concurrent Tasks

By default TaskQueue executes its tasks one after another or, in other words, the queue has up to one active task at a time.

You can, however, allow a given number of tasks to execute at the same time (e.g. if you need to download a number of image files from web). To do this just increase the number of active tasks and the queue will automatically start executing tasks concurrently. For example:

```swift
queue.maximumNumberOfActiveTasks = 10
```

This will make the queue execute up to 10 tasks at the same time.

**Note**: _As soon as you allow for more than one task at a time certain restrictions apply: you cannot invoke retry(), and you cannot pass a result from one task to another._

## GCD Queue Control

Do you want to run couple of heavy duty tasks in the background and then switch to the main queue to update your app UI? Easy. Study the example below, which showcases GCD queue control with **TaskQueue**:

```swift
let queue = TaskQueue()

//
// "+=" adds a task to be executed on the current queue
//
queue.tasks += {
    // update the UI
}

//
// "+=~" adds a task to be executed in the background, e.g. low prio queue
// "~" stands for so~so priority
//
queue.tasks +=~ {
    // do heavy work
}

//
// "+=!" adds a task to be executed on the main queue
// "!" stands for High! priority
//
queue.tasks +=! {
    // update the UI again
}

// to start the queue on the current GCD queue
queue.run()
```

## Extensive example

```swift
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
queue.tasks += { [weak queue] result, next in
    print("task #3: try #\(cnt)")
    cnt += 1

    if cnt > 3 {
        next(nil)
    } else {
        queue!.retry(delay: 1)
    }
}

//
// This task skips the next task in queue
// (no capture cycle here)
//
queue.tasks += {
    print("task #4: run")
    print("task #4: will skip next task")

    queue.skip()
}

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
    queue.run { _ in
        print("completion: appended completion run")
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
queue.run { result in
    print("====== completions ======")
    print("initial completion: run")
}
```

Run the included demo app to see some of these examples above in action.


## Credit

Author: **Marin Todorov**

* [https://github.com/icanzilb](https://github.com/icanzilb)
* [https://twitter.com/icanzilb](https://twitter.com/icanzilb)
* [http://www.touch-code-magazine.com/about/](http://www.touch-code-magazine.com/about/)

## License

TaskQueue is available under the MIT license. See the LICENSE file for more info.
