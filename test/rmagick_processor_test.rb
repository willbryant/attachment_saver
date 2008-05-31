require 'test/image_processor_test_common'
require 'processors/r_magick'

class RMagickProcessorTest < Test::Unit::TestCase
  class RMagickTestModel
    include AttachmentSaver::InstanceMethods
    include AttachmentSaver::Processors::RMagick
    include ImageProcessorTestModel
  end
  
  def processor_model
    RMagickTestModel
  end
  
  def processor_exception
    RMagickProcessorError
  end

  include ImageProcessorTests
end
