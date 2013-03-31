require 'yaml'

require 'dalli'
require 'memcachier'
require 'sass'
require 'slim'
require 'sinatra'
require 'sinatra/param'
require 'sinatra/partial'
require 'sinatra/reloader' if development?

require './reddit'

class String
    # Return a new String with 'ly' removed from the end of str (if present).
    # If str contains 'i' like in 'daily', then it will be changed by a 'y'
    # like in 'day'.
    def chomply
        self[0..-3].tr('i', 'y')
    end
end

configure do
    enable :sessions
    if development?
        set :slim, :pretty => true
        set :css_style => :expanded
    else
        set :css_style => :compressed
    end
    set :partial_template_engine, :slim
    #set :show_exceptions, false

    set :cache, Dalli::Client.new
    set :ttl, 60 * 30
    set :static_cache_control, [:public, :max_age => 60 * 60 * 24 * 30]

    set :editions, YAML.load_file('editions.yaml')
    set :period, 'daily'
end

before do
    expires settings.ttl, :public, :must_revalidate
    session[:editions] ||= settings.editions
    session[:period] ||= settings.period
end

get '/' do
    slim :index, locals: {
        t: session[:period].chomply,
        period: session[:period],
        editions: session[:editions]
    }
end

get '/r/:subreddits/?:sort?' do
    param :sort, String, default: 'hot',
        in: ['hot', 'top', 'new', 'controversial']
    param :t, String, default: session[:period].chomply,
        in: ['hour', 'day', 'week', 'month', 'year', 'all']
    param :limit, Integer, default: 20,
        in: (1..100)

    key_entries = "subreddits:#{request.fullpath}"
    entries = settings.cache.get(key_entries)
    if entries.nil?
        key_wait = 'wait'
        time_wait = 2
        wait = settings.cache.get(key_wait)
        unless wait.nil?
            remaining = '%.6f' % (time_wait + wait - Time.now.to_f)
            halt(500, slim(:ratelimited, locals: {
                period: session[:period],
                wait: remaining
            }))
        end

        subreddits = params[:subreddits].split '+'
        entries = Reddit.new(subreddits).entries(params)

        # Cache query
        settings.cache.set(key_entries, entries, settings.ttl)

        # Wait 'time_wait' seconds before next query
        settings.cache.set(key_wait, Time.now.to_f, time_wait)
    end
    slim :subreddits, locals: {
        period: session[:period],
        entries: entries
    }
end

get '/settings' do
    slim :settings, locals: {
        period: session[:period],
        editions: session[:editions]
    }
end

post '/settings' do
    param :period, String, default: settings.period,
        in: ['hourly', 'daily', 'weekly', 'monthly', 'yearly']

    session[:period] = params[:period]

    # The subreddits array is made of strings
    # containing subreddits separated by space
    subreddits = params[:subreddits].map {|x| x.split}

    # Associate each title with an array of subreddits
    editions = Hash[params[:titles].zip(subreddits)]

    # The form inputs could be empty
    editions.delete_if {|k, v| k.empty? || v.empty?}

    session[:editions] = (editions.empty? ? settings.editions : editions)

    slim :settings, locals: {
        period: session[:period],
        editions: session[:editions]
    }
end

get '/select' do # FIXME: should be removed
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

get '/styles/screen.css' do
    expires 60 * 60 * 24 * 31, :public, :must_revalidate
    scss :screen, :style => settings.css_style
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
        period: session[:period],
        message: message,
        image: 'error_500.png'
    }
end

not_found do
    slim :error, locals: {
        period: session[:period],
        message: "You requested something that cannot be found.",
        image: 'error_404.png'
    }
end
