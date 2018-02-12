require File.expand_path(File.join(File.dirname(__FILE__), 'image_processor_test_common'))
require 'processors/gdk_pixbuf'

class GdkPixbufProcessorTest < ActiveSupport::TestCase
  class GdkPixbufTestModel
    include AttachmentSaver::InstanceMethods
    include AttachmentSaver::Processors::GdkPixbuf
    include ImageProcessorTestModel
  end

  def processor_model
    GdkPixbufTestModel
  end

  def processor_exception
    GdkPixbufProcessorError
  end

  include ImageProcessorTests

  def saves_to_gif_format?
    false
  end
end
