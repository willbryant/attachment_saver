require 'test/image_processor_test_common'
require 'processors/image_science'

class ImageScienceProcessorTest < Test::Unit::TestCase
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
