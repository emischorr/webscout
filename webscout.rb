require 'rubygems'
require 'sinatra'
require 'erb'
require './tracker'

configure do
  require 'redis'
  redisUri = ENV["REDISTOGO_URL"] || 'redis://localhost:6379'
  uri = URI.parse(redisUri) 
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

  puts "Using synchronized workers!"
  set :sync_worker, ENV["SYNC_WORKER"]
end

helpers do  
  include Rack::Utils  
  alias_method :h, :escape_html
  def relative_time_ago(from_time)
    from_time = from_time.to_time unless from_time.class == Time
    distance_in_minutes = (((Time.now - from_time).abs)/60).round
    case distance_in_minutes
      when 0..1 then 'about a minute'
      when 2..44 then "#{distance_in_minutes} minutes"
      when 45..89 then 'about 1 hour'
      when 90..1439 then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
      when 1440..2879 then '1 day'
      when 2880..43199 then "#{(distance_in_minutes / 1440).round} days"
      when 43200..86399 then 'about 1 month'
      when 86400..525599 then "#{(distance_in_minutes / 43200).round} months"
      when 525600..1051199 then 'about 1 year'
      else "over #{(distance_in_minutes / 525600).round} years"
    end
  end
  def time_ago(unix_seconds)
    relative_time_ago(Time.at(unix_seconds.to_i))
  end
  def time(unix_seconds)
    Time.at(unix_seconds.to_i).strftime('%d/%m/%Y %H:%M')
  end
end

get '/' do
  erb :start
end

get '/trackers' do
  erb :index
end

get '/trackers/new' do
  erb :new
end

get '/trackers/:id' do
  @tracker = Tracker.find(params[:id])

  if @tracker
    erb :show
  else
    status 404
  end
end

get '/trackers/:id/edit' do
  @tracker = Tracker.find(params[:id])
  erb :edit
end

post '/trackers' do
  @tracker = Tracker.create(params[:tracker])
  if @tracker
    Tracker.start_worker(@tracker.id, settings.async_worker?)
    redirect to("/trackers/#{@tracker.id}")
  end
end

put '/trackers/:id' do
  @tracker = Tracker.find(params[:id])
  if @tracker.update(params[:tracker])
    redirect to("/trackers/#{@tracker.id}")
  end
end

delete '/trackers/:id' do
  @tracker = Tracker.find(params[:id])
  @tracker.destroy
end

get '/trackers/:id/check' do
  Tracker.start_worker(params[:id], settings.sync_worker?)
  status 200
end
