require 'bundler/setup'
require 'rubygems'
require 'yaml'
require 'twitter'
require 'json'
require 'set'
require 'pp'

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

  def load_default_name
    @default_names = @config_option['default']
  end

  def load_cache(path)
    if File.exist?(path)
      cache = File.open(path) do |io|
        JSON.load(io)
      end
      @current_names = cache['current']
      @last_tweet    = cache['tweet_id']
    else
      @current_names = Marshal.dump(@default_names)
      @last_tweet = nil
    end
  end

  def save_cache(path)
    cache = {}
    cache['tweet_id'] = @last_tweet
    cache['current']  = @current_names
    File.open(path, 'w') do |io|
      JSON.dump(cache, io)
    end
  end

  def fetch_mentions(tweet_id)
    if tweet_id.nil?
      @client.mentions_timeline
    else
      @client.mentions_timeline(sinse_id: tweet_id)
    end
  end

  def extract_tweet_info(tweets)
    tweets_info = []
    puts '========='
    tweets.reverse_each do |tweet|
      tweet_info = {}
      tweet_info['screen_name'] = tweet.user.screen_name
      tweet_info['tweet_id']    = tweet.id
      tweet_info['text']        = tweet.full_text.gsub(/^@[0-9a-zA-Z_]{1,15}\s+/, '')
      tweet_info['commands']    = parse_command(tweet_info['text'])
      pp tweet_info
      puts '========='
      tweets_info.push(tweet_info)
    end
    tweets_info
  end

  def parse_command(text)
    commands = []
    if text.start_with?('update_name')
      cutout_text = text.gsub(/^update_name\s*/, '')
      if cutout_text.empty?
        commands = [{ 'command' => 'name', 'arg' => '' }]
      else
        cutout_text.split(/\s+-/).each_with_index do |element, index|
          if index == 0
            if element.start_with?('-') && element != '-'
              commands.push(separate_parm(element.gsub(/^-/, '')))
            else
              commands.push({ 'command' => 'name', 'arg' => element })
            end
          else
            commands.push(separate_parm(element))
          end
        end

      end
    else
      commands = []
    end
    delete_duplicate_command(commands)
  end

  def separate_parm(str)
    cmd_ary = str.split(/\s+/, 2)
    { 'command' => cmd_ary[0], 'arg' => cmd_ary[1] }
  end

  def delete_duplicate_command(source)
    target = []
    source.each do |source_hash|
      if target.empty?
        target.push(source_hash)
      else
        dup_flag = false
        target.each do |target_hash|
          if source_hash['command'] == target_hash['command']
            dup_flag = false
            break
          else
            dup_flag = true
          end
        end
        target.push(source_hash) if dup_flag == true
      end
    end
    target
  end

  def check_available_command(source, available_cmd)
    result = source.any? do |cmd|
      !available_cmd.include?(cmd['command'])
    end
    if result == false
      { 'error' => false, 'reason' => '' }
    else
      { 'error' => true, 'reason' => '未知のオプションが指定されています。' }
    end
  end

  def check_exclusive_command(source)
    error  = false
    reason = nil
    if source.empty?
      error  = false
      reason = 'コマンドなし'
    elsif source.size == 1
      error  = false
      reason = "コマンドが一つしか指定されていません。CMD: #{source[0]['command']}"
    else
      source.each_with_index do |cmd, index|
        if index.zero?
          first_cmd = cmd['command']
        else
          case first_cmd
          when 'name', 'prefix', 'suffix'
            if cmd['command'] == 'name' || cmd['command'] == 'prefix' || cmd['command'] == 'suffix'
              error = false
              reason = 'name, prefix, suffixコマンドは共存可能です。'
            else
              error = true
              reason = "#{first_cmd}と#{cmd['command']}は共存不可能なオプションです。"
              break
            end
          when 'reset', 'help', 'version', 'ping'
            error  = true
            reason = "#{first_cmd}はその他すべてのオプションと共存不可能です。"
            break
          else # 未知のオプション
            error  = true
            reason = '未知のオプションです。-helpを使用し、利用可能なオプションを確認してください。'
          end
        end
      end
    end
    { 'error' => error, 'reason' => reason }
  end

  def check_command(tweet); end

  def main
    load_default_name
    load_cache(@config_option['cache_file'])
    loop do
      tweets = extract_tweet_info(fetch_mentions(@last_tweet))
      tweets.each do |tweet|
        puts (tweet['commands']).to_s
        break if tweet['commands'].empty?
        if check_available_command(tweet['commands'],
                                   %w[name prefix suffix reset help version ping])['error'] == true
          break
        end

        result = check_exclusive_command(tweet['commands'])
        pp result
        puts '======='
      end

      puts "Sleep: #{@config_option['cooldown']}s"
      sleep @config_option['cooldown']
    end
    save_cache(@config_option['cache_file'])
  end
end
main = UpdateNamer.new
main.main
