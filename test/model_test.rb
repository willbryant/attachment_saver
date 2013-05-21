require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'image_fixtures'))

class DerivedImage < ActiveRecord::Base
  saves_attachment
end

class Image < ActiveRecord::Base
  FORMATS = {:thumb =>  [:cover_and_crop,  50,   50],
           :medium => [:shrink_to_fit,  500,  500],
           :big =>    [:shrink_to_fit, 1024, 1024]}
  saves_attachment :formats => FORMATS
end

class OtherImage < ActiveRecord::Base
  saves_attachment :formats => {:small => [:shrink_to_fit, 200, 200], :normal => [:shrink_to_fit, 400, 300]}
  cattr_accessor :want_smalls
  
protected
  def want_format?(format_name, width, height)
    format_name != :small || self.class.want_smalls
  end
end

class Unprocessed < ActiveRecord::Base
  saves_attachment
  validates_presence_of :original_filename, :content_type, :size
end

class LoadedImage < ActiveRecord::Base
  set_table_name 'images'
  saves_attachment :processor => 'image_science' # don't create any derived images, but still process the image to get the attributes
end

class AllInOneTableImages < ActiveRecord::Base
  saves_attachment :formats => {:small => '200x200', :normal => '400x'},
                   :derived_class => 'AllInOneTableImages'
end

class ImageScienceImage < ActiveRecord::Base
  set_table_name 'images'
  saves_attachment :processor => 'ImageScience', :formats => {:small => '200x200'}
end

class RMagickImage < ActiveRecord::Base
  set_table_name 'images'
  saves_attachment :processor => 'RMagick', :formats => {:small => '200x200'}
end

class MiniMagickImage < ActiveRecord::Base
  set_table_name 'images'
  saves_attachment :processor => 'RMagick', :formats => {:small => '200x200'}
end

class ModelTest < Test::Unit::TestCase
  module ValidUploadedFileAttributes
    def fixture=(value)
      @fixture = value
    end
    
    def original_filename
      @fixture[:original_filename]
    end
    
    def content_type
      @fixture[:content_type]
    end

    def size
      stat.size
    end
  end
  
  def uploaded_file_from(fixture)
    f = File.open(fixture[:path], "rb")
    f.extend ValidUploadedFileAttributes
    f.fixture = fixture
    f
  end

  def test_unprocessed_attachment
    model = Unprocessed.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ImageFixtures::valid[:expected_content_type], model.content_type
    assert_equal ImageFixtures::valid[:expected_extension], model.file_extension
    assert_equal ImageFixtures::valid[:expected_extension], AttachmentSaver::split_filename(model.storage_filename).last
    assert_equal ImageFixtures::valid[:size], model.size
    assert File.read(ImageFixtures::valid[:path]) == File.read(model.storage_filename), "stored data doesn't match!"
  end
  
  def test_underived_but_processed_attachment
    model = LoadedImage.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ImageFixtures::valid[:expected_content_type], model.content_type
    assert_equal ImageFixtures::valid[:expected_extension], model.file_extension
    assert_equal ImageFixtures::valid[:expected_extension], AttachmentSaver::split_filename(model.storage_filename).last
    assert File.read(ImageFixtures::valid[:path]) == File.read(model.storage_filename), "stored data doesn't match!"
    assert_equal ImageFixtures::valid[:width], model.width
    assert_equal ImageFixtures::valid[:height], model.height
    assert_equal "#{ImageFixtures::valid[:width]}x#{ImageFixtures::valid[:height]}", model.image_size
  end
  
  def test_extension_and_type_correction
    model = LoadedImage.create!(:uploaded_data => uploaded_file_from(ImageFixtures::wrong_extension))
    assert_equal ImageFixtures::wrong_extension[:expected_content_type], model.content_type
    assert_equal ImageFixtures::wrong_extension[:expected_extension], model.file_extension
    assert_equal ImageFixtures::wrong_extension[:expected_extension], AttachmentSaver::split_filename(model.storage_filename).last
    assert File.read(ImageFixtures::wrong_extension[:path]) == File.read(model.storage_filename), "stored data doesn't match!"
    assert_equal ImageFixtures::wrong_extension[:width], model.width
    assert_equal ImageFixtures::wrong_extension[:height], model.height
    assert_equal "#{ImageFixtures::wrong_extension[:width]}x#{ImageFixtures::wrong_extension[:height]}", model.image_size
  end
  
  def test_image_resizing
    model = Image.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ImageFixtures::valid[:expected_content_type], model.content_type
    assert_equal ImageFixtures::valid[:expected_extension], model.file_extension
    assert_equal ImageFixtures::valid[:expected_extension], AttachmentSaver::split_filename(model.storage_filename).last
    assert File.read(ImageFixtures::valid[:path]) == File.read(model.storage_filename), "stored data doesn't match!"
    assert_equal ImageFixtures::valid[:width], model.width
    assert_equal ImageFixtures::valid[:height], model.height
    assert_equal "#{ImageFixtures::valid[:width]}x#{ImageFixtures::valid[:height]}", model.image_size
    
    # full resize operation tests are performed in image_*_processor_test, here we just check enough to ensure that they were executed
    
    assert_equal Image::FORMATS.keys.collect(&:to_s).sort, model.formats.collect(&:format_name).sort
    model.formats.each {|size| assert !size.new_record?}
    
    thumb = model.formats.find_by_format_name('thumb')
    assert_equal Image::FORMATS[:thumb][1], thumb.width
    assert_equal Image::FORMATS[:thumb][1], thumb.height
    
    medium = model.formats.find_by_format_name('medium')
    assert medium.width <= Image::FORMATS[:medium][1]
    assert medium.height <= Image::FORMATS[:medium][2]
    assert medium.width == Image::FORMATS[:medium][1] || medium.height == Image::FORMATS[:medium][2]
  end
  
  def test_image_science
    model = ImageScienceImage.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ['small'], model.formats.collect(&:format_name)
  end
  
  def test_rmagick
    model = RMagickImage.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ['small'], model.formats.collect(&:format_name)
  end
  
  def test_mini_magick
    model = MiniMagickImage.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ['small'], model.formats.collect(&:format_name)
  end
  
  def test_image_rebuilding
    model = Image.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    old_storage_filenames = [model.storage_filename] + model.formats.sort_by(&:format_name).collect(&:storage_filename)
    model.update_attributes(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    new_storage_filenames = [model.storage_filename] + model.formats.sort_by(&:format_name).collect(&:storage_filename)
    model.reload
    model.formats(true)
    reloaded_storage_filenames = [model.storage_filename] + model.formats.sort_by(&:format_name).collect(&:storage_filename)
    
    assert_equal Image::FORMATS.size, model.formats.size
    assert_equal Image::FORMATS.keys.collect(&:to_s).sort, model.formats.collect(&:format_name).sort
    
    assert_equal old_storage_filenames.size, new_storage_filenames.size
    assert_equal old_storage_filenames.size, reloaded_storage_filenames.size
    old_storage_filenames.each_with_index do |f, i|
      assert_not_equal f, new_storage_filenames[i]
      assert_not_equal f, reloaded_storage_filenames[i]
      assert_equal new_storage_filenames[i], reloaded_storage_filenames[i]
    end
  end
  
  def test_want_format?
    OtherImage.want_smalls = false
    model = OtherImage.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ["normal"], model.formats.collect(&:format_name).sort

    OtherImage.want_smalls = true
    model = OtherImage.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ["normal", "small"], model.formats.collect(&:format_name).sort

    OtherImage.want_smalls = false
    model.update_attributes!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    #assert_equal ["normal"], model.formats.collect(&:format_name).sort # because we use formats.destroy(..ids..), they really should be removed from the formats collection in memory, but aren't in Rails 1.2.3 :/.  so the normal, expected semantics is that apps must reload to see collection changes.
    assert_equal ["normal"], model.formats(true).collect(&:format_name).sort
    # note that the small size has not only been not regenerated, it's been deleted
  end
  
  def test_all_in_one_table
    model = AllInOneTableImages.create!(:uploaded_data => uploaded_file_from(ImageFixtures::valid))
    assert_equal ImageFixtures::valid[:expected_content_type], model.content_type
    assert_equal ImageFixtures::valid[:expected_extension], model.file_extension
    assert_equal ImageFixtures::valid[:expected_extension], AttachmentSaver::split_filename(model.storage_filename).last
    assert File.read(ImageFixtures::valid[:path]) == File.read(model.storage_filename), "stored data doesn't match!"
    assert_equal ImageFixtures::valid[:width], model.width
    assert_equal ImageFixtures::valid[:height], model.height
    assert_equal "#{ImageFixtures::valid[:width]}x#{ImageFixtures::valid[:height]}", model.image_size
    
    assert !model.formats.empty?
    model.formats.each do |size|
      assert_equal AllInOneTableImages, size.class
      assert !size.new_record?
      assert size.formats.empty?
    end
  end
end
