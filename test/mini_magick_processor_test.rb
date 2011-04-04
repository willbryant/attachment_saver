require File.expand_path(File.join(File.dirname(__FILE__), 'image_processor_test_common'))
require 'processors/mini_magick'

class MiniMagickProcessorTest < Test::Unit::TestCase
  class MiniMagickTestModel
    include AttachmentSaver::InstanceMethods
    include AttachmentSaver::Processors::MiniMagick
    include ImageProcessorTestModel
  end
  
  def processor_model
    MiniMagickTestModel
  end
  
  def processor_exception
    MiniMagickProcessorError
  end

  include ImageProcessorTests
end
