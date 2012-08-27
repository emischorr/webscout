require 'nokogiri'
require 'open-uri'
require './scout_worker'

class Tracker
  attr_accessor :id, :url, :name, :query, :callback, :last_check_at

  def initialize(values)
    values.each_pair do |key, val|
      instance_variable_set('@'+key.to_s, val)
    end
  end

  def self.find(id)
    tracker = REDIS.hgetall key(id)
    tracker.empty? ? nil : new(tracker.merge({"id" => id}))
  end

  def self.create(values)
    new(values).save
  end

  def destroy
    REDIS.del key
    nil
  end

  def update(values)
    values.each_pair do |key, val|
      instance_variable_set('@'+key.to_s, val)
    end
    save
  end

  def save
    if valid?
      @id ||= self.class.generate_id
      REDIS.hmset(key, "url", @url, "query", @query, "name", @name, "callback", @callback)
      self
    else
      nil
    end
  end

  def valid?
    @url && @query
  end

  def changes(limit=0, start=1)
    REDIS.zrevrange(changes_key, start-1, start-1+limit-1)
  end



  def self.start_worker(tracker_id, sync=false)
    if sync
      tracker = Tracker.find(tracker_id)
      tracker.check_document if tracker && tracker.last_check_at.to_i < Time.now.to_i - MIN_TRACK_INTERVAL*60
    else
      ScoutWorker.perform_async tracker_id
    end
  end

  def check_document
    doc = Nokogiri::HTML(open(@url))
    text = doc.search(@query).text
    # add text to sorted set only if it doesn't exist yet. 
    # (Redis SortedSet would automaticly inhibit adding repeating members, but we don't want to reset the timestamp)
    REDIS.zadd(changes_key, Time.now.to_i, text) unless REDIS.zscore(changes_key, text)
    REDIS.hset(key, "last_check_at", Time.now.to_i)
    text
  end

  def display_name
    @name || @url
  end



  private

    def self.generate_id
      # loop prevents this method from returning a value that is already asigned to a url
      loop do
        next_id = seed
        return next_id unless self.find(next_id)
      end
    end
    
    def self.seed
      salt = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".split('')
      my_id = ''
      1.upto(6) do
        my_id += salt[(rand * salt.length).floor]
      end
      my_id
    end

    def self.key(id)
      "tracker:#{id}"
    end

    def key
      self.class.key(@id)
    end

    def self.changes_key(id)
      "tracker:#{id}:changes"
    end

    def changes_key
      self.class.changes_key(@id)
    end

end