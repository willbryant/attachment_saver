require File.join(File.dirname(__FILE__), 'test_helper')
require 'mocha'
require 'datastores/in_column'

class InColumnDatastoreTest < Test::Unit::TestCase
  attr_accessor :data, :original_filename, :content_type
  
  DEFAULT_ATTACHMENT_OPTIONS = {}
  
  def self.attachment_options
    @@attachment_options ||= DEFAULT_ATTACHMENT_OPTIONS
  end

  include AttachmentSaver::DataStores::InColumn
  
  def setup
    @test_filename = File.join(RAILS_ROOT, "tmp", "test#{$$}.dat")
    @uploaded_data = nil
    @uploaded_file = nil
    @saved_to = nil
    self.data = nil
    self.original_filename = 'myfile.dat'
    self.content_type = 'application/octet-stream'
  end
  
  def random_data(length = nil)
    length = 512 + rand(2048) if length.nil?
    Array.new(length).collect {rand(256)} .pack('C*')
  end
  
  def save_attachment_test(expected_data)
    expects(:process_attachment?).times(1).returns(false)
    save_attachment
    
    assert !data.nil? && data != "", "no data saved"
    data.force_encoding("ascii-8bit") if data.respond_to?(:force_encoding)
    assert expected_data == data, "data stored doesn't match"
  end


  def test_save_attachment_for_data
    @uploaded_data = data = random_data
    @save_upload = true
    save_attachment_test(data)
  end
  
  def test_save_attachment_for_file
    data = random_data
    FileUtils.mkdir_p(File.dirname(@test_filename))
    File.open(@test_filename + '.src_file', 'wb+') do |file|
      file.write(data)
      @uploaded_file = file
      @save_upload = true
      save_attachment_test(data)
    end
  end
  
  def test_save_attachment_for_tempfile
    data = random_data
    FileUtils.mkdir_p(File.dirname(@test_filename))
    Tempfile.open('src_file', File.dirname(@test_filename)) do |file|
      file.write(data)
      @uploaded_file = file
      @save_upload = true
      save_attachment_test(data)
    end
  end
  
  
  def test_save_attachment_calls_processing
    @uploaded_data = expected_data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(true)
    expects(:process_attachment_with_wrapping).times(1).returns do |filename|
      assert expected_data == File.read(filename)
    end
    
    save_attachment
    
    assert expected_data == data
  end
  
  
  def test_save_attachment_without_upload
    expects(:process_attachment?).times(0)
    expects(:process_attachment).times(0)
    save_attachment
    assert_equal nil, data
  end
  
  
  def test_in_storage?
    @uploaded_data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(false)
    save_attachment
    
    assert_equal true, in_storage?
    self.data = nil
    assert_equal false, in_storage?
  end
end
