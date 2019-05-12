class CreateHnItems < ActiveRecord::Migration[5.2]
  def up
    enable_extension :pg_trgm

    create_table :hn_items do |t|
      t.bigint :hn_id, null: false
      t.date :front_page_date, null: false
      t.integer :front_page_ranking, null: false
      t.text :submitted_by
      t.datetime :submitted_at
      t.text :title
      t.text :url
      t.integer :score
      t.integer :comments_count
      t.text :item_type
      t.text :domain
      t.text :domain_with_subdomain
      t.tsvector :tsv
      t.timestamps
    end

    add_index :hn_items, :hn_id, unique: true

    add_index :hn_items, :domain
    add_index :hn_items, :domain_with_subdomain
    add_index :hn_items, "lower(domain)"
    add_index :hn_items, "lower(domain_with_subdomain)"

    add_index :hn_items, :submitted_by

    add_index :hn_items, :tsv, using: :gin
    add_index :hn_items, :title, using: :gin, opclass: {title: :gin_trgm_ops}

    execute <<-SQL
      CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
      ON hn_items FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(tsv, 'pg_catalog.simple', title);
    SQL
  end

  def down
    drop_table :hn_items
    disable_extension :pg_trgm
  end
end
