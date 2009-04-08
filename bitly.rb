# -*- coding: utf-8 -*-

require 'uri'
require 'open-uri'

config.plugins.bitly.set_default(:length_to_shorten, '40')

length_to_shorten = config.plugins.bitly.length_to_shorten.to_i
login = config.plugins.bitly.login
key = config.plugins.bitly.key
if login.empty? || key.empty?
  puts 'Need your "bit.ly login name" & "API Key"'
  puts 'please set config.plugins.bitly.login & config.plugins.bitly.key'
  puts 'your API Key is here => http://bit.ly/account/'
else
  Termtter::Client.register_hook(
    :name => :bitly,
    :points => [:modify_arg_for_update],
    :exec_proc => lambda {|cmd, arg|
      long_url = []
      arg.gsub(URI.regexp) {|uri|
        long_url.push(uri) unless uri.size < length_to_shorten || /^http:\/\/bit\.ly\// =~ uri
      }
      return arg if long_url.empty?

      api_query = "http://api.bit.ly/shorten?version=2.0.1&login=#{login}&apiKey=#{key}"
      long_url.each {|url| api_query += "&longUrl=#{url}"}

      begin
        response_json = open(api_query).read
      rescue OpenURI::HTTPError
        puts "bit.ly access error : #{$!}"
        return arg
      end

      if /"statusCode": "OK"/ =~ response_json
        long_url.each {|url|
          /#{Regexp.escape(url)}.*?"shortUrl": "(.*?)"/m =~ response_json
          arg.sub!(url, $1)
        }
      else
        /"errorMessage": "(.*?)"/ =~ response_json
        puts "bit.ly API error : #{$1}"
      end
      arg
    }
  )
end

#Necessary settings.
#  config.plugins.bitly.login = 'YOUR LOGIN NAME'
#  config.plugins.bitly.key = 'API KEY'
#Optional setting.
#  config.plugins.bitly.length_to_shorten = '30'
#
#Get API Key at http://bit.ly/account/
