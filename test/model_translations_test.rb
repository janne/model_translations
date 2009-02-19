require 'test_helper'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :posts do |t|
      t.timestamps
    end
    create_table :post_translations do |t|
      t.string     :locale
      t.references :post
      t.string     :title
      t.text       :text
      t.timestamps
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Post < ActiveRecord::Base
  translates :title, :text
end

class ModelTranslationsTest < ActiveSupport::TestCase
  def setup
    setup_db
    I18n.locale = I18n.default_locale = :en
    Post.create(:title => 'English title', :text => 'Text')
  end

  def teardown
    teardown_db
  end

  test "database setup" do
    assert Post.count == 1
  end

  test "allow translation" do
    I18n.locale = :sv
    Post.first.update_attribute :title, 'Svensk titel'
    assert Post.first.title == 'Svensk titel'
    I18n.locale = :en
    assert Post.first.title == 'English title'
  end

  test "assert fallback to default" do
    assert Post.first.title == 'English title'
    I18n.locale = :sv
    assert Post.first.title == 'English title'
  end
end
