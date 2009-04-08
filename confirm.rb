# -*- coding: utf-8 -*-

Termtter::Client.register_hook(
  :name => :confirm,
  :points => [:pre_exec_update],
  :exec_proc => lambda {|cmd, arg|
    puts %["#{arg}" (#{arg.split(//u).size})]
    if /^y?$/i !~ Readline.readline("update? [Y/n] ", false)
      puts 'canceled.'
      raise Termtter::CommandCanceled
    end
  }
)
