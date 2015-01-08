require 'sinatra/base'
require 'json'
#require 'sinatra/flash'
require 'yaml'
# require 'sinatra/namespace'
require 'haml'
require 'sinatra/simple-navigation'
require 'sinatra/flash'
require 'httparty'
require 'aws-sdk'

# web version of MovieCrawlerApp(https://github.com/ChenLiZhan/SOA-Crawler)
class MovieViewApp < Sinatra::Base
  set :views, Proc.new { File.join(root, "views") }
  # enable :sessions
  use Rack::Session::Pool
  register Sinatra::Flash
  use Rack::MethodOverride
  # register Sinatra::SimpleNavigation
  # SimpleNavigation.config_file_paths << File.expand_path('../config', __FILE__)
  # register Sinatra::Namespace

  configure :production, :development do
    enable :logging
  end

  API_BASE_URI = 'https://serene-citadel-5567.herokuapp.com'
  # API_BASE_URI = 'http://localhost:8080'
  API_VER = '/api/v2/'
  TOPIC_ARN = 'arn:aws:sns:us-west-2:819536398009:Movie'
  # SINGLEMOVIE_TOPIC = 'arn:aws:sns:us-west-2:819536398009:moviesearch'

  helpers do
    # RANK_LIST = { '1' => 'U.S.', '2' => 'Taiwan', '3' => 'DVD' }
    def api_url(resource)
      URI.join(API_BASE_URI, API_VER, resource).to_s
    end

    def current_page?(path = ' ')
      path_info = request.path_info
      path_info += ' ' if path_info == '/'
      request_path = path_info.split '/'
      request_path[1] == path
    end

    def notification(category, subject)
      sns = AWS::SNS.new
      t = sns.topics[TOPIC_ARN]
      result = t.publish(category, subject: subject)
    end
  end

  get '/' do
    haml :home
  end

  get '/info/:category' do
    @category = params[:category]
    notification(@category, 'info')
    @intros = HTTParty.get api_url("info/#{@category}.json")

    haml :intro
  end

  get '/rank/:category' do
    @category = params[:category]
    notification(@category, 'rank')
    @boxoffices = HTTParty.get api_url("rank/#{@category}.json")

    haml :boxoffice
  end

  get '/movie' do
    @action = :create
    haml :movie
  end

  post '/movie' do
    # if params[:movie].split(/[\r\n\s]/).length > 1
    #   flash[:notice] = 'One movie at a time, take easy!'
    #   redirect '/movie'
    #   return nils
    # end
    # request_url = api_url("movie")
    movie = params[:movie].strip
    param = {
      movie: movie
    }
    options = {
      headers: { 'Content-Type' => 'application/json' },
      body: param.to_json
    }

    unique_key = "Movie-SQS-#{Time.new.to_i}"
    notification(movie, unique_key)

    sqs = AWS::SQS.new(region: ENV['AWS_REGION'])

    queue = sqs.queues.create(unique_key, visibility_timeout: 90, maximum_message_size: 262144)

    queue.poll do |received_message|
      message = JSON.parse(received_message.body)
      logger.info "received message '#{message}'"
    end
    # result = HTTParty.post(request_url, options)

    # id = result.request.last_uri.path.split('/').last
    # session[:result] = result.to_json
    # session[:movie] = movie
    # session[:action] = :create
    # redirect "/movie/#{id}"
  end

  get '/movie/:id' do
    # if session[:action] == :create
    #   @results = JSON.parse(session[:result])
    #   @movie = session[:movie]
    # else
    request_url = api_url("moviechecked/#{params[:id]}")
    result = HTTParty.get(request_url)
    @results = YAML.load(result['info'])
    # end

    @id = params[:id]
    @action = :update
    haml :movie
  end

  delete '/movie/:id' do
    request_url = api_url("moviechecked/#{params[:id]}")
    result = HTTParty.delete(request_url)
    flash[:notice] = 'Record of movie deleted'
    redirect '/movie'
  end
end
