Pod::Spec.new do |s|
  s.name             = "TaskQueue"
  s.version          = "1.1.1"
  s.summary          = "Task management made easy, bounce tasks between main thread and background threads like a pro"
  s.description      = <<-DESC
	TaskQueue is a Swift library which allows you to schedule tasks once and then let the queue execute them in a synchronous matter. The great thing about TaskQueue is that you get to decide on which GCD queue each of your tasks should execute beforehand and leave TaskQueue to do switching of queues as it goes.

	Even if your tasks are asynchronous like fetching location, downloading files, etc. TaskQueue will wait until they are finished before going on with the next task.
                       DESC
  s.homepage         = "https://github.com/icanzilb/TaskQueue"
  s.screenshots      = "https://raw.githubusercontent.com/icanzilb/TaskQueue/master/etc/readme_schema.png"
  s.license          = 'MIT'
  s.author           = { "Marin Todorov" => "touch-code-magazine@underplot.com" }
  s.source           = { :git => "https://github.com/icanzilb/TaskQueue.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/icanzilb'

  s.requires_arc = true

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'

  s.source_files = 'Sources/*.swift'
end
