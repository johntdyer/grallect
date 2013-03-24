#!/usr/bin/env ruby


require 'json'
require 'logger'
require 'open-uri'
require 'pp'
require 'uri'

class Grallect

  def initialize(host)
    # this should be generated by merging together defaults and a configuration file
    @config = { 
      :graphite => { :url => 'http://localhost' },
      :collectd => { :prefix => "collectd", :postfix => nil, :escape_character => '_', :interval => 10 },
      :cpu => { :count => 2, :warning => 80, :critical => 95, :window => 60 },
      :verbose => true,
    }

    @config[:host] = host.gsub!('.', @config[:collectd][:escape_character])

    @logger = Logger.new(STDERR)
    @logger.level = @config[:verbose] ? Logger::DEBUG : Logger::ERROR
  end

  def check_cpu()
    results = []
    code = nil

    range = (0..@config[:cpu][:count]-1)

    # number of data points to average together
    samples = @config[:cpu][:window] / @config[:collectd][:interval]

    # Checking each cpu individually
    range.each do |i|

      # for each data point, add together the user and system time, then get an average of the data points
      url = URI.escape("#{@config[:graphite][:url]}/render/?format=json&target=movingAverage(sumSeries(#{@config[:host]}.collectd.cpu-#{i}.cpu-{user,system}),#{samples})&from=-#{@config[:cpu][:window]}seconds")
      @logger.debug URI.unescape(url)

      begin
        response = open(url).read
        @logger.debug response
      rescue SocketError => e
        @logger.fatal e.message
        exit 1
      end

      begin
        data = JSON.parse(response)
      rescue ParserError => e
        @logger.fatal e.message
        exit 1
      end

      if data.empty?
        @logger.warn "No data found at #{url}"
      else
        value = data.first['datapoints'].last.first
        results.push value
        if value >= @config[:cpu][:warning] and value < @config[:cpu][:critical]
          code = 1
        elsif value >= @config[:cpu][:critical]
          code = 2
        else
          code = 0
        end
      end

    end

    case code
    when 0
      output = 'OK: '
    when 1
      output = 'WARNING: '
    when 2
      output = 'CRITICAL: '
    else
      code = 3
      output = 'UNKNOWN: No data was found'
    end

    results.each_with_index { |value,index| output = output + "CPU #{index} averaged #{value}%. " }

    puts output
    return code
  end

end

# this should be generated by command line arguments
command = 'cpu'
host = 'example.com'

g = Grallect.new(host)

case command
when 'cpu'
  g.check_cpu
else
  puts 'What kind of command is that?'
end
