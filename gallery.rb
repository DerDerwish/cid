# encoding: UTF-8
require 'fileutils'
require 'json'
require 'RMagick'

class Gallery
  #initialization stuff
  if defined? BASEDIR
    @@base = BASEDIR
  else
    @@base = 'data/'
  end
  Dir.mkdir(@@base) if !Dir.exists?(@@base)

  attr_reader :path, :id

  #open and return existing gallery
  def self.open(id)
    Gallery.new(id)
  rescue => ex
    print ex.backtrace.join("\n")
    nil
  end

  #open and return a random public gallery
  #count: at most N galleries
  #used for start page
  def self.open_random(count=1)
    g = galleries.shuffle
    ret = []
    g.each do |id|
      gal = Gallery.open id
      ret << gal if !gal.private
      break if ret.length == count
    end
    return ret
  end

  #create new or open existing gallery
  def initialize(id=nil)
    if id
      @id = id
      @path = @@base+id.to_s+'/'
      if !Dir.exists? @path
        raise "Gallery does not exist!"
      end
      readmeta
    else
      @id = genid
      @path = @@base+@id+'/'
      Dir.mkdir @path
      @meta = {'title' => "Gallery #{@id}", 'desc' => '', 'private' => false, 'password' => genchars(10), 'pics' => {}}
      savemeta
    end
    @exppath = @path+'.expires'
  end

  #get/set password for gallery
  def password(newpwd=nil)
    return @meta['password'] if !newpwd
    @meta['password'] = newpwd
    savemeta
  end

  #get/set title for gallery
  def title(newname=nil)
    return @meta['title'] if !newname
    @meta['title'] = newname
    savemeta
  end

  #get/set description for gallery
  def desc(newtext=nil)
    return @meta['desc'] if !newtext
    @meta['desc'] = newtext
    savemeta
  end

  #get/set visibility for gallery
  #new value = "": false "something": true
  def private(new=nil)
    return @meta['private'] if new==nil
    @meta['private'] = !new.to_s.empty?
    savemeta
  end

  #set time to live for gallery
  #days = days from now.. 0 = permanent
  #no param = return date of expiration
  def expires(days=nil)
    if days==nil
      return File.readlines(@exppath)[0].chomp.to_i if File.exists? @exppath
      return nil #never
    end

    days = days.to_i
    if days != 0
      expiration = (Time.now+86400*days).to_i
      File.write(@exppath, expiration)
    else
      File.delete(@exppath) if File.exists? @exppath
    end
  end

  #get picture IDs and their labels
  def pics
    @meta['pics']
  end

  def setname(picid, name)
    n = @meta['pics'][picid]
    return false if !n
    @meta['pics'][picid] = name
    savemeta
    return true
  end

  #add a new image to the gallery as JPG
  #with given image data, label and optional size
  def add(data,label,size=nil)
    picid = @meta['pics'].keys.map(&:to_i).max.to_i+1
    picid=picid.to_s
    @meta['pics'][picid] = label

    #resize if neccessary
    if size
      tmp = Magick::Image.from_blob(data)[0]
      data = tmp.adaptive_resize(size[0],size[1]).to_blob
    end

    #create thumbnail (shrink if neccessary)
    thumb = data
    pic = Magick::Image.from_blob(data)[0]
    scale = 320.to_f/[pic.columns, pic.rows].max.to_f
    thumb = pic.thumbnail(scale).to_blob if scale<1

    File.write(@path+picid, data)
    File.write(@path+picid+'_thumb', thumb)
    savemeta
  end

  #get picture from gallery or its thumbnail
  def get(picid, thumb=false)
    p = get_path picid, thumb
    return nil if !p
    mime = get_mime picid
    if mime == 'image/svg+xml'
      File.readlines(p).join
    else
      img = Magick::Image.read(p)[0]
      img.to_blob
    end
  rescue
    nil
  end

  #get picture path from gallery
  def get_path(picid, thumb=false)
    picid=picid.to_s
    picid=picid+'_thumb' if thumb
    p=@path+picid
    return p if File.exists? p
    return nil
  end

  #get mime type
  def get_mime(picid)
    p = get_path picid
    return `file -b --mime-type #{get_path picid}`.chomp if p
    return nil
  end

  #remove picture from gallery
  def delete(picid)
    picid=picid.to_s
    File.delete(@path+picid)
    File.delete(@path+picid+'_thumb')
    @meta['pics'].delete(picid)
    savemeta
    return true
  rescue
    return false
  end

  #remove gallery
  def destroy
    FileUtils.rm_rf @path
    return true
  end

  #list all existing galleries
  def self.galleries
    Dir.entries(@@base)-['.','..']
  end

  #generate gallery id
  def self.genid
    hash = genchars 8
    galls = galleries
    while galls.index(hash)
      hash = (hash.to_i(36)+1).to_s(36) #increment
    end
    return hash
  end

  #generate random 10 character password
  def self.genchars(n)
    n.times.map{Random.rand(36)}.map{|n| n.to_s(36)}.join
  end

  private

  def genid
    return self.class.genid
  end

  def genchars(n)
    return self.class.genchars n
  end

  #load metadata from file
  def readmeta
    @meta = JSON.parse open(@path+'.meta','r:UTF-8').read
  end

  #save changes to metadata
  def savemeta
    File.write @path+'.meta', JSON.generate(@meta)
  end
end
