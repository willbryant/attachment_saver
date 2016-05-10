require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require 'mocha/test_unit'
require 'processors/image'
require File.expand_path(File.join(File.dirname(__FILE__), 'image_operations'))

class ImageProcessorTest < ActiveSupport::TestCase
  class SomeModel
    include AttachmentSaver::Processors::Image
    
    cattr_accessor :attachment_options
    attr_accessor :content_type
    
    def initialize(content_type)
      self.content_type = content_type
    end
  end
  
  def test_image?
    SomeModel.attachment_options = {}
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
    SomeModel.attachment_options = {}
    model_without_upload = SomeModel.new('application/octet-stream') # note the content type doesn't have to be an image for examine_image to be called, since examine_image is supposed to fix up incorrect client-supplied content-types
    model_without_upload.expects(:uploaded_file).times(1).returns(nil)
    model_without_upload.expects(:examine_image).times(0)
    model_without_upload.before_validate_attachment
    
    model_with_upload = SomeModel.new('application/octet-stream')
    model_with_upload.expects(:uploaded_file).at_least(:once).returns(StringIO.new('dummy'))
    model_with_upload.expects(:examine_image).times(1)
    model_with_upload.before_validate_attachment
    
    model_with_non_image_upload = SomeModel.new('text/plain')
    model_with_non_image_upload.expects(:uploaded_file).at_least(:once).returns(StringIO.new('dummy'))
    model_with_non_image_upload.expects(:examine_image).times(1).raises(ImageProcessorError)
    model_with_non_image_upload.before_validate_attachment
    assert_equal 'text/plain', model_with_non_image_upload.content_type
    
    model_with_mislabelled_non_image_upload = SomeModel.new('image/png')
    model_with_mislabelled_non_image_upload.expects(:uploaded_file).at_least(:once).returns(StringIO.new('dummy'))
    model_with_mislabelled_non_image_upload.expects(:examine_image).times(1).raises(ImageProcessorError)
    model_with_mislabelled_non_image_upload.before_validate_attachment
    assert_equal 'application/octet-stream', model_with_mislabelled_non_image_upload.content_type
  end
  
  def test_from_geometry_string
    SomeModel.attachment_options = {}
    ImageOperations::geometry_strings.each do |geometry, expected_result|
      assert_equal expected_result, AttachmentSaver::Processors::Image.from_geometry_string(geometry), "geometry parse of #{geometry} produced incorrect results"
    end
  end
end
