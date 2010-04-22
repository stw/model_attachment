require 'test/unit'

require 'rubygems'
require 'active_record'

$:.unshift File.dirname(__FILE__) + '/../lib'
require File.dirname(__FILE__) + '/../init'

class Test::Unit::TestCase
end

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

# keep AR from printing schema statements
#$stdout = StringIO.new

def setup_db
  ActiveRecord::Base.logger
  ActiveRecord::Schema.define(:version => 1) do
    create_table :documents do |t|
      t.string :name
      t.string :file_name
      t.string :content_type
      t.integer :file_size
      t.timestamps
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |t|
    ActiveRecord::Base.connection.drop_table(t)
  end
end

class Document < ActiveRecord::Base
end

class DocumentNoResize < Document
  has_attachment :path => "/:domain/:folder/:document/"
end

class DocumentWithResize < Document
  has_attachment :path => "/:domain/:folder/:document/",
    :types => {
      :small => { :command => 'convert -geometry 100x100' } 
    }
end

class ModelAttachmentTest < Test::Unit::TestCase
  
  def setup
    setup_db
  end
  
  def teardown
    teardown_db
  end
  
  def test_creation
    document = Document.new
    assert_equal document.class.to_s, "Document"
  end
  
end

