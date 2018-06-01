require 'open3'
require 'date'
require 'pry'

class Rbcron
  CRON_FORMAT = "%M %k %e %m %w".freeze
  CRON_MATCH_REGEX = /^[[\*\/\d]|[\d]]+{1,2}\s[[\*\/\d]|[\d]]+{1,2}\s[[\*\/\d]|[\d]]+{1,2}\s[[\*\/\d]|[\d]]+{1,2}\s[[\*\/\d]|[\d]]+{1,2}/

  def initialize(schedule_file = nil)
    @now = nil
    @cron_time = nil
    @schedule = schedule(schedule_file)
    @threads = []
    start_message
    start
  end

  private

  def start_message
    puts "rbcron started"
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

      @threads.each do |thread|
        next unless thread[:status]
        puts @now
        if thread[:status].success?
          puts thread[:stdout]
        else
          puts thread[:stderr]
        end
        @threads.delete(thread)
      end

      next if @cron_time == formatted_now

      @cron_time = formatted_now

      scheduled_jobs.each { |job| run(job) }
    end
  end

  def run(job)
    @threads << Thread.new do
      stdout,stderr,status = Open3.capture3(job)
      Thread.current[:stdout] = stdout
      Thread.current[:stderr] = stderr
      Thread.current[:status] = status
    end
  end

  def scheduled_jobs
    @schedule.map do |job|
      next unless format_schedule(job_time(job)) == @cron_time

      # extract the command to run
      job.gsub(extract_job_schedule(job), "").strip
    end.compact
  end

  def extract_job_schedule(job)
    job.match(CRON_MATCH_REGEX).to_s
  end

  # replaces wildcards (*) with the actual time & date values
  def job_time(job)
    extract_job_schedule(job).split.each_with_index.map do |value, index|
      cron_time_value = @cron_time.split[index]

      if value == "*"
        cron_time_value
      elsif value.match(/\*\/\d{1,2}/)
        increment = value.match(/\*\/\d{1,2}/).to_s[2..-1].to_i

        case index
        when 0, 1
          increment_value(:time, cron_time_value, increment)
        when 2
          increment_value(:day_of_month, cron_time_value, increment)
        when 3
          increment_value(:month, cron_time_value, increment)
        when 4
          increment_value(:day_of_week, cron_time_value, increment)
        end
      else
        value
      end
    end.join(" ")
  end

  def increment_value(type, cron_time_value, increment)
    if Multiples.send(type, increment).include?(cron_time_value.to_i)
      cron_time_value
    else
      increment
    end
  end

  def format_schedule(schedule)
    schedule.split.map{ |n| "%02d" % n.to_i }.join(" ")
  end

  def formatted_now
    format_schedule(@now.strftime(CRON_FORMAT))
  end
end

class Multiples
  def self.multiples(max, n)
    (1..(max/n)).to_a.map { |i| (i * n) }
  end

  def self.time(n)
    multiples(60, n)
  end

  def self.day_of_month(n)
    date = Date.new
    days_in_month = Date.new(date.year, date.month, -1).day
    multiples(days_in_month, n)
  end

  def self.month(n)
    multiples(12, n)
  end

  def self.day_of_week(n)
    multiples(7, n)
  end
end

begin 
  Rbcron.new(ARGV[0])
rescue Exception => e
  puts "\nrbcron has ended #{Time.now}.\n#{e}"
end
