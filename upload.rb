require 'watir'
require 'yaml'
require 'net/https'
require 'uri'
require 'json'

def login(config)
    b = Watir::Browser.start "https://gpslib.ru/tracks/upload.php", :chrome
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

def upload_track(browser, folder, country, title)
    browser.radio(:id => "type_auto").set
    browser.text_field(:id => "title").set title
    browser.text_field(:id => "city").set ""
    browser.select_list(:name => "country").option(:value => country).select
    browser.select_list(:name => "label").option(:text => folder).select
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

def process_folder(browser, config, folder)
    Dir.foreach(folder) do |f|
        fullname = File.join(Dir.pwd, folder, f)
        next if !File.file?( fullname )
        country = lookup_country(config, fullname)
        puts fullname, country
        exit
    end
end

config = YAML.load_file('config.yml')


folder = "foldertest"

country = "CA"
title = "test"

here = Dir.pwd
b = ''

Dir.chdir(config["upload_from"])
Dir.foreach(".") do |entry|
    process_folder(b, config, entry) if entry[0] != "."
end
Dir.chdir(here)

#b = login(config)
#new_label(b, folder)
#upload_track(b, folder, country, title)
