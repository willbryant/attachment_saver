require File.expand_path(File.join(File.dirname(__FILE__), 'image_processor_test_common'))
require 'processors/r_magick'

class RMagickProcessorTest < ActiveSupport::TestCase
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
