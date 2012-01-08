require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require 'attachment_saver'

class AttachmentSaverTest < Test::Unit::TestCase
  def test_split_filename
    assert_equal ['a', nil],        AttachmentSaver::split_filename('a')
    assert_equal ['a', ''],         AttachmentSaver::split_filename('a.')
    assert_equal ['a', 'b'],        AttachmentSaver::split_filename('a.b')
    assert_equal ['a', 'bcde'],     AttachmentSaver::split_filename('a.bcde')
    assert_equal ['a.bcde', 'fgh'], AttachmentSaver::split_filename('a.bcde.fgh')
  end
  
  class SomeModel
    include AttachmentSaver::InstanceMethods
    class_attribute :attachment_options

    attr_accessor :size, :content_type, :original_filename
  end
  
  module TempfileAttributes
    def original_filename
      "test.txt"
    end
    
    def content_type
      "text/plain"
    end
  end
  
  module ExtensionlessAttributes
    def original_filename
      "test"
    end
    
    def content_type
      "text/plain"
    end
  end
  
  module OriginalFilenameHasPathAttributes
    def original_filename
      " c:\\test/foo.txt "
    end
    
    def content_type
      "text/plain"
    end
  end
  
  def contents_of(file)
    file.rewind
    file.read
  end
  
  def test_default_methods
    model = SomeModel.new
    assert_equal nil, model.uploaded_data
    assert_equal nil, model.uploaded_file
    assert_equal false, model.process_attachment?
    assert File.directory?(model.tempfile_directory)
  end
  
  def test_uploaded_data_setters_and_extensions
    SomeModel.attachment_options = {}
    
    model = SomeModel.new
    model.uploaded_data = 'test #1'
    assert_equal 7, model.size
    assert_equal nil, model.content_type
    assert_equal nil, model.original_filename
    assert_equal 'test #1', model.uploaded_data # before converting to an uploaded_file
    assert_not_equal nil, model.uploaded_file
    assert model.uploaded_file.is_a?(Tempfile)
    assert_equal model.uploaded_file.object_id, model.uploaded_file.object_id, 'uploaded_file should return the same instance each time'
    assert_equal 'test #1', model.uploaded_data # after converting to an uploaded_file
    assert_equal 'test #1', contents_of(model.uploaded_file)
    assert_equal 'test #1', model.uploaded_data
    assert_equal 'bin', model.file_extension
    model.file_extension = 'ext'
    assert_equal 'ext', model.file_extension
    
    model = SomeModel.new
    model.uploaded_data = StringIO.new('test #2')
    assert_equal 7, model.size
    assert_equal nil, model.content_type
    assert_equal nil, model.original_filename
    assert_not_equal nil, model.uploaded_file
    assert model.uploaded_file.is_a?(Tempfile)
    assert_equal model.uploaded_file.object_id, model.uploaded_file.object_id, 'uploaded_file should return the same instance each time'
    assert_equal 'test #2', model.uploaded_data
    assert_equal 'test #2', contents_of(model.uploaded_file)
    assert_equal 'test #2', model.uploaded_data
    assert_equal 'bin', model.file_extension
    model.file_extension = 'ext'
    assert_equal 'ext', model.file_extension
    
    Tempfile.open('test') do |tempfile|
      tempfile.write('test #3')
      model = SomeModel.new
      model.uploaded_data = tempfile
      assert_equal 7, model.size
      assert_equal nil, model.content_type
      assert_equal nil, model.original_filename
      assert_equal tempfile.object_id, model.uploaded_file.object_id, 'uploaded_file should return the originally given tempfile'
      assert_equal 'test #3', model.uploaded_data
      assert_equal 'test #3', contents_of(model.uploaded_file)
      assert_equal 'test #3', model.uploaded_data
      assert_equal 'bin', model.file_extension
      model.file_extension = 'ext'
      assert_equal 'ext', model.file_extension
    end
    
    Tempfile.open('test') do |tempfile|
      tempfile.extend TempfileAttributes
      tempfile.write('test #4')
      model = SomeModel.new
      model.uploaded_data = tempfile
      assert_equal 7, model.size
      assert_equal "text/plain", model.content_type
      assert_equal "test.txt", model.original_filename
      assert_equal tempfile.object_id, model.uploaded_file.object_id, 'uploaded_file should return the originally given tempfile'
      assert_equal 'test #4', model.uploaded_data
      assert_equal 'test #4', contents_of(model.uploaded_file)
      assert_equal 'test #4', model.uploaded_data
      assert_equal 'txt', model.file_extension
      model.file_extension = 'ext'
      assert_equal 'ext', model.file_extension
    end
    
    Tempfile.open('test') do |tempfile|
      tempfile.extend ExtensionlessAttributes
      model = SomeModel.new
      model.uploaded_data = tempfile
      assert_equal "test", model.original_filename
      assert_equal 'bin', model.file_extension
      model.file_extension = 'ext'
      assert_equal 'ext', model.file_extension
    end
    
    Tempfile.open('test') do |tempfile|
      tempfile.extend OriginalFilenameHasPathAttributes
      
      model = SomeModel.new
      model.uploaded_data = tempfile
      assert_equal "foo.txt", model.original_filename
      assert_equal 'txt', model.file_extension
      
      SomeModel.attachment_options = {:keep_original_filename_path => true}
      model = SomeModel.new
      model.uploaded_data = tempfile
      assert_equal "c:\\test/foo.txt", model.original_filename
      assert_equal 'txt', model.file_extension
    end
    
    model = SomeModel.new
    model.uploaded_data = '' # this is what controllers get sent when there's a file field but no file selected; attachment_saver accordingly handles blank strings as a special case
    assert_equal nil, model.uploaded_file
    assert_equal nil, model.size
    assert_equal nil, model.content_type
    assert_equal nil, model.original_filename
  end
end
