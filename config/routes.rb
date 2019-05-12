Rails.application.routes.draw do
  get "/hn_items/trends", to: "hn_items#trends"
  get "/hn_items/top_items", to: "hn_items#top_items"
  get "/hn_items/aggregate_stats", to: "hn_items#aggregate_stats"
  get "/hn_items", to: redirect("https://news.ycombinator.com")
  get "/hn_items/*anything", to: redirect("https://news.ycombinator.com")
end
