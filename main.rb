require 'bundler/setup'
require 'rubygems'
require 'yaml'
require 'twitter'
require 'json'
require 'pp'

# クソデカクラス
class UpdateNamer
  def initialize
    config_file = YAML.load_file('./config.yml')
    api = config_file['api']
    @config_option = config_file['option']
    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = api['API_Key']
      config.consumer_secret     = api['API_Secret_Key']
      config.access_token        = api['Access_Token']
      config.access_token_secret = api['Access_Token_Secret']
    end
    puts '初期化終了しました。'
  end

  def load_default
    config_default  = @config_option['default']
    @default_prefix = @current_prefix = config_default['prefix']
    @default_name   = @current_name   = config_default['name']
    @default_suffix = @current_suffix = config_default['suffix']
  end

  def load_cache
    @cache_path = @config_option['cache_file']
    if File.exist?(@cache_path)
      json = File.open(@cache_path) do |io|
        JSON.load(io)
      end
      @default_prefix = json['prefix']
      @default_name   = json['name']
      @default_suffix = json['suffix']
      @last_tweet     = json['tweet_id']
    else
      @last_tweet = nil
    end
  end

  def save_cache
    hash = {}
    hash['tweet_id'] = @last_tweet
    hash['prefix']   = @current_prefix
    hash['name']     = @current_name
    hash['suffix']   = @current_suffix
    File.open(@cache_path, 'w') do |file|
      JSON.dump(hash, file)
    end
  end

  # リプライを取得
  def fetch_mentions(tweet_id)
    if tweet_id.nil?
      @client.mentions_timeline
    else
      @client.mentions_timeline(since_id: tweet_id)
    end
  end

  def get_tweet_info(tweets)
    result = []
    tweets.reverse_each do |tweet|
      tweet_info = {}
      tweet_info['screen_name'] = tweet.user.screen_name
      tweet_info['tweet_id']    = tweet.id
      tweet_info['text']        = tweet.full_text.gsub(/^@[0-9a-zA-Z_]{1,15}\s+/, '')
      tweet_info['mode']        = check_mode(tweet_info['text'])
      tweet_info['parameter']   = extract_parameter(tweet_info['text'])
      pp tweet_info
      puts '========='
      result.push(tweet_info)
    end
    result
  end

  # モードチェック
  def check_mode(text)
    if text.start_with?('update_name')
      text = text.gsub(/^update_name\s+/, '')
      case text
      when /^-prefix/
        'prefix'
      when /^-suffix/
        'suffix'
      when /^-reset/
        'reset'
      when /^-help/
        'help'
      when /^-version/
        'version'
      when /^-ping/
        'ping'
      else
        'name'
      end
    end
  end

  def extract_parameter(text)
    if text.start_with?('update_name')
      parm = text.gsub(/^update_name\s+/, '')
      parm.gsub(/^-(prefix|suffix|reset|help|version|ping)\s*/, '') unless parm == ''
    end
    parm
  end

  def check_lenght(mode, str)
    # 1文字以上、50文字以内
    # prefix,suffixは0文字以上
    # nameは1文字以上に規定
    # また、すべてを結合したときの文字数が50文字以下になるようにする。
    # それ以外はエラーを返す。
    case mode
    when 'prefix', 'suffix'
      if str.size < 0
        result = false
        msg = '文字が短すぎます。0文字以上にしてください。'
      elsif str.size > 50
        result = false
        msg = '文字が長すぎます。49文字以内にしてください。'
      else
        result = true
        msg = ''
      end
    when 'name', 'jointed'
      if str.size < 1
        result = false
        msg = '文字が短すぎます。1文字以上にしてください。'
      elsif str.size > 51
        result = false
        msg = '文字が長すぎます。50文字以内にしてください。'
      else
        result = true
        msg = ''
      end

    end
    { 'result' => result, 'message' => msg }
  end

  def joint_string(mode, str)
    next_name = ''
    result = check_lenght(mode, str)
    if result['result'] == true || mode == 'reset'
      case mode
      when 'prefix'
        next_name = str + @current_name + @current_suffix
        @current_prefix = str
      when 'name'
        next_name = @current_prefix + str + @current_suffix
        @current_name = str
      when 'suffix'
        next_name = @current_prefix + @current_name + str
        @current_suffix = str
      when 'reset'
        next_name = @default_prefix + @default_name + @default_suffix
        @current_prefix = @default_prefix
        @current_name   = @default_name
        @current_suffix = @default_suffix
      end
      result = check_lenght('jointed', next_name)
    end
    { 'status' => result['result'], 'message' => result['message'], 'mode' => mode, 'name' => next_name }
  end

  def mode_switcher(mode, str)
    case mode
    when 'prefix', 'name', 'suffix', 'reset'
      joint_string(mode, str)
    when 'help'
      return_help(str)
    when 'version'
      return_version(str)
    when 'ping'
      return_ping(str)
    end
  end

  def return_help(_str)
    msg = 'help
update_name : 表示名を変更します。
update_name -(prefix|suffix) : 接頭辞、接尾辞を追加します。
update_name -reset : 表示名、接尾辞、接頭辞を初期値に戻します。
update_name -help : ヘルプを表示します。'
    { 'status' => true, 'message' => msg, 'mode' => 'help', 'name' => nil }
  end

  def return_version(_str)
    msg = 'UpdateNamer Version 0.2β'
    { 'status' => true, 'message' => msg, 'mode' => 'version', 'name' => nil }
  end

  def return_ping(_str)
    msg = 'Pong'
    { 'status' => true, 'message' => msg, 'mode' => 'ping', 'name' => nil }
  end

  def change_name(str)
    @client.update_profile({ name: str })
    { 'status' => true }
  rescue StandardError => e
    puts '例外'
    puts e
    puts '例外終了'
    { 'status' => false, 'reason' => e }
  end

  def post_reply(tweet, joint_name, result)
    if result['status']
      case tweet['mode']
      when 'prefix'
        msg = "@#{tweet['screen_name']} によって接頭辞が#{tweet['parameter']}に変更されました。"
      when 'name'
        msg = "@#{tweet['screen_name']} によって名前が#{tweet['parameter']}に変更されました。"
      when 'suffix'
        msg = "@#{tweet['screen_name']} によって接尾辞が#{tweet['parameter']}に変更されました。"
      when 'reset'
        msg = "@#{tweet['screen_name']} によって名前がリセットされました。"
      when 'help'
        msg = "@#{tweet['screen_name']} #{joint_name['message']}"
      when 'version'
        msg = "@#{tweet['screen_name']} #{joint_name['message']}"
      when 'ping'
        msg = "@#{tweet['screen_name']} #{joint_name['message']}"
      end
    else
      msg = "@#{tweet['screen_name']} #{result['reason']}"
    end
    @client.update(msg, { in_reply_to_status_id: tweet['tweet_id'] })
  end

  def main
    load_default
    load_cache
    while true
      tweet_info = get_tweet_info(fetch_mentions(@last_tweet))
      tweet_info.each do |tweet|
        next if tweet['mode'].nil?

        joint_name = mode_switcher(tweet['mode'], tweet['parameter'])
        result = if tweet['mode'] == 'help' || tweet['mode'] == 'version' || tweet['mode'] == 'ping'
                   { 'status' => true }
                 else
                   change_name(joint_name['name'])
                 end
        pp result
        post_reply(tweet, joint_name, result)
      end
      unless tweet_info.empty?
        @last_tweet = tweet_info.last['tweet_id']
        save_cache
      end
      sleep 60
    end
  end
end
main = UpdateNamer.new
main.main
