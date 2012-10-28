#!/usr/bin/env ruby
#cid garbage collection - deletes all expired galleries
#you should configure a cron job to run this script daily
require './main'
require 'fileutils'

#get all gallery directories with expiration date
gs = Dir.entries(BASEDIR)-['.','..']
gs.delete_if{|g| !File.exists?(BASEDIR+g+'/.expires')}

#EXTERMINAAAATE!!
gs.each do |id|
  time = Time.at(File.readlines(BASEDIR+id+'/.expires')[0].chomp.to_i)
  FileUtils.rm_rf(BASEDIR+id) if Time.now>time
end
