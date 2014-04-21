APP_ROOT = ENV['MM_ROOT']
God.pid_file_directory = APP_ROOT + "/.god"

%w{1337}.each do |port|
  God.watch do |w|
    w.dir = APP_ROOT
    w.log = APP_ROOT + "/.god/middleman.log"
    w.name = "middleman"

    w.interval = 30.seconds

    w.start = "middleman server --port=#{port} --verbose"
    w.stop = "killall -9 middleman"
    w.restart = "killall -9 middleman | middleman server --port=#{port} --verbose"

    w.behavior(:clean_pid_file)

    w.start_if do |start|
      start.condition(:process_running) do |c|
        c.interval = 5.seconds
        c.running = false
      end
    end

    w.restart_if do |restart|
      restart.condition(:memory_usage) do |c|
        c.above = 150.megabytes
        c.times = [3, 5] # 3 out of 5 intervals
      end

      restart.condition(:cpu_usage) do |c|
        c.above = 50.percent
        c.times = 5
      end
    end

    # lifecycle
    w.lifecycle do |on|
      on.condition(:flapping) do |c|
        c.to_state = [:start, :restart]
        c.times = 5
        c.within = 5.minute
        c.transition = :unmonitored
        c.retry_in = 10.minutes
        c.retry_times = 5
        c.retry_within = 2.hours
      end
    end
  end
end
