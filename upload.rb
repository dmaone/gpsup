require 'watir'
require 'yaml'

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



config = YAML.load_file('config.yml')
b = login(config)


folder = "foldertest"

country = "CA"
title = "test"

#new_label(b, folder)

upload_track(b, folder, country, title)
