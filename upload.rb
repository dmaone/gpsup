require 'watir'
require 'yaml'
require 'net/https'
require 'uri'
require 'json'

def login(config)
    b = Watir::Browser.start "https://gpslib.ru/", :chrome
    b.text_field(:id =>  "flogin").set config["username"]
    b.text_field(:id => "fpassword").set config["password"]
    b.button(:type => "submit").click
    return b
end

def new_label(browser, label_name)
    browser.goto "https://gpslib.ru/tracks/labels.php"
    browser.button(:class => "btn-primary").click
    browser.text_field(:id => "tag").set label_name
    browser.checkbox(:id => "public").set
    browser.button(:type => "submit").click
end

def upload_track(browser, folder, track)
    browser.goto "https://gpslib.ru/tracks/upload.php"
    browser.radio(:id => "type_auto").set
    browser.text_field(:id => "title").set track['title']
    browser.text_field(:id => "city").set ""
    browser.select_list(:name => "country").option(:value => track['country']).select
    browser.select_list(:name => "label").option(:text => folder).select
    browser.file_field(:id => "file").set(track['name'])
    browser.button(:type => "submit").click
end

def lookup_country(config, filename)
    # get coordinates from the middle of the track to avoid country borders
    retval = nil
    l = File.size?(filename)
    File.open(filename, "r") do |f|
        f.seek(l/2, :SET)
        f.readline
        buf = f.readline
        md = /<trkpt\s+lat="(?<lat>[^"]+)"\s+lon="(?<lon>[^"]+)">/.match(buf)
        uri = URI.parse("https://maps.googleapis.com/maps/api/geocode/json?latlng=#{md['lat']},#{md['lon']}&key=#{config['geocode_api_key']}")
        client = Net::HTTP.new(uri.host, uri.port)
        client.use_ssl = true
        # We won't pass PCI audit with this, that's for sure.
        client.verify_mode = OpenSSL::SSL::VERIFY_NONE
        resp = client.request(Net::HTTP::Get.new(uri.request_uri))
        data = JSON.parse(resp.body)
        data['results'][0]['address_components'].each do |component|
            retval = component['short_name'] if component['types'][0] == "country"
        end
    end
    raise "Cannot determine track country!" if retval.nil?
    return retval
end

def get_title(filename)
    retval='Untitled'
    File.open(filename, "r") do |f|
        md = nil
        while !f.eof? and md.nil?
            md = /<time>(?<time>[^Z]+)Z/.match(f.readline)
        end
        retval = md['time'] if !md.nil?
    end
    return retval
end

def scan_folder(config, folder)
    retval = Array.new
    Dir.foreach(folder) do |f|
        fullname = File.join(Dir.pwd, folder, f)
        next if !File.file?( fullname )
        title = get_title(fullname)
        country = lookup_country(config, fullname)
        retval.push( { "name" => fullname, "country" => country, "title" => title } )
    end
    return retval
end

def upload_folder(browser, config, folder, tracks)
    new_label(browser, folder)
    tracks.each do |track|
        upload_track(browser, folder, track)
    end
end

config = YAML.load_file('config.yml')

here = Dir.pwd

b = login(config)

Dir.chdir(config["upload_from"])
Dir.foreach(".") do |entry|
    tracks = scan_folder(config, entry) if entry[0] != "."
    upload_folder(b, config, entry, tracks) if !tracks.nil?
end
Dir.chdir(here)
