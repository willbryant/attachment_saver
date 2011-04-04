require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require 'mocha'
require 'datastores/file_system'

class FileSystemDatastoreTest < Test::Unit::TestCase
  attr_accessor :storage_key, :original_filename, :content_type
  
  DEFAULT_ATTACHMENT_OPTIONS = {:storage_directory => File.join(TEST_TEMP_DIR, 'fs_store_test'),
                                :storage_path_base => 'files'}
  
  def self.attachment_options
    @@attachment_options ||= DEFAULT_ATTACHMENT_OPTIONS
  end

  include AttachmentSaver::DataStores::FileSystem
  
  def setup
    @test_filename = File.join(self.class.attachment_options[:storage_directory], self.class.attachment_options[:storage_path_base], "test#{$$}.dat")
    @uploaded_data = nil
    @uploaded_file = nil
    @saved_to = nil
    self.storage_key = nil
    self.original_filename = 'myfile.dat'
    self.content_type = 'application/octet-stream'
  end
  
  def teardown
    FileUtils.rm_rf(TEST_TEMP_DIR)
  end
  
  def file_extension
    "testext"
  end
  
  def random_data(length = nil)
    length = 512 + rand(2048) if length.nil?
    Array.new(length).collect {rand(256)} .pack('C*')
  end
  
  def read_file(filename)
    File.read(filename, :encoding => "ascii-8bit") # ruby 1.9
  rescue TypeError
    File.read(filename) # ruby 1.8
  end
  
  def save_attachment_to_with_record(filename)
    @saved_to = filename
    save_attachment_to_without_record(filename)
  end
  alias_method_chain :save_attachment_to, :record
  

  def save_attachment_to_test(expected_data)
    File.rm(@test_filename) if File.exist?(@test_filename)
    
    save_attachment_to(@test_filename)
    
    assert File.exist?(@test_filename), "no file #{@test_filename} created"
    assert expected_data == read_file(@test_filename), "data written to #{@test_filename} doesn't match"
  end
  
  def save_attachment_to_test_no_clobber_existing
    FileUtils.mkdir_p(File.dirname(@test_filename))
    File.open(@test_filename, 'wb') {|f| f.write('test file')}
    
    assert_raises(Errno::EEXIST) { save_attachment_to(@test_filename) }
    assert File.exist?(@test_filename), "file #{@test_filename} deleted"
    assert 'test file' == read_file(@test_filename), "contents of #{@test_filename} clobbered"
  end
  
  def save_test_independent_files(uploaded_file, original_data)
    uploaded_file.rewind
    uploaded_file.write('new file data')
    uploaded_file.truncate('new file data'.length)
    uploaded_file.flush
    assert original_data == read_file(@test_filename), "stored file appears to be a hardlink to the uploaded file"
  end
  
  def save_test_same_file(uploaded_file)
    uploaded_file.rewind
    uploaded_file.write('new file data')
    uploaded_file.truncate('new file data'.length)
    uploaded_file.flush
    assert 'new file data' == read_file(@test_filename), "stored file is not a hardlink to the uploaded file"
  end
  
  def test_save_attachment_to_for_data
    @uploaded_data = data = random_data
    @save_upload = true
    save_attachment_to_test(data)
  end
  
  def test_save_attachment_to_for_data_doesnt_clobber_existing
    @uploaded_data = random_data
    @save_upload = true
    save_attachment_to_test_no_clobber_existing
  end
  
  def test_save_attachment_to_for_file
    data = random_data
    FileUtils.mkdir_p(File.dirname(@test_filename))
    File.open(@test_filename + '.src_file', 'wb+') do |file|
      file.write(data)
      @uploaded_file = file
      @save_upload = true
      save_attachment_to_test(data)
      save_test_independent_files(file, data)
    end
  end
  
  def test_save_attachment_to_for_file_doesnt_clobber_existing
    FileUtils.mkdir_p(File.dirname(@test_filename))
    File.open(@test_filename + '.src_file', 'wb') do |file|
      file.write(random_data)
      @uploaded_file = file
      @save_upload = true
      save_attachment_to_test_no_clobber_existing
    end
  end
  
  def test_save_attachment_to_for_tempfile
    data = random_data
    FileUtils.mkdir_p(File.dirname(@test_filename))
    Tempfile.open('src_file', File.dirname(@test_filename)) do |file|
      file.write(data)
      @uploaded_file = file
      @save_upload = true
      save_attachment_to_test(data)
      save_test_same_file(file)
    end
  end
  
  def test_save_attachment_to_for_tempfile_doesnt_clobber_existing
    FileUtils.mkdir_p(File.dirname(@test_filename))
    Tempfile.open('src_file', File.dirname(@test_filename)) do |file|
      file.write(random_data)
      @uploaded_file = file
      @save_upload = true
      save_attachment_to_test_no_clobber_existing
    end
  end
  
  def test_save_attachment_to_for_tempfile_falls_back_if_ln_fails
    data = random_data
    FileUtils.mkdir_p(File.dirname(@test_filename))
    Tempfile.open('src_file', File.dirname(@test_filename)) do |file|
      file.write(data)
      @uploaded_file = file
      @save_upload = true
      FileUtils.expects(:ln).once.raises(RuntimeError)
      save_attachment_to_test(data)
      save_test_independent_files(file, data)
    end
  end
  
  
  def test_save_attachment_without_upload
    expects(:save_attachment_to).times(0)
    expects(:process_attachment?).times(0)
    expects(:process_attachment).times(0)
    save_attachment
  end
  
  
  def test_save_attachment_with_random_filename
    @uploaded_data = data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(false)
    expects(:process_attachment).times(0)

    save_attachment
    
    assert !storage_key.blank?, "storage_key not set"
    assert File.exist?(storage_filename), "no file #{storage_filename} created"
    assert data == read_file(storage_filename), "data written to #{storage_filename} doesn't match"
  end

  def test_save_attachment_with_random_filename_retries_for_a_while
    @uploaded_data = random_data
    @save_upload = true
    expects(:save_attachment_to).times(100).raises(Errno::EEXIST)
    expects(:process_attachment?).times(0)
    assert_raises(FileSystemAttachmentDataStoreError) { save_attachment } # as above
  end
  
  
  class Named
    attr_accessor :storage_key, :original_filename, :content_type
  
    def self.attachment_options
      @@attachment_options ||= DEFAULT_ATTACHMENT_OPTIONS.dup
      @@attachment_options[:filter_filenames] ||= /[^\w\._-]/
      @@attachment_options
    end
    
    def uploaded_data=(uploaded_data)
      @uploaded_data = uploaded_data
      @save_upload = true
    end
  
    include AttachmentSaver::InstanceMethods
    include AttachmentSaver::DataStores::FileSystem
  end
  
  def test_save_new_attachment_with_filtered_filename
    named = Named.new
    named.uploaded_data = data = random_data
    named.original_filename = 'm!y_file-test12+*.dat'
    named.content_type = 'application/octet-stream'
    named.expects(:process_attachment?).times(1).returns(false)
    named.expects(:process_attachment).times(0)
    named.save_attachment
  
    assert !named.storage_key.blank?, "named storage_key not set"
    assert_equal 'm_y_file-test12__.dat', named.storage_key.gsub(/.*\//, ''), "named storage key doesn't correspond to original filename"
    assert File.exist?(named.storage_filename), "no named file #{named.storage_filename} created"
    assert data == read_file(named.storage_filename), "data written to #{named.storage_filename} doesn't match"
  end
  
  def test_save_new_attachment_with_filtered_filename_retries_only_for_a_while
    named = Named.new
    named.uploaded_data = data = random_data
    named.original_filename = 'm!y_file-test12+*.dat'
    named.content_type = 'application/octet-stream'
    named.expects(:save_attachment_to).times(100).raises(Errno::EEXIST)
    assert_raises(FileSystemAttachmentDataStoreError) { named.save_attachment } # as above
  end
  
  
  class Thumbnail
    attr_accessor :storage_key, :content_type, :original, :format_name
  
    def self.attachment_options
      @@attachment_options ||= DEFAULT_ATTACHMENT_OPTIONS.dup
    end
    
    def uploaded_data=(uploaded_data)
      @uploaded_data = uploaded_data
      @save_upload = true
    end
  
    include AttachmentSaver::InstanceMethods
    include AttachmentSaver::DataStores::FileSystem
  end
  
  def test_save_new_attachment_with_parent_filename
    @uploaded_data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(false)
    expects(:process_attachment).times(0)
    save_attachment
    
    thumbnail = Thumbnail.new
    thumbnail.uploaded_data = thumbnail_data = random_data
    thumbnail.content_type = 'application/octet-stream'
    thumbnail.file_extension = 'test'
    thumbnail.original = self
    thumbnail.format_name = 'thumb'
    thumbnail.expects(:process_attachment?).times(1).returns(false)
    thumbnail.expects(:process_attachment).times(0)
    thumbnail.save_attachment
    
    assert !thumbnail.storage_key.blank?, "thumbnail storage_key not set"
    assert_equal File.dirname(storage_key), File.dirname(thumbnail.storage_key), "thumbnail not saved to same directory as parent"
    assert_equal storage_key.gsub(/\.\w+$/, '_thumb.test'), thumbnail.storage_key, "thumbnail storage key doesn't correspond to parent"
    assert File.exist?(thumbnail.storage_filename), "no thumbnail file #{thumbnail.storage_filename} created"
    assert thumbnail_data == read_file(thumbnail.storage_filename), "data written to #{thumbnail.storage_filename} doesn't match"
  end
  
  def test_save_new_attachment_with_filtered_parent_filename
    named = Named.new
    named.uploaded_data = data = random_data
    named.original_filename = 'm!y_file-test12+*.dat'
    named.content_type = 'application/octet-stream'
    named.expects(:process_attachment?).times(1).returns(false)
    named.expects(:process_attachment).times(0)
    named.save_attachment
  
    thumbnail = Thumbnail.new
    thumbnail.uploaded_data = thumbnail_data = random_data
    thumbnail.content_type = 'application/octet-stream'
    thumbnail.file_extension = 'test'
    thumbnail.original = named
    thumbnail.format_name = 'thumb'
    thumbnail.expects(:process_attachment?).times(1).returns(false)
    thumbnail.expects(:process_attachment).times(0)
    thumbnail.save_attachment
    
    assert !thumbnail.storage_key.blank?, "thumbnail storage_key not set"
    assert_equal File.dirname(named.storage_key), File.dirname(thumbnail.storage_key), "thumbnail not saved to same directory as parent"
    assert_equal named.storage_key.gsub(/\.\w+$/, '_thumb.test'), thumbnail.storage_key, "thumbnail storage key doesn't correspond to parent"
    assert File.exist?(thumbnail.storage_filename), "no thumbnail file #{thumbnail.storage_filename} created"
    assert thumbnail_data == read_file(thumbnail.storage_filename), "data written to #{thumbnail.storage_filename} doesn't match"
  end
  
  def test_save_new_attachment_with_filtered_parent_filename_adds_suffix_if_existing
    named = Named.new
    named.uploaded_data = data = random_data
    named.original_filename = 'm!y_file-test12+*.dat'
    named.content_type = 'application/octet-stream'
    named.expects(:process_attachment?).times(1).returns(false)
    named.expects(:process_attachment).times(0)
    named.save_attachment
    
    FileUtils.touch(named.storage_filename.gsub(/\.\w+$/, '_thumb.test'))
    FileUtils.touch(named.storage_filename.gsub(/\.\w+$/, '_thumb2.test'))
  
    thumbnail = Thumbnail.new
    thumbnail.uploaded_data = thumbnail_data = random_data
    thumbnail.content_type = 'application/octet-stream'
    thumbnail.file_extension = 'test'
    thumbnail.original = named
    thumbnail.format_name = 'thumb'
    thumbnail.expects(:process_attachment?).times(1).returns(false)
    thumbnail.expects(:process_attachment).times(0)
    thumbnail.save_attachment
    
    assert !thumbnail.storage_key.blank?, "thumbnail storage_key not set"
    assert_equal File.dirname(named.storage_key), File.dirname(thumbnail.storage_key), "thumbnail not saved to same directory as parent"
    assert_equal named.storage_key.gsub(/\.\w+$/, '_thumb3.test'), thumbnail.storage_key, "thumbnail storage key doesn't correspond to parent"
    assert File.exist?(thumbnail.storage_filename), "no thumbnail file #{thumbnail.storage_filename} created"
    assert thumbnail_data == read_file(thumbnail.storage_filename), "data written to #{thumbnail.storage_filename} doesn't match"
  end
  
  
  def test_save_attachment_calls_processing
    @uploaded_data = expected_data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(true)
    expects(:process_attachment_with_wrapping).times(1).returns do |filename|
      assert expected_data == read_file(filename)
    end
    expects(:save_attachment_to)
    
    save_attachment
  end
  
  
  def test_save_attachment_deletes_immediately_if_processing_fails
    @uploaded_data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(true)
    expects(:process_attachment_with_wrapping).times(1).raises(AttachmentProcessorError)

    assert_raises(AttachmentProcessorError) { save_attachment }

    assert_equal nil, storage_key, "storage key wasn't reset after processing failed"
    assert_not_equal nil, @saved_to, "save_attachment_to not called"
    assert !File.exist?(@saved_to), "saved file wasn't removed after processing failed"
  end
  
  
  def test_save_attachment_with_old_filename
    expects(:process_attachment?).times(2).returns(false)

    @uploaded_data = random_data
    @save_upload = true
    save_attachment
    tidy_attachment # after_save
    old_filename = storage_filename

    @uploaded_data = random_data
    @save_upload = true
    save_attachment
    tidy_attachment # after_save
    
    assert_not_equal storage_filename, old_filename
    assert !File.exist?(old_filename), "old file wasn't removed after save"
  end
  
  def test_save_attachment_with_old_filename_keeps_old_if_processing_fails
    @uploaded_data = data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(false)
    save_attachment
    tidy_attachment # after_save
    old_key = storage_key
    old_filename = storage_filename

    @uploaded_data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(true)
    expects(:process_attachment_with_wrapping).times(1).raises(AttachmentProcessorError)
    assert_raises(AttachmentProcessorError) { save_attachment }
    
    assert_equal old_key, storage_key
    assert File.exist?(old_filename), "old file was removed before save"
    assert data == read_file(storage_filename), "data in old file damaged"
    
    tidy_attachment # check the old-file deletion code wouldn't destroy it either (presumably after another save attempt)
    assert File.exist?(old_filename), "old file was removed before save"
  end
  
  
  def test_destroy_attachment
    @uploaded_data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(false)
    save_attachment
    tidy_attachment # after_save
    
    delete_attachment
    assert !storage_key.blank?, "storage_key not set"
    assert !File.exist?(storage_filename), "file #{storage_filename} not removed by destroy"
  end
  
  
  def test_public_path
    self.storage_key = 'files/myfile.dat'
    assert_equal '/files/myfile.dat', public_path
  end
  
  
  def test_in_storage?
    @uploaded_data = random_data
    @save_upload = true
    expects(:process_attachment?).times(1).returns(false)
    save_attachment
    
    assert_equal true, in_storage?
    FileUtils.rm(self.storage_filename)
    assert_equal false, in_storage?
  end
  
  
  EXPECTED_DEFAULT_MODE = 0664
  TEST_FILE_MODE = 0604

  def test_default_permission_setting
    assert_equal EXPECTED_DEFAULT_MODE, Named.attachment_options[:file_permissions] # using Named to check is arbitrary - just can't use this class, since we mess with in it the test below (we don't ever set it back, since none of the other tests care exactly what the permissions setting is)
  end
  
  def test_permission_setting_for_save_from_data
    self.class.attachment_options[:file_permissions] = TEST_FILE_MODE
    @uploaded_data = data = random_data
    @save_upload = true
    save_attachment_to_test(data)
    assert_equal TEST_FILE_MODE, File.stat(@test_filename).mode & 0777
  end
  
  def test_permission_setting_for_save_from_file
    self.class.attachment_options[:file_permissions] = TEST_FILE_MODE
    data = random_data
    FileUtils.mkdir_p(File.dirname(@test_filename))
    File.open(@test_filename + '.src_file', 'wb+') do |file|
      file.write(data)
      @uploaded_file = file
      @save_upload = true
      save_attachment_to_test(data)
      save_test_independent_files(file, data)
    end
    assert_equal TEST_FILE_MODE, File.stat(@test_filename).mode & 0777
  end
  
  def test_permission_setting_for_save_from_tempfile
    self.class.attachment_options[:file_permissions] = TEST_FILE_MODE
    data = random_data
    FileUtils.mkdir_p(File.dirname(@test_filename))
    Tempfile.open('src_file', File.dirname(@test_filename)) do |file|
      file.write(data)
      @uploaded_file = file
      @save_upload = true
      save_attachment_to_test(data)
      save_test_same_file(file)
    end
    assert_equal TEST_FILE_MODE, File.stat(@test_filename).mode & 0777
  end
end
