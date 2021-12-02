require 'twitter'
require 'yaml'
require 'oauth'

# Twitter API関連の処理全般
class TwitterClient
  def initialize
    # 初期化(やることある？)
    @api_keys_path = './api_keys.yml'
  end

  def check_api_key_file
    # APIキーが書かれたファイルが有るか確認
    if File.exist?(@api_keys_path)
      # ある場合はAPIキーを読み込む
      load_api_keys
    else
      # ない場合は、APIキーを取得して、ファイルに書き込む
      input_ck_cs
    end
  end

  def load_api_keys
    # APIキーを読み込む
    api_keys = YAML.load_file(@api_keys_path)
    # APIキーを読み込んだが、AT,ATSがない場合は、APIキーを取得して書き込む
    if !api_keys['AccessToken'].nil? || !api_keys['AccessTokenSecret'].nil?
      authrize_client(api_keys)
    else
      get_api_keys
    end
    authrize_client(api_keys)
  end

  def authrize_client(api_keys)
    # 読み込んだAPIキーを使ってTwitterクライアントを作成
    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = api_keys['API_Key']
      config.consumer_secret     = api_keys['API_Secret_Key']
      config.access_token        = api_keys['Access_Token']
      config.access_token_secret = api_keys['Access_Token_Secret']
    end
  end

  def get_api_keys(api_keys)
    # APIキーを取得する
    ck = api_keys['API_Key']
    cs = api_keys['API_Secret_Key']
    consumer = OAuth::Consumer.new ck, cs, site: 'https://api.twitter.com'

    request_token = consumer.get_request_token
    puts '認証されていません。以下のURLからアプリを許可し、PINコードを入力してください。'
    puts "認証URL: #{request_token.authorize_url}"
    STDERR.print 'PINコード: '

    access_token = request_token.get_access_token oauth_verifier: gets.chomp
    puts "Access Token : #{access_token.token}"
    puts "Access Secret: #{access_token.secret}"
    at = access_token.token
    ats = access_token.secret
    save_api_keys(ck, cs, at, ats)
  end

  def input_ck_cs
    # CK,CSが存在しないので、入力してもらう。
    puts 'Consumer Key, Consumer Secretが存在しません。'
    puts 'CK, CSを入力してください。'
    STDERR.print 'CK: '
    ck = gets.chomp
    STDERR.print 'CS: '
    cs = gets.chomp
    api_keys = {
      'API_Key' => ck,
      'API_Secret_Key' => cs
    }
    get_api_keys(api_keys)
  end

  def save_api_keys(ck = nil, cs = nil, at = nil, ats = nil)
    # APIキーを保存する
    api_keys = {
      'API_Key' => ck,
      'API_Secret_Key' => cs,
      'Access_Token' => at,
      'Access_Token_Secret' => ats
    }
    File.open(@api_keys_path, 'w') do |f|
      f.write api_keys.to_yaml
    end
  end

  def check_api_limits
    # API制限を確認する
    rate_limit = @client.rate_limit_status
    puts 'API制限を確認しました。'
    puts "Remaining: #{rate_limit.remaining_hits}"
    puts "Reset: #{rate_limit.reset_time}"
  end
end
