# start sidekiq with
# sidekiq -r ./webscout.rb
require 'sidekiq'

class ScoutWorker
  include Sidekiq::Worker

  def perform(tracker_id)
    Tracker.start_worker(tracker_id, true)
  end
end