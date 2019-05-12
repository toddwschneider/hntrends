class HnTrendsCalculator
  ALLOWED_TIME_PERIODS = %w(year quarter month)
  DEFAULT_TIME_PERIOD = "year"
  DEFAULT_MIN_DAYS = {
    "year" => 60,
    "quarter" => 30,
    "month" => 10
  }
  DEFAULT_START_DATE = Date.new(2007, 1, 1)

  TRENDS_JOIN_CONDITIONS = {
    "text" => "i.tsv @@ websearch_to_tsquery('simple', t.term)",
    "exact_case_insensitive" => "i.title ~* ('\\y' || t.term || '\\y')",
    "exact_case_sensitive" => "i.title ~ ('\\y' || t.term || '\\y')",
    "domain" => "lower(i.domain) = lower(t.term)",
    "domain_with_subdomain" => "lower(i.domain_with_subdomain) = lower(t.term)",
    "submitted_by" => "i.submitted_by = t.term"
  }
  ALLOWED_SEARCH_METHODS = TRENDS_JOIN_CONDITIONS.keys
  DEFAULT_SEARCH_METHOD = "text"

  MAX_NUMBER_OF_TERMS = 8

  attr_reader :terms, :time_period, :search_method

  def initialize(terms:, time_period: DEFAULT_TIME_PERIOD, search_method: DEFAULT_SEARCH_METHOD)
    unless ALLOWED_TIME_PERIODS.include?(time_period)
      raise ArgumentError, "invalid time period"
    end

    unless ALLOWED_SEARCH_METHODS.include?(search_method)
      raise ArgumentError, "invalid search method"
    end

    terms = Array.wrap(terms).uniq

    if terms.blank?
      raise ArgumentError, "terms can't be empty"
    end

    if terms.size > MAX_NUMBER_OF_TERMS
      raise ArgumentError, "max #{MAX_NUMBER_OF_TERMS} terms allowed"
    end

    @terms = terms
    @time_period = time_period
    @search_method = search_method
  end

  def trends_query(start_date: DEFAULT_START_DATE, min_days: nil)
    bind_vars = {
      time_period: time_period,
      min_days: (min_days || DEFAULT_MIN_DAYS.fetch(time_period)).to_i,
      start_date: start_date.to_date
    }

    terms.each.with_index do |term, i|
      bind_vars[:"term_#{i}"] = term
    end

    terms_values_sql = terms.map.with_index do |_, i|
      "(:term_#{i}, #{i.to_i})"
    end.join(", ")

    query = <<-SQL
      WITH terms (term, sort_order) AS (
        VALUES #{terms_values_sql}
      ),
      term_counts AS (
        SELECT
          t.term,
          date(date_trunc(:time_period, i.front_page_date)) AS date,
          COUNT(*) AS items_count,
          SUM(i.score) AS items_score
        FROM hn_items i
          INNER JOIN terms t
            ON #{TRENDS_JOIN_CONDITIONS.fetch(search_method)}
        WHERE i.front_page_date >= :start_date
        GROUP BY 1, 2
      )
      SELECT
        t.term,
        hic.date,
        coalesce(tc.items_count, 0) AS items_count,
        coalesce(tc.items_score, 0) AS items_score,
        coalesce(tc.items_count, 0)::numeric / hic.total_items AS frac_items,
        coalesce(tc.items_score, 0)::numeric / hic.total_score AS frac_score
      FROM hn_item_counts hic
        CROSS JOIN terms t
        LEFT JOIN term_counts tc
          ON hic.date = tc.date
          AND t.term = tc.term
      WHERE hic.period = :time_period
        AND hic.days_counted >= :min_days
        AND hic.date >= :start_date
      ORDER BY t.sort_order, hic.date
    SQL

    headers = %i(date items_count items_score frac_items frac_score)

    grouped_rows = HnItem.find_by_sql([query, bind_vars]).group_by(&:term)

    grouped_rows.map do |term, rows|
      cols = rows.map do |row|
        [
          row.date.to_datetime.to_i * 1000,
          row.items_count,
          row.items_score,
          row.frac_items.to_f.round(7),
          row.frac_score.to_f.round(7)
        ]
      end.transpose

      {term: term}.merge(headers.zip(cols).to_h)
    end
  end

  def top_items(date: nil, items_per_term: nil)
    if items_per_term.blank?
      items_per_term = terms.size == 1 ? 10 : 3
    end

    bind_vars = {
      items_per_term: items_per_term.to_i,
      time_period: time_period
    }

    bind_vars[:date] = date.to_date if date

    terms.each.with_index do |term, i|
      bind_vars[:"term_#{i}"] = term
    end

    terms_values_sql = terms.map.with_index do |_, i|
      "(:term_#{i}, #{i.to_i})"
    end.join(", ")

    if date.present?
      where_sql = <<-SQL
        WHERE date(date_trunc(:time_period, i.front_page_date)) = :date
      SQL
    end

    query = <<-SQL
      WITH terms (term, sort_order) AS (
        VALUES #{terms_values_sql}
      ),
      matching_items AS (
        SELECT
          t.term,
          t.sort_order,
          i.hn_id,
          i.title,
          i.url,
          i.domain,
          i.submitted_by,
          i.score,
          i.comments_count,
          i.front_page_date,
          row_number() OVER (PARTITION BY t.term ORDER BY i.score DESC, i.submitted_at ASC) AS row_number
        FROM hn_items i
          INNER JOIN terms t
            ON #{TRENDS_JOIN_CONDITIONS.fetch(search_method)}
        #{where_sql}
      )
      SELECT
        *,
        ts_headline(
          'simple',
          title,
          websearch_to_tsquery('simple', term),
          'StartSel = <mark>, StopSel = </mark>'
        ) AS highlighted_title
      FROM matching_items
      WHERE row_number <= :items_per_term
      ORDER BY sort_order, row_number
    SQL

    HnItem.find_by_sql([query, bind_vars]).group_by(&:term).map do |term, items|
      {
        term: term,
        items: items.map do |i|
          {
            hn_id: i.hn_id,
            title: i.highlighted_title,
            url: i.url,
            domain: i.domain,
            submitted_by: i.submitted_by,
            score: i.score,
            comments_count: i.comments_count,
            front_page_date: i.front_page_date
          }
        end
      }
    end
  end
end
