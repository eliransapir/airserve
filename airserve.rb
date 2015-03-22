require "cuba"
require "airplayer"
require "rest_client"
require "mustache"

Cuba.use Rack::Session::Cookie, :secret => "__a_very_long_string__"

#Cuba.plugin Cuba::Safe

dirroot = "/home/public/media/"
controller = AirPlayer::Controller.new({device: 0, progress: false})

def browse(dirroot, dirstub)
  folders = []
  files = []
  dirpath = dirroot + URI.unescape(dirstub)
  Dir.foreach(dirpath) do |item|
    next if item.start_with?('.')
    filepath = "#{dirpath}/#{item}"
    if File.directory?(filepath)
      folders << item
      next
    end
    files << item
  end

  template = File.open("browse.mustache", "rb").read
  res.write Mustache.render(template, \
    :dirstub => dirstub, :folders => folders.sort, :files => files.sort)
end

Cuba.define do

  # only GET requests
  on get do

    # /
    on root do
      browse(dirroot, "")
    end

    # /about
    on "play/(.*)" do |title|
      decoded_title = URI.unescape(title)
      playlist = AirPlayer::Playlist.new()
      playlist.add(dirroot + decoded_title)
      playlist.entries do |media|
        Thread.new {
          begin
            controller.play(media)
          rescue
            controller = AirPlayer::Controller.new({device: 0, progress: false})
            controller.play(media)
          end
        }

        template = File.open("play.mustache", "rb").read
        res.write Mustache.render(template, :title => decoded_title)
      end
    end

    on "browse/(.*)" do |dirstub|
      browse(dirroot, "/#{dirstub}")
    end

    on "view/(.*)" do |title|
      decoded_title = URI.unescape(title)
      template = File.open("view.mustache", "rb").read
      res.write Mustache.render(template, :title => decoded_title)
      controller.pause
    end

    on "pause/(.*)" do |title|
      decoded_title = URI.unescape(title)
      template = File.open("pause.mustache", "rb").read
      res.write Mustache.render(template, :title => decoded_title)
      controller.pause
    end

    on "resume/(.*)" do |title|
      decoded_title = URI.unescape(title)
      template = File.open("play.mustache", "rb").read
      res.write Mustache.render(template, :title => decoded_title)
      controller.resume
    end

    on "stop/(.*)" do |title|
      decoded_title = URI.unescape(title)      
      template = File.open("stop.mustache", "rb").read
      res.write Mustache.render(template, :title => decoded_title)
      controller.stop
    end

    #on "skip?{.*}" do |mins|
    #  seconds = mins * 60
    #  RestClient.post "192.168.0.10:7000/scrub?position=#{seconds}", {}
    #  res.write "<a href='/pause'>Pause</a>"
    #end

  end
end
