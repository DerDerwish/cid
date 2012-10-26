#!/usr/bin/env ruby
#cid - cute image database
#Copyright (C) 2012 Anton Pirogov
#Licensed under the GPLv3

require 'sinatra'
require 'haml'

require './gallery'

#constants

BASEDIR='data/'
SIZES=[[100,75],[150,112],[320,240], \
       [640,480],[800,600],[1024,768], \
       [1366,768],[1440,900],[1280,1024], \
       [1600,1200],[1900,1200]]

#0 = no resize, >0 = resize to SIZES[-1]
def size_from_select(id)
  id = id.to_i
  return nil if id==0
  return SIZES[id-1]
end

#routes

#TODO: route to rename gallery and pictures

get '/' do
  haml :index
end

#upload response
post '/create' do
  pic = params[:image][:tempfile].read
  name = params[:image][:filename]
  size = size_from_select params[:size]

  #create gallery and add pictures
  g = Gallery.new
  g.add pic,name,size

  #user response
  @showlink = url("/show/#{g.id}")
  @password = g.password
  haml :upload
end

#gallery view page
get '/show/:id' do
  g = Gallery.open(params[:id])
  if !g
    @msg='This gallery does not exist!'
    halt haml(:error)
  end

  @g = g
  haml :show
end

#gallery edit page
get '/edit/:id/:pwd' do
  g = Gallery.open(params[:id])
  if !g
    @msg='Gallery does not exist!'
    halt haml(:error)
  end
  if params[:pwd]!=g.password
    @msg='Wrong password!'
    halt haml(:error)
  end

  @g = g
  haml :edit
end

#to be called from edit page
post '/edit/:id/:pwd' do
  #actions: prename(pid,name), grename(name), pdelete(pid), padd(image,name)
  g = Gallery.open(params[:id])
  if !g
    @msg='Gallery does not exist!'
    halt (haml :error)
  end
  if params[:pwd]!=g.password
      @msg='Wrong password!'
      halt haml(:error)
  end

  case params[:action]
  when 'title'
    if params[:val].nil?
      @msg='title: Value missing!'
      halt haml(:error)
    end
    g.title params[:val]

  when 'name'
    if params[:pic].nil? || params[:val].nil?
      @msg='name: Picture ID or value missing!'
      halt haml(:error)
    end
    g.setname params[:pic], params[:val]

  when 'delete'
    if params[:pic].nil?
      @msg='delete: Picture ID missing!'
      halt haml(:error)
    end
    g.delete params[:pic]

  when 'add'
    if params[:image].nil? || params[:val].nil? || params[:size].nil?
      @msg='add: image data, size or value missing!'
      halt haml(:error)
    end
    g.add params[:image][:tempfile].read, params[:image][:filename], size_from_select(params[:size])

  else
    @msg='Invalid edit command!'
    halt haml(:error)
  end

  #render page back
  @g = g
  haml :edit
end

#to be called from the edit page
get '/destroy/:id/:pwd' do
  g = Gallery.open(params[:id])
  if !g
    @msg='Gallery does not exist!'
    halt haml(:error)
  end
  if params[:pwd]!=g.password
    @msg='Wrong password!'
    haml :error
  end

  success = g.destroy
  @msg='Gallery successfully deleted!'
  haml :success
end

#direct links to image data files
get '/:type/:id/:pic' do
  g = Gallery.open(params[:id])
  if !g
    @msg='This gallery does not exist!'
    halt haml(:error)
  end

  case params[:type]
  when 'img'    #raw image
    content_type 'image/jpg'
    g.get(params[:pic])
  when 'thumb'  #thumbnail
    content_type 'image/jpg'
    g.get(params[:pic], true)
  else
    @msg='No such action!'
    haml :error
  end
end


