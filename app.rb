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
    # Return a new String with 'ly' appened to str.
    # If str contains 'y' like in 'day', then it will be changed to a 'i'
    # like in 'daily'.
    def ly
        self.tr('y', 'i') + 'ly'
    end

    # Return a new String with 'ly' removed from the end of str (if present).
    # If str contains 'i' like in 'daily', then it will be changed to a 'y'
    # like in 'day'.
    def chomply
        self[0..-3].tr('i', 'y')
    end
end

configure :development do
    set :slim, :pretty => true
    set :css_style => :expanded
end

configure :production do
    set :css_style => :compressed
end

configure do
    set :partial_template_engine, :slim
    #set :show_exceptions, false

    set :cache, Dalli::Client.new
    set :ttl, 60 * 30
    set :static_cache_control, [:public, :max_age => 60 * 60 * 24 * 30]

    set :editions, YAML.load_file('editions.yml')
    set :period, 'daily'
end

before do
    expires settings.ttl, :public, :must_revalidate
    headers 'X-UA-Compatible' => 'IE=edge,chrome=1'
end

get '/' do
    param :t, String, default: settings.period.chomply,
        in: ['hour', 'day', 'week', 'month', 'year', 'all']

    slim :index, locals: {
        t: params[:t],
        period: params[:t].ly,
        editions: settings.editions
    }
end

get '/r/:subreddits/?:sort?' do
    param :sort, String, default: 'hot',
        in: ['hot', 'top', 'new', 'controversial']
    param :t, String, default: settings.period.chomply,
        in: ['hour', 'day', 'week', 'month', 'year', 'all']
    param :limit, Integer, default: 100,
        in: (1..100)

    key_entries = "subreddits:#{request.fullpath}"
    entries = settings.cache.get(key_entries)
    if entries.nil?
        key_wait = 'wait'
        time_wait = 2
        wait = settings.cache.get(key_wait)
        unless wait.nil?
            remaining = '%.6f' % (time_wait + wait - Time.now.to_f)
            halt(503, slim(:ratelimited, locals: {
                period: settings.period,
                wait: remaining
            }))
        end

        subreddits = params[:subreddits].split(/[+\s]/)
        entries = Reddit.new(subreddits).entries(params)

        msg = 'Looks like Reddit is unavailable at the moment.'
        halt(503, msg) if entries.empty?

        # Cache query
        settings.cache.set(key_entries, entries, settings.ttl)

        # Wait 'time_wait' seconds before next query
        settings.cache.set(key_wait, Time.now.to_f, time_wait)
    end
    slim :subreddits, locals: {
        period: settings.period,
        entries: entries
    }
end

get '/settings' do
    slim :settings, locals: {
        period: settings.period,
        editions: settings.editions,
        message: ''
    }
end

post '/settings' do
    param :period, String, default: settings.period,
        in: ['hourly', 'daily', 'weekly', 'monthly', 'yearly']
    param :subreddits, Array, required: true
    param :titles, Array, required: true

    # The subreddits array is made of strings
    # containing subreddits separated by space
    subreddits = params[:subreddits].map {|x| x.split}

    # Associate each title with an array of subreddits
    editions = Hash[params[:titles].zip(subreddits)]

    # The form inputs could be empty
    editions.delete_if {|k, v| k.empty? || v.empty?}

    if editions.empty?
        message = 'Default settings restored'
        editions = settings.editions
    else
        # TODO
        message = ''
    end

    slim :settings, locals: {
        period: params[:period],
        editions: editions,
        message: message
    }
end

get '/partials/*' do |view|
    slim :"partials/#{view}", locals: {
        t: '{{t}}',
        edition: '{{edition}}',
        subreddit: '{{subreddit}}',
        subreddits: ['{{subreddits}}'],
    }
end

get '/styles/screen.css' do
    expires 60 * 60 * 24 * 31, :public, :must_revalidate
    scss :'styles/screen', :style => settings.css_style
end

error 400..599 do
    unless response.body[0] =~ /<html>/
        slim :error, locals: {
            period: settings.period,
            message: response.body[0],
            image: 'error_500.png'
        }
    end
end

error do
    case env['sinatra.error']
    when SocketError, Errno::ECONNREFUSED
        message = 'Looks like our tube does not connect to Reddit'
        status 503
    when Dalli::RingError
        message = 'Looks like our cache servers do not want to run.'
        status 503
    else
        message = 'Looks like some kind of internal server error.'
        status 500
    end
    slim :error, locals: {
        period: settings.period,
        message: message,
        image: 'error_500.png'
    }
end

not_found do
    slim :error, locals: {
        period: settings.period,
        message: 'You requested something that cannot be found.',
        image: 'error_404.png'
    }
end
