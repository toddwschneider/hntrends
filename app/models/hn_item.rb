class HnItem < ApplicationRecord
  validates :hn_id, presence: true, uniqueness: true
  validates :front_page_date, presence: true
  validates :front_page_ranking, presence: true

  class << self
    def cache_all_dates(from_date:, to_date:, interval: 1.minute)
      now = Time.zone.now

      (from_date..to_date).each.with_index do |date, i|
        run_at = now + (i * interval)

        args = {date: date}

        if date < HnClient::FIRST_DATE_WITH_EXACT_DATA
          args[:min_score] = 3
          args[:num_items] = date.on_weekday? ? 115 : 80
        end

        delay(run_at: run_at).cache_front_page_items_without_delay(args)
      end
    end
    handle_asynchronously :cache_all_dates

    def cache_front_page_items(date:, num_items: nil, min_score: nil, sleep_seconds: 2)
      args = {
        date: date,
        num_items: num_items,
        min_score: min_score,
        sleep_seconds: sleep_seconds
      }

      client.each_front_page_item(args) do |i|
        item = find_or_initialize_by(hn_id: i.hn_id)

        item.front_page_date = date
        item.front_page_ranking = i.ranking
        item.title = i.title
        item.url = i.url
        item.domain = i.domain
        item.domain_with_subdomain = i.domain_with_subdomain
        item.submitted_by = i.submitted_by
        item.score = i.score
        item.comments_count = i.comments_count

        item.save!
      end

      cache_api_info(date: date, all_items: true)

      refresh_materialized_view
    end
    handle_asynchronously :cache_front_page_items

    def cache_api_info(date: nil, min_hn_id: nil, max_hn_id: nil, all_items: false, batch_size: 50)
      scoped = select(:id)
      scoped = scoped.where(front_page_date: date) if date
      scoped = scoped.where("hn_id >= ?", min_hn_id) if min_hn_id
      scoped = scoped.where("hn_id <= ?", max_hn_id) if max_hn_id
      scoped = scoped.where(submitted_at: nil) unless all_items

      scoped.find_in_batches(batch_size: batch_size) do |batch|
        cache_api_info_for_batch(batch.map(&:id))
      end
    end
    handle_asynchronously :cache_api_info

    def cache_api_info_for_batch(ids)
      items = where(id: ids)
      api_responses = client.items(items.map(&:hn_id))

      items.each do |item|
        next unless r = api_responses[item.hn_id]

        item.submitted_at = Time.zone.at(r.fetch("time"))
        item.item_type = r.fetch("type")
        item.score = r["score"] if r["score"]
        item.comments_count = r["descendants"] if r["descendants"]

        item.save!
      end
    end
    handle_asynchronously :cache_api_info_for_batch

    def refresh_materialized_view
      connection.execute <<-SQL
        REFRESH MATERIALIZED VIEW CONCURRENTLY hn_item_counts;
      SQL
    end
    handle_asynchronously :refresh_materialized_view
  end

  def cache_api_info
    self.class.cache_api_info_for_batch_without_delay(hn_id)
  end
  handle_asynchronously :cache_api_info

  def self.aggregate_stats
    query = <<-SQL
      SELECT date, total_items
      FROM hn_item_counts
      WHERE period = 'all_time'
    SQL

    find_by_sql(query).first.as_json.except("id")
  end

  private

  def self.client
    @client ||= HnClient.new
  end
end
