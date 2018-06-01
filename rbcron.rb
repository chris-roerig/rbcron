require 'open3'

class Rbcron
  CRON_FORMAT = "%M %k %e %m %w".freeze

  def initialize(schedule_file = nil)
    @now = nil
    @cron_time = nil
    @schedule = schedule(schedule_file)
    start_message
    start
  end

  private

  def start_message
    puts "Rbcron started"
    puts "Loaded schedule:"
    puts @schedule.join("\n")
    puts ""
  end

  def schedule(schedule_file = nil)
    schedule_file ||= 'rbcrontab'
    File.readlines(schedule_file).map(&:strip)
  end

  def start
    loop do
      @now = Time.now
      next if @cron_time == @now.strftime(CRON_FORMAT)

      @cron_time = @now.strftime(CRON_FORMAT)

      jobs = @schedule.map do |job|
        next unless job_time(job) == @cron_time
        job.gsub(job_schedule(job), "").strip
      end

      jobs.compact.each do |job|
        puts @now
        stdout,stderr,status = Open3.capture3(job)
        if status.success?
          puts stdout
        else
          puts stderr
        end
      end
    end
  end

  def job_schedule(job)
    job.match(/^[\*\d]{1,2}\s[\*\d]{1,2}\s[\*\d]{1,2}\s[\*\d]{1,2}\s[\*\d]{1,2}/).to_s
  end

  def job_time(job)
    job_schedule(job).split.each_with_index.map do |i, n|
      if i == "*"
        @cron_time.split[n]
      else
        i
      end
    end.join(" ")
  end
end

begin 
  Rbcron.new(ARGV[0])
rescue Exception => e
  puts "\nRbcron has ended #{Time.now}.\n#{e}"
end
