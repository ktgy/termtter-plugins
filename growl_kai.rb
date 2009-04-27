# -*- coding: utf-8 -*-

## Need install Kaizouban_Growl & HTMLView.growlStyle
## http://memogaki.soudesune.net/2chResView.html#rNavi6

require 'uri'
require 'fileutils'
require 'cgi'
require 'digest/md5'

begin
  require 'meow'
  growl = Meow.new('termtter (growl_kai)', 'update_friends_timeline')
rescue LoadError
  growl = nil
end

config.plugins.growl.set_default(:icon_cache_dir, "#{Termtter::CONF_DIR}/tmp/user_profile_images")
config.plugins.growl.set_default(:image_cache_dir, "#{Termtter::CONF_DIR}/tmp/cache_images")
config.plugins.growl.set_default(:growl_user, [])
config.plugins.growl.set_default(:growl_keyword, [])
config.plugins.growl.set_default(:sticky_user, [])
config.plugins.growl.set_default(:sticky_keyword, [])
growl_keys    = { 'user'    =>  config.plugins.growl.growl_user,
                  'keyword' =>  Regexp.union(config.plugins.growl.growl_keyword) }
sticky_keys   = { 'user'    =>  config.plugins.growl.sticky_user,
                  'keyword' =>  Regexp.union(config.plugins.growl.sticky_keyword) }

FileUtils.mkdir_p(config.plugins.growl.icon_cache_dir) unless File.exist?(config.plugins.growl.icon_cache_dir)
FileUtils.mkdir_p(config.plugins.growl.image_cache_dir) unless File.exist?(config.plugins.growl.image_cache_dir)
Dir.glob("#{config.plugins.growl.icon_cache_dir}/*") {|f| File.delete(f) unless File.size?(f) }
Dir.glob("#{config.plugins.growl.image_cache_dir}/*") {|f|
  File.delete(f) if File.atime(f) < (Time.now - 60*60*24)
}

def get_icon_path(s)
  /https?:\/\/.+\/(\d+)\/.*?$/ =~ s.user.profile_image_url
  cache_file = "%s/%s-%s%s" % [  config.plugins.growl.icon_cache_dir,
                                 s.user.screen_name,
                                 $+,
                                 File.extname(s.user.profile_image_url)  ]
  unless File.exist?(cache_file)
    unless File.exist?("#{config.plugins.growl.icon_cache_dir}/default.png")
      File.open("#{config.plugins.growl.icon_cache_dir}/default.png", 'wb') do |f|
        Termtter::API.connection.start('static.twitter.com', 80) do |http|
          f << http.get('/images/default_profile_normal.png').body
        end
      end
    end
    Dir.glob("#{config.plugins.growl.icon_cache_dir}/#{s.user.screen_name}-*") {|f| File.delete(f) }
    url = URI.parse(URI.escape(s.user.profile_image_url))
    begin
      File.open(cache_file, 'wb') do |f|
        Termtter::API.connection.start(url.host, url.port) do |http|
          f << http.get(url.path).body
        end
      end
    rescue
      File.delete(cache_file)
      cache_file = "#{config.plugins.growl.icon_cache_dir}/default.png"
    end
  end
  return cache_file
end

def is_growl(s,growl_keys)
  return true if (growl_keys['user'].empty? && growl_keys['keyword'] == /(?!)/) ||\
                 (growl_keys['user'].include?(s.user.screen_name) || growl_keys['keyword'] =~ s.text)
  return false
end

def is_sticky(s,sticky_keys)
  return true if sticky_keys['user'].include?(s.user.screen_name) || sticky_keys['keyword'] =~ s.text
  return false
end

def get_image(s)
  s.text.gsub(URI.regexp) {|uri|
    case uri
    when /^http:\/\/movapic.com\/pic\/(\w+)/
      image_url = "http://image.movapic.com/pic/s_#{$1}.jpeg"
    when /^http:\/\/f.hatena.ne.jp\/(([\w-])[\w-]+)\/((\d{8})\d+)/
      image_url = "http://img.f.hatena.ne.jp/images/fotolife/#{$2}/#{$1}/#{$4}/#{$3}_120.jpg"
    when /^http:\/\/twitpic.com\/(\w+)/
      begin
        Termtter::API.connection.start('twitpic.com', 80) do |http|
          image_url = http.head("/show/thumb/#{$1}")['Location']
        end
      rescue
        return nil
      end
    when /^http:\/\/www\.youtube\.com\/watch\?.*v=([\w-]+)/
      image_url = "http://img.youtube.com/vi/#{$1}/#{rand(3) + 1}.jpg"
    when /^http:\/\/www\.nicovideo\.jp\/watch\/((?:sm|nm|ca)\d+)/
      begin
        Termtter::API.connection.start('ext.nicovideo.jp', 80) do |http|
          image_url = /<thumbnail_url>(.*)<\/thumbnail_url>/.\
            match(http.get("/api/getthumbinfo/#{$1}").body).to_a[1]
        end
      rescue
        return nil
      end
    when /(jpg|jpeg|gif|png)$/
      image_url = uri
    end

    if image_url
      image_url = URI.parse(image_url)
      image_cache = "%s/%s%s" % [  config.plugins.growl.image_cache_dir,
                                   Digest::MD5.hexdigest(image_url.to_s),
                                   File.extname(image_url.path)  ]
      unless File.exist?(image_cache)
        begin
          File.open(image_cache, 'wb') do |f|
            Termtter::API.connection.start(image_url.host, image_url.port) do |http|
              f << http.get(image_url.request_uri).body
            end
          end
        rescue
          return nil
        end
      end
      return image_cache
    end
  }
  return nil
end

Termtter::Client.register_hook(
  :name => :growl,
  :points => [:output],
  :exec_proc => lambda {|statuses, event|
    return unless event == :update_friends_timeline
    Thread.start do
      statuses.each do |s|
        next unless is_growl(s,growl_keys)
        growl_title = s.user.screen_name
        growl_title += " (#{s.user.name})" unless s.user.screen_name == s.user.name
        growl_text = <<-"EOS"
        <img src="#{get_icon_path(s)}" height="48" width="48" style="float:left; margin-right:5px; margin-bottom:5px;">
        <div style="margin-bottom:5px;">#{s.text}</div>
        EOS
        if image = get_image(s)
          growl_text += %[<hr><img src="#{image}">]
        end
        growl_text += '<<<AppleScript>>>'
        s.text.gsub(URI.regexp) {|uri|
          growl_text += %[do shell script "open #{uri}"\n]
        }
        unless growl
          arg = ['growlnotify', growl_title, '-m', s.text, '-n', 'termtter (growl_kai)']
          arg.push('-s') if is_sticky(s,sticky_keys)
          system *arg
        else
          growl.notify(growl_title, growl_text, :sticky => is_sticky(s,sticky_keys))
        end
        sleep 0.3
      end
    end
  }
)
#Optional setting example.
#  Growl ON setting.
#    config.plugins.growl.growl_user    = ['p2pquake', 'jihou']
#    config.plugins.growl.growl_keyword = ['地震', /^@screen_name/]
#  Sticky setting.
#    config.plugins.growl.sticky_user    = ['screen_name']
#    config.plugins.growl.sticky_keyword = [/^@screen_name/, '#termtter']
