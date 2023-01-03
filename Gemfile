source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.6.6'

gem 'rails', '~> 5.2.3'

gem 'addressable', '~> 2.8'
gem 'bootsnap', '>= 1.1.0', require: false
gem 'clockwork', '~> 2.0'
gem 'delayed_job_active_record', '~> 4.1'
gem 'foreman', '~> 0.85'
gem 'hashie', '~> 3.6'
gem 'httparty', '~> 0.21'
gem 'nokogiri', '~> 1.13'
gem 'pg', '>= 0.18', '< 2.0'
gem 'puma', '~> 4.3'
gem 'sass-rails', '~> 5.0'
gem 'typhoeus', '~> 1.3'
gem 'uglifier', '>= 1.3.0'

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  gem 'chromedriver-helper'
end

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
