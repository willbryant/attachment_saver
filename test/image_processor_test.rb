require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require 'mocha'
require 'processors/image'
require File.expand_path(File.join(File.dirname(__FILE__), 'image_operations'))

class ImageProcessorTest < Test::Unit::TestCase
  class SomeModel
    include AttachmentSaver::Processors::Image
    
    cattr_accessor :attachment_options
    attr_accessor :content_type
    
    def initialize(content_type)
      self.content_type = content_type
    end
  end
  
  def test_image?
    [nil, '', '/', 'foo', 'foo/' '/bar', 'text/plain', 'x-image/invalid', 'image-x/invalid'].each do |mime|
      assert_equal false, SomeModel.new(mime).image?
    end
    
    ['image/jpeg', 'image/png', 'image/gif'].each do |mime|
      assert_equal true, SomeModel.new(mime).image?
    end
  end
  
  def test_process_attachment?
    SomeModel.attachment_options = {}
    assert_equal false, SomeModel.new('text/plain').process_attachment?
    assert_equal false, SomeModel.new('image/jpeg').process_attachment?
    
    SomeModel.attachment_options = {:formats => {'thumb' => '50x50'}}
    assert_equal false, SomeModel.new('text/plain').process_attachment?
    assert_equal true, SomeModel.new('image/jpeg').process_attachment?
  end
  
  def test_before_validate_attachment
    model_without_upload = SomeModel.new('application/octet-stream') # note the content type doesn't have to be an image for examine_attachment to be called, since examine_attachment is supposed to fix up incorrect client-supplied content-types
    model_without_upload.expects(:uploaded_file).times(1).returns(nil)
    model_without_upload.expects(:examine_attachment).times(0)
    model_without_upload.before_validate_attachment
    
    model_with_upload = SomeModel.new('application/octet-stream')
    model_with_upload.expects(:uploaded_file).times(1).returns('dummy')
    model_with_upload.expects(:examine_attachment).times(1)
    model_with_upload.before_validate_attachment
    
    model_with_non_image_upload = SomeModel.new('text/plain')
    model_with_non_image_upload.expects(:uploaded_file).times(1).returns('dummy')
    model_with_non_image_upload.expects(:examine_attachment).times(1).raises(ImageProcessorError)
    model_with_non_image_upload.before_validate_attachment
    assert_equal 'text/plain', model_with_non_image_upload.content_type
    
    model_with_mislabelled_non_image_upload = SomeModel.new('image/png')
    model_with_mislabelled_non_image_upload.expects(:uploaded_file).times(1).returns('dummy')
    model_with_mislabelled_non_image_upload.expects(:examine_attachment).times(1).raises(ImageProcessorError)
    model_with_mislabelled_non_image_upload.before_validate_attachment
    assert_equal 'application/octet-stream', model_with_mislabelled_non_image_upload.content_type
  end
  
  def test_from_geometry_string
    ImageOperations::geometry_strings.each do |geometry, expected_result|
      assert_equal expected_result, AttachmentSaver::Processors::Image.from_geometry_string(geometry), "geometry parse of #{geometry} produced incorrect results"
    end
  end
end
