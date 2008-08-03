require 'attachment_saver_errors'
require 'misc/file_size'

module AttachmentSaver
  module BaseMethods
    def saves_attachment(options = {})
      extend ClassMethods
      include InstanceMethods
      
      class_inheritable_accessor :attachment_options
      self.attachment_options = options

      attachment_options[:datastore] ||= 'file_system'
      require "datastores/#{attachment_options[:datastore].to_s.underscore}"
      include DataStores.const_get(attachment_options[:datastore].to_s.classify)
      before_validation :before_validate_attachment # this callback does things like override the content-type based on the actual file data
      before_save       :save_attachment # this callback is where most of the goodness happens; note that it runs before save, so that it prevents the record being saved if processing raises; this is why our filenames can't be based on the instance ID
      after_save        :tidy_attachment
      after_save        :close_open_file
      after_destroy     :delete_attachment

      if attachment_options[:formats] && reflect_on_association(:formats).nil? # this allows you to override our definition of the sizes association by simply defining it before calling has_attachment
        attachment_options[:processor] ||= 'image_science'
        attachment_options[:derived_class] ||= DerivedImage
        has_many :formats, :as => :original, :class_name => attachment_options[:derived_class].to_s, :dependent => :destroy
        after_save      :save_updated_derived_children
      end
      
      if attachment_options[:processor]
        require "processors/#{attachment_options[:processor].to_s.underscore}" unless Processors.const_defined?(attachment_options[:processor].to_s.classify)
        include Processors.const_get(attachment_options[:processor].to_s.classify)
      end
    end
  end
  
  module ClassMethods
    # currently present only for the benefit of extensions
  end
  
  module InstanceMethods
    def uploaded_data=(uploaded)
      # we don't go ahead and process the upload just yet - in particular, we need to wait
      # until we have all the attributes, and then until validation passes - so we just retain
      # the data or file reference for now.
      if uploaded.is_a?(String) # we allow people to upload into the file field using a normal input element (eg. a textarea)
        return if uploaded.blank? # this handles the case when a form has a file field but no file is selected - most browsers submit an empty string then (annoyingly)
        @uploaded_data = uploaded
        @uploaded_file = nil
      elsif uploaded.is_a?(StringIO)
        uploaded.rewind
        @uploaded_data = uploaded.read
        @uploaded_file = nil
      elsif uploaded
        @uploaded_file = uploaded
        @uploaded_data = nil
      end

      self.size =              uploaded.size                                      if respond_to?(:size=)
      self.content_type =      uploaded.content_type.strip.downcase               if respond_to?(:content_type=) && uploaded.respond_to?(:content_type)
      self.original_filename = trim_original_filename(uploaded.original_filename) if respond_to?(:original_filename=) && uploaded.respond_to?(:original_filename)
    end
    
    def uploaded_data
      if @uploaded_data.nil?
        if @uploaded_file.nil?
          nil
        else
          @uploaded_file.rewind
          @uploaded_file.read
        end
      else
        !@uploaded_data.blank?
      end
    end
    
    def uploaded_file
      unless @uploaded_data.nil?
        # if we have a processor, we need to get the uploaded data into a file at some point
        # so it can be processed.  we take advantage of the fact that our file backend knows
        # how to hardlink temporary files into their final location (rather than copying) to
        # simplify things without introducing an extra file copy (so long as we put the temp
        # file in the right place); of course, for non-file backends, this file will be only
        # temporary in any case - so doing this here represents no extra overhead (remember,
        # uploaded files over the magic size built into the CGI module are saved to files in
        # the first place, so we know that the overhead here is minimal anyway).
        temp = Tempfile.new("asutemp", FileUtils.mkdir_p(tempfile_directory))
        temp.binmode
        temp.write(@uploaded_data)
        temp.flush
        @uploaded_file = temp
        @uploaded_data = nil
      end
      @uploaded_file
    end
    
    def close_open_file
      @uploaded_file.close if @uploaded_file
    end
    
    def before_validate_attachment # overridden by the processors (and/or by the class we're mixed into)
      # when you write code in here that needs to access the file, use the uploaded_file method to get it
    end
    
    def process_attachment? # called by the datastores, overridden by the processors (and/or by the class we're mixed into)
      false
    end
    
    def process_attachment_with_wrapping(filename)
      process_attachment(filename)
    rescue AttachmentProcessorError
      raise # pass any exceptions of the correct type (which anything eminating from our processors should be) straight
    rescue Exception => ex
      raise AttachmentProcessorError, "#{ex.class}: #{ex.message}", ex.backtrace # wrap anything else
    end
    
    def tempfile_directory # called by uploaded_file, overridden by the file datastore, which sets it to the base dir that it saves into itself, so that the files are put on the same partition & so can be directly hardlinked rather than copied
      Dir::tmpdir
    end
    
    def file_extension=(extension) # used by processors to override the original extension
      @file_extension = extension
    end
      
    def file_extension
      extension = @file_extension
      extension = AttachmentSaver::split_filename(original_filename).last if extension.blank? && respond_to?(:original_filename) && !original_filename.blank?
      extension = 'bin' if extension.blank?
      extension
    end
    
    def trim_original_filename(filename)
      return filename.strip if attachment_options[:keep_original_filename_path]
      filename.gsub(/^.*(\\|\/)/, '').strip
    end
      
    def image_size
      width.nil? || height.nil? ? nil : "#{width}x#{height}"
    end
    
    def save_updated_derived_children # rails automatically saves children on create, but not on update; when uploading a new image, we don't want to save them until we've finished processing in case that raises & causes a rollback, so we have to save them ourselves later
      @updated_derived_children.each(&:save!) unless @updated_derived_children.blank?
      @updated_derived_children = nil
    end
  end
  
  def self.split_filename(filename)
    pos = filename.rindex('.')
    if pos.nil?
      return [filename, nil]
    else
      return [filename[0..pos - 1], filename[pos + 1..-1]]
    end
  end
end