class HnItemsController < ApplicationController
  before_action :set_headers, only: %i(trends top_items aggregate_stats)

  def trends
    expires_in 1.hour, public: true

    render json: calculator.trends_query
  end

  def top_items
    expires_in 1.hour, public: true

    render json: calculator.top_items(date: date)
  end

  def aggregate_stats
    expires_in 12.hours, public: true

    render json: HnItem.aggregate_stats
  end

  private

  def set_headers
    headers["Access-Control-Allow-Origin"] = "*"
  end

  def calculator
    HnTrendsCalculator.new(
      terms: search_terms,
      time_period: time_period,
      search_method: search_method
    )
  end

  def search_terms
    params[:q].split(",").map(&:squish).select(&:present?)
  end

  def time_period
    if HnTrendsCalculator::ALLOWED_TIME_PERIODS.include?(params[:t])
      params[:t]
    else
      HnTrendsCalculator::DEFAULT_TIME_PERIOD
    end
  end

  def search_method
    if %w(domain domain_with_subdomain submitted_by).include?(params[:f])
      params[:f]
    elsif %w(text exact_case_insensitive exact_case_sensitive).include?(params[:s])
      params[:s]
    else
      HnTrendsCalculator::DEFAULT_SEARCH_METHOD
    end
  end

  def date
    Date.parse(params[:d]) if params[:d].present?
  end
end
