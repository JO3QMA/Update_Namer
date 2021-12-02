require 'twitter'
require 'yaml'
require 'oauth'

# Twitter API関連の処理全般
class TwitterClient
  def initialize
    # 初期化(やることある？)
    @api_keys_path = './api_keys.yml'
  end

  def load_api_keys
    # APIキーを読み込む
    api_keys = YAML.load_file(@api_keys_path)
    if !api_keys['Consumer_Key'].nil? && !api_keys['Consumer_Secret_Key'].nil? && !api_keys['Access_Token'].nil? && !api_keys['Access_Token_Secret'].nil?
      # CK, CS, AT, ATS全てある場合 ->  クライアントを作成する。
      create_client(api_keys)
    elsif !api_keys['Consumer_Key'].nil? && !api_keys['Consumer_Secret_Key'].nil?
      # CK, CSのみある場合 ->  AT,ATSを取得して、ファイルに書き込む。
      api_keys = get_api_keys(api_keys)
      save_api_keys(api_keys)
    else
      # CK, CS, AT, ATS全てがない場合 -> CK,CSを入力してもらう。
      api_keys = input_ck_cs
      api_keys = get_api_keys(api_keys)
      save_api_keys(api_keys)
    end
  end

  def create_client(api_keys)
    # 読み込んだAPIキーを使ってTwitterクライアントを作成
    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = api_keys['Consumer_Key']
      config.consumer_secret     = api_keys['Consumer_Secret_Key']
      config.access_token        = api_keys['Access_Token']
      config.access_token_secret = api_keys['Access_Token_Secret']
    end
  end

  def get_api_keys(api_keys)
    # CK, CSのみある場合、AT,ATSを取得して、ファイルに書き込む。
    ck = api_keys['Consumer_Key']
    cs = api_keys['Consumer_Secret_Key']
    consumer = OAuth::Consumer.new ck, cs, site: 'https://api.twitter.com'

    request_token = consumer.get_request_token
    puts '認証されていません。以下のURLからアプリを許可し、PINコードを入力してください。'
    puts "認証URL: #{request_token.authorize_url}"
    STDERR.print 'PINコード: '

    access_token = request_token.get_access_token oauth_verifier: gets.chomp
    at = access_token.token
    ats = access_token.secret
    puts "Access Token : #{at}"
    puts "Access Secret: #{ats}"
    {
      'Consumer_Key' => ck,
      'Consumer_Secret_Key' => cs,
      'Access_Token' => access_token.token,
      'Access_Token_Secret' => access_token.secret
    }
  end

  def input_ck_cs
    # CK,CSが存在しないので、入力してもらう。
    puts 'Consumer Key, Consumer Secretが存在しません。'
    puts 'CK, CSを入力してください。'
    STDERR.print 'CK: '
    ck = gets.chomp
    STDERR.print 'CS: '
    cs = gets.chomp
    {
      'Consumer_Key' => ck,
      'Consumer_Secret_Key' => cs
    }
  end

  def save_api_keys(api_keys)
    # APIキーを保存する
    File.open(@api_keys_path, 'w') do |f|
      f.write api_keys.to_yaml
    end
  end

  def auth_sequence
    # 認証シークエンス

    # APIキーが書かれたファイルが有るか確認
    if File.exist?(@api_keys_path)
      # ある場合はAPIキーを読み込む
      load_api_keys
    else
      # ない場合は、APIキーを取得して、ファイルに書き込む
      api_keys = input_ck_cs
      api_keys = get_api_keys(api_keys)
      save_api_keys(api_keys)
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
