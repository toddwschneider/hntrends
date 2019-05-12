# Hacker News Front Page Trends

A Ruby on Rails app that stores [Hacker News](https://news.ycombinator.com) items that have appeared on the front page, and exposes a few JSON API endpoints that let users search for terms, domains, and users to see how popular they have been on the HN front page over time.

[Click here for a live dashboard that uses this API](https://toddwschneider.com/dashboards/hacker-news-trends/)

## Screenshot

[![screenshot](https://user-images.githubusercontent.com/70271/57560906-f10c2f00-7356-11e9-81ba-0271c4241262.png)](https://toddwschneider.com/dashboards/hacker-news-trends/?q=statistics%2C+"machine+learning"+or+ML%2C+"artificial+intelligence"+or+AI&f=title&s=text&m=frac_items&t=year)

## Caveat

HN only provides the exact list of front page items for dates since 11/11/2014, so anything before then is an estimate. For earlier dates, I used a heuristic of sorting by score and taking the top 115 items on weekdays, 80 on weekends, subject to a minimum of 3 points. This definitely isn’t perfect, for example:

- it excludes job posts before 11/11/2014 since they always have 1 point
- items with high scores don’t always get to the front page
- it’s possible that HN has changed its algorithm over time to promote faster or slower front page turnover

But it should be a decent approximation, and the code could also be modified to use other heuristics. It would also probably be an improvement to fetch all job posts from pre 11/11/14 via the [HN API](https://github.com/HackerNews/API).

## Structure

There are 3 files of interest:

1. `app/lib/hn_client.rb` - code to collect front page data via the HN website and [API](https://github.com/HackerNews/API)
2. `app/models/hn_item.rb` - code that uses the `HnClient` to store the appropriate records in PostgreSQL database
3. `app/lib/hn_trends_calculator.rb` - code to calculate trends over time and top items for given search terms. The trends endpoint returns 4 metrics for each term/date:
    1. Fraction of all front page items
    2. Number of all front page items
    3. Fraction of total front page score, i.e. the total score of items matching the search term divided by the total score of all front page items
    4. Front page score

The trends calculator supports searching titles, domains (with or without subdomains), and usernames. When searching by title, there are 3 different search styles:

1. Web search uses PostgreSQL [full text search](https://www.postgresql.org/docs/11/textsearch.html), in particular the [websearch_to_tsquery()](https://www.postgresql.org/docs/11/textsearch-controls.html#TEXTSEARCH-PARSING-QUERIES) function and [GIN indexes](https://www.postgresql.org/docs/11/textsearch-tables.html). By default the tsv column uses the `simple` text search configuration
2. Case-insensitive exact title match uses the `~*` PostgreSQL [regular expression](https://www.postgresql.org/docs/11/functions-matching.html#FUNCTIONS-POSIX-REGEXP) operator, combined with a [trigram index](https://www.postgresql.org/docs/11/pgtrgm.html#id-1.11.7.40.7)
3. Case-sensitive exact title match is the same as #2, but uses the `~` regex operator instead of `~*`

## Requirements

Requires PostgreSQL 11+, since `websearch_to_tsquery()` was added in version 11
