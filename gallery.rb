
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
  File.write('nextid','0') if !File.exists?('nextid')

  attr_reader :path, :id

  def self.open(id)
    Gallery.new(id)
  rescue
    nil
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
      @id = nextid
      @path = @@base+@id+'/'
      Dir.mkdir @path
      @meta = {'title' => "Gallery #{@id}", 'password' => genpwd, 'pics' => {}}
      savemeta
    end
  end

  #get password for gallery
  def password(newpwd=nil)
    return @meta['password'] if !newpwd
    @meta['password'] = newpwd
    savemeta
  end

  #get picture IDs and their labels
  def pics
    @meta['pics']
  end

  def title(newname=nil)
    return @meta['title'] if !newname
    @meta['title'] = newname
    savemeta
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
      tmp.format = 'JPG'
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
    picid=picid.to_s
    picid=picid+'_thumb' if thumb
    img = Magick::Image.read(@path+picid)[0]
    img.to_blob
  rescue
    nil
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

  private
  #get next pic id and increase counter
  def nextid
    id = File.readlines('nextid')[0]
    File.write('nextid',"#{id.to_i+1}")
    return id
  end

  #generate random 10 character password
  def genpwd
    10.times.map{Random.rand(26)}.map{|n| n.to_s(26)}.join
  end

  def readmeta
    @meta = JSON.parse File.readlines(@path+'.meta').join
  end

  def savemeta
    File.write @path+'.meta', JSON.generate(@meta)
  end

end
