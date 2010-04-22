# 
#  model_attachment_test.rb
#  
#  Created by Stephen Walker on 2010-04-22.
#  Copyright 2010 Stephen Walker. All rights reserved.
# 

require 'test/unit'

require 'rubygems'
require 'active_record'
require 'fileutils'

$:.unshift File.dirname(__FILE__) + '/../lib'
require File.dirname(__FILE__) + '/../init'

RAILS_ROOT = File.dirname(__FILE__)

class Test::Unit::TestCase
end

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

# keep AR from printing schema statements
$stdout = StringIO.new

def setup_db
  FileUtils.rm(RAILS_ROOT + "/test.log")
  ActiveRecord::Base.logger = Logger.new(RAILS_ROOT + "/test.log")
  
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
  def domain
    "bbs"
  end
  
  def folder
    "1"
  end
  
  def document
    "1"
  end
end

class DocumentDefault < Document
  has_attachment
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
  
  def test_no_resize_creation
    document = DocumentNoResize.new
    assert_equal document.class.to_s, "DocumentNoResize"
  end
  
  def test_with_resize
    document = DocumentWithResize.new
    assert_equal document.class.to_s, "DocumentWithResize"
  end
  
  def test_save_default
    FileUtils.cp(RAILS_ROOT + "/assets/test.jpg", RAILS_ROOT + "/assets/test1.jpg")
    file = File.open(RAILS_ROOT + "/assets/test1.jpg")
    
    document = DocumentDefault.new(:name => "Test", :file_name => file)
    document.save
    
    assert_equal "test1.jpg", document.file_name
    assert_equal "image/jpeg", document.content_type
    
    assert File.exists?(RAILS_ROOT + "/system/test/test1.jpg")
    
    document.destroy
    assert !File.exists?(RAILS_ROOT + "/system/test/test1.jpg")
  end
  
  def test_save_with_no_resize
    FileUtils.cp(RAILS_ROOT + "/assets/test.jpg", RAILS_ROOT + "/assets/test1.jpg")
    file = File.open(RAILS_ROOT + "/assets/test1.jpg")
    
    document = DocumentNoResize.new(:name => "Test", :file_name => file)
    document.save
    
    assert_equal document.file_name, "test1.jpg"
    assert_equal document.content_type, "image/jpeg"
    
    assert File.exists?(RAILS_ROOT + "/system/bbs/1/1/test1.jpg")
    
    document.destroy
    assert !File.exists?(RAILS_ROOT + "/system/bbs/1/1/test1.jpg")
  end
  
  def test_save_with_resize
    FileUtils.cp(RAILS_ROOT + "/assets/test.jpg", RAILS_ROOT + "/assets/test2.jpg")
    file = File.open(RAILS_ROOT + "/assets/test2.jpg")
    
    document = DocumentWithResize.new(:name => "Test", :file_name => file)
    document.save
    
    assert_equal document.file_name, "test2.jpg"
    assert_equal document.content_type, "image/jpeg"
    
    assert File.exists?(RAILS_ROOT + "/system/bbs/1/1/test2.jpg")
    assert File.exists?(RAILS_ROOT + "/system/bbs/1/1/test2_small.jpg")
    
    document.destroy
    assert !File.exists?(RAILS_ROOT + "/system/bbs/1/1/test2.jpg")
    assert !File.exists?(RAILS_ROOT + "/system/bbs/1/1/test2_small.jpg")  
  end

end

