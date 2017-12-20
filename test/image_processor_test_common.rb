require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require 'attachment_saver'
require File.expand_path(File.join(File.dirname(__FILE__), 'image_fixtures'))
require File.expand_path(File.join(File.dirname(__FILE__), 'image_operations'))

module ImageProcessorTestModel
  attr_accessor :content_type, :original_filename, :width, :height
  
  def self.included(base)
    base.cattr_accessor :attachment_options
    base.attachment_options = {}
  end
  
  def initialize(uploaded_data)
    self.uploaded_data = uploaded_data
  end
  
  def new_record?
    true
  end
  
  def build_derived(attrs)
    @derived_attributes ||= {}
    raise "already have a derived image named #{attrs[:format_name]}" if @derived_attributes[attrs[:format_name].to_s]
    @derived_attributes[attrs[:format_name].to_s] = attrs # and it would build a record, not just save the attributes
  end
  
  def find_derived(format_name)
    @derived_attributes[format_name.to_s]
  end
end

module ImageProcessorTests
  def processes_images?
    true # overridden for examine-only processors
  end

  def test_attributes_from_valid
    processor_model.attachment_options = {}
    ImageFixtures.all_readable.each do |fixture|
      model = processor_model.new(File.open(fixture[:path], 'rb'))
      model.content_type = fixture[:content_type]
      model.original_filename = fixture[:original_filename]
      model.examine_image
      assert_equal fixture[:expected_content_type], model.content_type
      assert_equal fixture[:width], model.width
      assert_equal fixture[:height], model.height
      assert_equal "#{fixture[:width]}x#{fixture[:height]}", model.image_size
      assert_equal fixture[:expected_extension], model.file_extension
    end
  end
  
  def test_attributes_from_non_image
    processor_model.attachment_options = {}
    (ImageFixtures.all_unreadable - [ImageFixtures.corrupt]).each do |fixture|
      model = processor_model.new(File.open(fixture[:path], 'rb'))
      model.content_type = fixture[:content_type]
      assert_raises(processor_exception) { model.examine_image }
      assert_equal fixture[:expected_content_type], model.content_type
      assert_nil model.width
      assert_nil model.height
      assert_nil model.image_size
      assert_equal 'bin', model.file_extension
      model.original_filename = fixture[:original_filename]
      assert_equal fixture[:expected_extension], model.file_extension
    end
  end

  def test_attributes_from_corrupt
    processor_model.attachment_options = {}
    if processes_images?
      fixture = ImageFixtures.corrupt
      model = processor_model.new(File.open(fixture[:path], 'rb'))
      model.content_type = fixture[:content_type]
      assert_raises(processor_exception) { model.examine_image }
      assert_equal fixture[:expected_content_type], model.content_type
      assert_nil model.width
      assert_nil model.height
      assert_nil model.image_size
      assert_equal 'bin', model.file_extension
      model.original_filename = fixture[:original_filename]
      assert_equal fixture[:expected_extension], model.file_extension
    end
  end
  
  def test_image_exploits
    processor_model.attachment_options = {:valid_image_types => %w(image/png image/jpeg)}

    model = processor_model.new(File.open(ImageFixtures.fixture_path('ssrf.png'), 'rb')) # actually a .mvg file
    model.expects(:examine_attachment).times(0) # don't invoke the potentially vulnerable image processor code
    model.before_validate_attachment
    assert_not_equal 'image/png', model.content_type
  end

  def test_derived_attributes_from_valid
    processor_model.attachment_options = {:formats => ImageOperations.resize_operations}

    fixture = ImageOperations.original_image
    model = processor_model.new(File.open(fixture[:path], 'rb'))
    model.content_type = fixture[:content_type]
    model.original_filename = fixture[:original_filename]

    if processes_images?
      model.process_attachment(model.uploaded_file_path)

      ImageOperations.expected_results.each do |format_name, size|
        derived = model.find_derived(format_name)
        assert !derived.nil?, "no derived image named #{format_name} generated"
        assert_equal size.first, derived[:width], "#{format_name} width incorrect"
        assert_equal size.last, derived[:height], "#{format_name} height incorrect"
        assert_equal model.file_extension, derived[:file_extension], "#{format_name} file_extension incorrect"
      end
    else
      assert_raise(NotImplementedError) do
        model.process_attachment(model.uploaded_file_path)
      end
    end
  end
end
