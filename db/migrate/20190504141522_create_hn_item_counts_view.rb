class CreateHnItemCountsView < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      CREATE MATERIALIZED VIEW hn_item_counts AS
      SELECT
        'year'::text AS period,
        date(date_trunc('year', front_page_date)) AS date,
        COUNT(*) AS total_items,
        SUM(score) AS total_score,
        COUNT(DISTINCT front_page_date) AS days_counted
      FROM hn_items
      GROUP BY 1, 2

      UNION

      SELECT
        'quarter'::text AS period,
        date(date_trunc('quarter', front_page_date)) AS date,
        COUNT(*) AS total_items,
        SUM(score) AS total_score,
        COUNT(DISTINCT front_page_date) AS days_counted
      FROM hn_items
      GROUP BY 1, 2

      UNION

      SELECT
        'month'::text AS period,
        date(date_trunc('month', front_page_date)) AS date,
        COUNT(*) AS total_items,
        SUM(score) AS total_score,
        COUNT(DISTINCT front_page_date) AS days_counted
      FROM hn_items
      GROUP BY 1, 2

      UNION

      SELECT
        'all_time'::text AS period,
        max(front_page_date) AS date,
        COUNT(*) AS total_items,
        SUM(score) AS total_score,
        COUNT(DISTINCT front_page_date) AS days_counted
      FROM hn_items

      ORDER BY 1, 2;
    SQL

    add_index :hn_item_counts, %i(period date), unique: true
  end

  def down
    execute "DROP MATERIALIZED VIEW hn_item_counts"
  end
end
