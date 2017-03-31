# -*- coding: utf-8 -*-
require 'twitter'
require 'mysql2'
require 'sinatra'
require 'open-uri'
require 'yaml'
set :server, 'webrick'

# 変数
limit   = 200    # 取得するツイートの上限数
keyword = "本田翼"   # ハッシュタグによる検索を行う際のキーワード
tconfig = YAML.load_file("config/settings.yml")

# Twitter APIによるリクエスト
client = Twitter::REST::Client.new do |config|
    config.consumer_key        = tconfig["twitter"]["consumer_key"]
    config.consumer_secret     = tconfig["twitter"]["consumer_secret"]
    config.access_token        = tconfig["twitter"]["access_token"]
    config.access_token_secret = tconfig["twitter"]["access_token_secret"]
end

#データべースの接続
db_client = Mysql2::Client.new(:host => 'localhost', :username => 'root', :password =>  tconfig["db"]["pass"])
db_client.query("delete from twitter.test1")

# キーワードを含むハッシュタグの検索
begin
    # limitで指定された数だけツイートを取得
    client.search("#{keyword} -rt", :locale => "ja", :result_type => "recent", :include_entity => true).take(limit).map do |tweet|
        # entities内にメディア(画像等)を含む場合の処理
        if tweet.media? then
            tweet.media.each do |value|
                puts value.media_uri
                db_client.query("insert into twitter.test1 values ('#{value.media_uri}')")
            end
        end
    end

    get '/' do
      @data = []
      db_client.query("select url from twitter.test1").each do |obj|
        @data << obj
      end
      erb :index
    end

# 検索ワードでツイートを取得できなかった場合の例外処理
rescue Twitter::Error::ClientError
    puts "ツイートを取得できませんでした"

# リクエストが多すぎる場合の例外処理
rescue Twitter::Error::TooManyRequests => error
    sleep error.rate_limit.reset_in
    retry
end
