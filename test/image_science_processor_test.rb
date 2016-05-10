require File.expand_path(File.join(File.dirname(__FILE__), 'image_processor_test_common'))
require 'processors/image_science'

class ImageScienceProcessorTest < ActiveSupport::TestCase
  class ImageScienceTestModel
    include AttachmentSaver::InstanceMethods
    include AttachmentSaver::Processors::ImageScience
    include ImageProcessorTestModel
  end
  
  def processor_model
    ImageScienceTestModel
  end
  
  def processor_exception
    ImageScienceProcessorError
  end

  include ImageProcessorTests
end
