require 'twitter'
require 'yaml'

# Twitter API関連の処理全般
class TwitterClient
  def initialize
    # 初期化(やることある？)
    @api_keys_path = './api_keys.yml'
    
  end

  def check_api_key_file
    # APIキーが書かれたファイルが有るか確認
    if File.exist?(@api_keys_path)
      load_api_keys
    else
      get_api_keys
    end
  end
    
  def load_api_keys
    # APIキーを読み込む
    api_keys = YAML.load_file(@api_keys_path)
    if api_keys['AccessToken'] && api_keys['AccessTokenSecret']
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

  def get_api_keys
    # APIキーを取得する
  end

end