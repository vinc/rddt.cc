require 'yaml'

require 'dalli'
require 'memcachier'
require 'sass'
require 'slim'
require 'sinatra'
require 'sinatra/param'
require 'sinatra/partial'

require './reddit'

configure do
    enable :sessions
    set :slim, :pretty => true
    set :partial_template_engine, :slim
    #set :show_exceptions, false

    set :cache, Dalli::Client.new
    set :ttl, 60 * 30
    set :editions, YAML.load_file('editions.yaml')
end

before do
    expires settings.ttl, :public, :must_revalidate
    session[:editions] ||= settings.editions
end

get '/' do
    slim :index, locals: { editions: session[:editions] }
end

get '/r/:subreddits/?:sort?' do
    param :sort, String,
        in: ['hot', 'top', 'new', 'controversial'], default: 'hot'
    param :t, String,
        in: ['hour', 'day', 'week', 'month', 'year', 'all'], default: 'day'
    param :limit, Integer,
        in: (1..100), default: 20

    key_entries = "subreddits:#{request.fullpath}"
    entries = settings.cache.get(key_entries)
    if entries.nil?
        key_wait = "wait"
        time_wait = 2
        wait = settings.cache.get(key_wait)
        unless wait.nil?
            remaining = '%.6f' % (time_wait + wait - Time.now.to_f)
            halt(500, slim(:ratelimited, locals: {wait: remaining}))
        end

        subreddits = params[:subreddits].split '+'
        entries = Reddit.new(subreddits).entries(params)

        # Cache query
        settings.cache.set(key_entries, entries, settings.ttl)

        # Wait 'time_wait' seconds before next query
        settings.cache.set(key_wait, Time.now.to_f, time_wait)
    end
    slim :subreddits, locals: {entries: entries}
end

get '/select' do
    if params.empty?
        session.delete(:editions)
    else
        session[:editions] = params.map do |k, v|
            {
                title: k,
                subreddits: (v || '').split(' ')
            }
        end
    end
    redirect '/', 303
end

get '/style.css' do
    expires 60 * 60 * 24 * 31, :public, :must_revalidate
    scss :style
end

error do
    status 500
    case env['sinatra.error']
    when SocketError, Errno::ECONNREFUSED
        message = "Looks like our tube does not connect to Reddit"
    when Dalli::RingError
        message = "Looks like our cache servers do not want to run."
    else
        message = "Looks like some kind of internal server error."
    end
    slim :error, locals: {
        message: message,
        image: 'error_500.png'
    }
end

not_found do
    slim :error, locals: {
        message: "You requested something that cannot be found.",
        image: 'error_404.png'
    }
end
