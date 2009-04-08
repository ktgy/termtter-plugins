# -*- coding: utf-8 -*-

require 'net/http'

config.plugins.tweetburner.set_default(:length_to_shorten, '40')
config.plugins.tweetburner.set_default(:open_timeout, '4')
config.plugins.tweetburner.set_default(:read_timeout, '6')
length_to_shorten = config.plugins.tweetburner.length_to_shorten.to_i
open_timeout = config.plugins.tweetburner.open_timeout.to_i
read_timeout = config.plugins.tweetburner.read_timeout.to_i

Termtter::Client.register_hook(
  :name => :tweetburner,
  :points => [:modify_arg_for_update],
  :exec_proc => lambda {|cmd, arg|
    long_url = []
    arg.gsub(URI.regexp) {|uri|
      long_url.push(uri) unless uri.size < length_to_shorten || /^http:\/\/twurl\.nl\// =~ uri
    }
    return arg if long_url.empty?

    Net::HTTP.version_1_2
    http = Net::HTTP.new('tweetburner.com')
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout
    begin
      http.start do
        long_url.each {|longurl|
          response = http.post('/links', "link[url]=#{longurl}")
          if response.code == '200'
            arg.sub!(longurl, response.body)
          else
            puts "Tweetburner error : #{response.code}"
          end
        }
      end
    rescue Timeout::Error
      puts 'Tweetburner access timeout'
    end
    arg
  }
)
#Optional setting.
#  config.plugins.tweetburner.length_to_shorten = '40'
