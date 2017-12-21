require File.expand_path(File.join(File.dirname(__FILE__), 'image_processor_test_common'))
require 'processors/image_size'

class ImageSizeProcessorTest < ActiveSupport::TestCase
  class ImageSizeTestModel
    include AttachmentSaver::InstanceMethods
    include AttachmentSaver::Processors::ImageSize
    include ImageProcessorTestModel
  end
  
  def processor_model
    ImageSizeTestModel
  end
  
  def processor_exception
    ImageSizeProcessorError
  end

  include ImageProcessorTests

  def processes_images?
    false
  end
end
