require 'sinatra/base'
#require 'movie_crawler'
require 'json'
require 'yaml'
# require 'sinatra/namespace'
require 'haml'
require 'sinatra/flash'
require 'httparty'
#require_relative 'model/movie'
#require_relative 'model/theater'

# web version of MovieCrawlerApp(https://github.com/ChenLiZhan/SOA-Crawler)
class MovieCrawlerApp < Sinatra::Base
  enable :sessions
  # use Rack::Session::Pool
  use Rack::MethodOverride
  register Sinatra::Flash

   configure :production, :development do
     enable :logging
   end
   configure :development do
     set :session_secret, "something"    # ignore if not using shotgun in development
   end

  API_BASE_URI = 'http://127.0.0.1:4567'
  API_VER = '/api/v2/'


  helpers do
    def current_page?(path = ' ')
      path_info = request.path_info
      path_info += ' ' if path_info == '/'
      request_path = path_info.split '/'
      request_path[1] == path
    end

    def api_url(resource)
      URI.join(API_BASE_URI, API_VER, resource).to_s
    end
  end


  get '/' do
    haml :home, :layout => true
    # SimpleNavigation.config_file_paths
    # settings.views
  end


  get '/info/:category' do
    @intros = params[:category]
    @list = HTTParty.get api_url("info/#{@intros}.json")

    if @intros && @list.nil?
      flash[:notice] = "list #{@list} not found" if @list.nil?
      redirect '/'
      return nil
    end

    haml :intro
  end

  get '/rank/:category' do
    @boxoffices = get_ranks(params[:category])

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
    #   return nil
    # end

    movie = params[:movie].strip
    request_url = "#{API_BASE_URI}/api/v2/movie"
    param = {
      movie: movie
    }
    options = {
      headers: { 'Content-Type' => 'application/json' },
      body: param.to_json
    }
    result = HTTParty.post(request_url, options)

    # if (result.code != 200 && result.code != 302)
    #   flash[:notice] = 'Movie not found'
    #   redirect '/movie'
    #   return nil
    # end

    id = result.request.last_uri.path.split('/').last
    session[:result] = result.to_json
    session[:movie] = movie
    session[:action] = :create
    redirect "/movie/#{id}"
  end

  get '/movie/:id' do
    # if session[:action] == :create
    #   @results = JSON.parse(session[:result])
    #   @movie = session[:movie]
    # else
    request_url = "#{API_BASE_URI}/api/v2/moviechecked/#{params[:id]}"
    result = HTTParty.get(request_url)
    @results = YAML.load(result['info'])
    # end

    @id = params[:id]
    @action = :update
    haml :movie
  end

  delete '/movie/:id' do
    request_url = "#{API_BASE_URI}/api/v2/moviechecked/#{params[:id]}"
    result = HTTParty.delete(request_url)
    flash[:notice] = 'Record of movie deleted'
    redirect '/movie'
  end

  # # namespace '/api/v1' do


# here is the api routes

  post '/api/v2/movie' do
    content_type :json, charset: 'utf-8'

    body = request.body.read
    begin
      req = JSON.parse(body)
      logger.info req
    rescue Exception => e
      puts e.message
      halt 400
    end
    # movie = Movie.find_by(moviename: params[:name])
    # if movie
    #   # return "find"+params[:name]
    #   # redirect "/api/v2/moviechecked/#{params[:name]}"
    #   movie.movieinfo
    # else
    #   movie = Movie.new
    #   movie.moviename = params[:name]
    #   movie.movieinfo = get_movie_info(params[:name]).to_json
    #   movie.save
    #   movie.movieinfo
    # end
    movie = Movie.find_by(moviename: req['movie'])
    if movie.nil?
      movie = Movie.new
      movie.moviename = req['movie']
      movie.movieinfo = get_movie_info(req['movie']).to_json
      movie.save
    end

    redirect "/api/v2/moviechecked/#{movie.id}"
  end

  get '/api/v2/moviechecked/:id' do
    content_type :json, charset: 'utf-8'

    movie = Movie.find(params[:id])
    logger.info "result: #{movie.movieinfo}\n"
    movie.movieinfo
  end

  delete '/api/v2/moviechecked/:id' do
    Movie.destroy(params[:id])
  end

  get '/api/v2/:type/:category.json' do
    content_type :json, charset: 'utf-8'

    if @data = Theater.find_by(category: params[:category])
      @data = {
        'content_type' => @data.content_type,
        'category' => @data.category,
        'info' => JSON.parse(@data.content)
      }
      @data.to_json
    else
      data = params[:type] == 'info' ? get_infos(params[:category]) : \
      get_ranks(params[:category])
      theater = Theater.new
      theater.content_type = data['content_type']
      theater.category = data['category']
      theater.content = data['content'].to_json
      theater.save && data.to_json
    end
  end

  post '/api/v2/checktop' do
    content_type :json, charset: 'utf-8'
    req = JSON.parse(request.body.read)
    n = req['top']
    halt 400 unless req.any?
    halt 404 unless [*1..10].include? n
    topsum(n).to_json
  end

  get '/info/' do
    halt 400
  end
  # end
end
