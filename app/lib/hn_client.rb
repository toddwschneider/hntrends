class HnClient
  API_BASE_URL = "https://hacker-news.firebaseio.com/v0/item"
  FIRST_DATE = Date.new(2006, 10, 9)
  FIRST_DATE_WITH_EXACT_DATA = Date.new(2014, 11, 11)
  HN_FRONT_PAGE_URL_BASE = "https://news.ycombinator.com/front"
  ITEMS_PER_PAGE = 30
  MAX_PAGINATION_REQUESTS = 10

  RateLimited = Class.new(StandardError)

  def each_front_page_item(date:, min_score: nil, num_items: nil, sleep_seconds: 2)
    if date < FIRST_DATE || date > Date.yesterday
      raise "invalid date"
    end

    if date < FIRST_DATE_WITH_EXACT_DATA && (min_score.blank? || num_items.blank?)
      raise "min_score and num_items required before #{FIRST_DATE_WITH_EXACT_DATA}"
    end

    num_pages = [
      ((num_items&.to_f / ITEMS_PER_PAGE).ceil if num_items),
      MAX_PAGINATION_REQUESTS
    ].compact.min

    (1..num_pages).each do |page_number|
      query = {day: date, p: page_number}
      url = "#{HN_FRONT_PAGE_URL_BASE}?#{query.to_query}"

      request = HTTParty.get(url)

      raise RateLimited if request.forbidden?

      doc = Nokogiri::HTML(request.body)

      doc.css(".athing").each do |e|
        item = item_from_athing(e)

        next if min_score && item.score && item.score < min_score
        next if num_items && item.ranking && item.ranking > num_items
        next if item.ranking.blank? && e.at("> .title").blank?

        yield item
      end

      break if doc.at("a[rel='next']").blank?

      sleep sleep_seconds
    end
  end

  def item_from_athing(node)
    url = node.at(".storylink")&.attr("href")&.strip

    if url !~ /^http/i
      url = "https://news.ycombinator.com/#{url}"
    end

    begin
      parsed_url = Addressable::URI.parse(url)
      domain = parsed_url.domain
      domain_with_subdomain = parsed_url.host
    rescue Addressable::URI::InvalidURIError
    end

    score = extract_number_from_text(
      node.next.at(".score")&.text,
      default_value: 1
    )

    comments_count = extract_number_from_text(
      node.next.at("a:contains('comment')")&.text,
      default_value: 0
    )

    Hashie::Mash.new(
      hn_id: node["id"]&.to_i,
      ranking: node.at(".rank")&.text&.chomp(".")&.to_i,
      title: node.at(".storylink")&.text&.strip,
      url: url,
      domain: domain,
      domain_with_subdomain: domain_with_subdomain,
      submitted_by: node.next.at(".hnuser")&.text&.strip,
      score: score,
      comments_count: comments_count
    )
  end

  def extract_number_from_text(text, default_value: nil)
    return default_value unless text.present?
    text.squish.split(" ").first.gsub(",", "")&.to_i || default_value
  end

  def items(hn_ids, max_concurrency: 5)
    hydra = Typhoeus::Hydra.new(max_concurrency: max_concurrency)

    requests = hn_ids.map do |id|
      request = Typhoeus::Request.new("#{API_BASE_URL}/#{id}.json")
      hydra.queue(request)
      request
    end

    hydra.run

    results = requests.map do |request|
      next unless request.response.code == 200
      JSON.parse(request.response.body)
    end

    hn_ids.zip(results).to_h
  end
end
