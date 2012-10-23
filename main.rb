#!/usr/bin/env ruby
#cid - cute image database
#Copyright (C) 2012 Anton Pirogov
#Licensed under the GPLv3

require 'sinatra'
require 'haml'
require 'RMagick'

#initialization

PICDIR='data/'
SIZES=[[100,75],[150,112],[320,240], \
       [640,480],[800,600],[1024,768], \
       [1366,768],[1440,900],[1280,1024], \
       [1600,1200],[1900,1200]]

Dir.mkdir(PICDIR) if !File.exists?(PICDIR)
File.write('nextid','0') if !File.exists?('nextid')

#helper functions

#get next pic id and increase counter
def nextid
  id = File.readlines('nextid')[0]
  File.write('nextid',"#{id.to_i+1}")
  return id
end

#get password for image
def getpwd(picid)
  File.readlines(PICDIR+picid)[0]
end

#generate random password
def genpwd
  8.times.map{Random.rand(16)}.map{|n| n.to_s(16)}.join
end

#return image binary data
def image(path)
    img = Magick::Image.read(path)[0]
    img.to_blob
end

#save image + thumbnail + password
#input: data=image blob, size=size option index
def saveimg(data, size)
  id = nextid

  #resize if neccessary
  if size!=0
    tmp = Magick::Image.from_blob(data)[0]
    tmp.format = 'JPG'
    data = tmp.adaptive_resize(SIZES[size-1][0],SIZES[size-1][1]).to_blob
  end

  #create thumbnail (shrink if neccessary)
  thumb = data
  pic = Magick::Image.from_blob(data)[0]
  scale = 320.to_f/[pic.columns, pic.rows].max.to_f
  thumb = pic.thumbnail(scale).to_blob if scale<1

  #write files
  File.write(PICDIR+id, genpwd)
  File.write(PICDIR+id+'.jpg', data)
  File.write(PICDIR+id+'_thumb.jpg', thumb)

  return id
end

#delete an image with given id
#using the password for verification
def delimg(id, pwd)
  return false if pwd != getpwd(id)

  #delete files
  File.delete(PICDIR+id)
  File.delete(PICDIR+id+'.jpg')
  File.delete(PICDIR+id+'_thumb.jpg')
  return true
rescue
  return false #error occured - probably file does not exist
end

#routes

get '/' do
  haml :index
end

#upload response
post '/upload' do
  pic = params[:image][:tempfile].read
  size = params[:size].to_i

  @id = saveimg pic, size
  @showlink = url("/show/#{@id}")
  @dellink = url("/delete/#{@id}/#{getpwd(@id)}")
  haml :upload
end

#image links
get '/:action/:id' do
  if File.exists?(PICDIR+params[:id])
    case params[:action]
    when 'img'    #raw image
      content_type 'image/jpg'
      filepath = PICDIR+params[:id]+'.jpg'
      image filepath
    when 'thumb'  #thumbnail
      content_type 'image/jpg'
      filepath = PICDIR+params[:id]+'_thumb.jpg'
      image filepath
    when 'show'   #the image page
      @id = params[:id]
      haml :show

    else
      @msg='No such action!'
      haml :error
    end
  else
    @msg='This image does not exist!'
    haml :error
  end
end

#delete link
get '/delete/:id/:pwd' do
  success = delimg params[:id], params[:pwd]
  if success
    haml :delsuccess
  else
    @msg='Wrong password or file does not exist!'
    haml :error
  end
end
