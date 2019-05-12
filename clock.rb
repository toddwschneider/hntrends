require "clockwork"
require_relative "./config/boot"
require_relative "./config/environment"

module Clockwork
  configure do |config|
    config[:tz] = "UTC"
  end

  every(1.day, "create hn_items", at: "01:00") do
    HnItem.cache_all_dates(
      from_date: 4.days.ago.to_date,
      to_date: Date.yesterday
    )
  end

  every(1.day, "defensively refresh materialized view", at: "02:00") do
    HnItem.refresh_materialized_view
  end
end
