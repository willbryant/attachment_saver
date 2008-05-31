require 'image_science'
require 'misc/image_science_extensions'
require 'misc/extended_tempfile'
require 'processors/image'

class ImageScienceProcessorError < ImageProcessorError; end

module AttachmentSaver
  module Processors
    module ImageScience
      include Image
      
      def with_image(filename, &block)
        ::ImageScience.with_image(filename) {|image| block.call(image.extend(Operations))}
      end
      
      def with_image_attributes(filename, &block)
        return with_image(filename, &block) unless ::ImageScience.respond_to?(:with_image_attributes)
        ::ImageScience.with_image_attributes(filename) {|image| block.call(image)}
      end
      
      def examine_attachment
        with_image_attributes(uploaded_file.path) do |original_image|
          self.width = original_image.width if respond_to?(:width)
          self.height = original_image.height if respond_to?(:height)
          self.content_type = original_image.mime_type unless self.class.attachment_options[:keep_content_type] || original_image.mime_type.nil?
          self.file_extension = original_image.file_type_extension unless self.class.attachment_options[:keep_file_extension] || original_image.file_type_extension.nil?
        end
      rescue AttachmentSaverError
        raise
      rescue Exception => ex
        raise ImageScienceProcessorError, "#{ex.class}: #{ex.message}", ex.backtrace
      end
      
      def process_image(original_image, derived_format_name, resize_format)
        resize_format = Image.from_geometry_string(resize_format) if resize_format.is_a?(String)

        original_image.send(*resize_format) do |derived_image|
          return nil unless want_format?(derived_format_name, derived_image.width, derived_image.height)

          if derived_image.file_type == 'GIF' # && derived_image.depth != 8 # TODO: submit patch to add depth attribute
            # as a special case hack, don't try and save 24-bit derived images into 8-bit-only GIF format
            # (ImageScience doesn't resample back down, so it throws errors if we try to do that)
            derived_content_type = 'image/png'
            derived_extension = 'png'
          else
            # both original_filename and content_type must be defined for parents when using image processing
            # - but apps can just define them using attr_accessor if they don't want them persisted to db
            derived_content_type = derived_image.mime_type || original_image.mime_type || content_type # note that mime_type will return nil instead of returning any of the freeimage-invented content types
            derived_extension = (derived_image.file_type || file_extension).downcase # in fact, derived_image.file_type should always work; the only situation in which it could return nil is if freeimage is extended to support a new image format but image_science_extensions isn't updated
          end
      
          # we leverage tempfiles as discussed in the uploaded_file method
          temp = ExtendedTempfile.new("asitemp", tempfile_directory, derived_extension)
          temp.binmode
          temp.close
          derived_image.save(temp.path)
          temp.open # we close & reopen so we see the file the processor wrote to, even if it created a new file rather than writing into our tempfile
        
          { :format_name => derived_format_name.to_s,
            :width => derived_image.width,
            :height => derived_image.height,
            :content_type => derived_content_type,
            :file_extension => derived_extension,
            :uploaded_data => temp }
        end
      end
      
      module Operations
        include AttachmentSaver::Processors::Image::Operations
        
        def file_type_extension
          file_type.downcase
        end
        
        def resize_to(new_width, new_height, &block)
          resize(new_width, new_height) do |image|
            image.extend Operations
            block.call(image) # ImageScience itself doesn't accept a block argument (it yields only)
          end
        end
        
        def crop_to(new_width, new_height, &block) # crops to the center
          left = (width - new_width)/2
          right = (height - new_height)/2
          with_crop(left, right, left + new_width, right + new_height) do |image|
            image.extend Operations
            block.call(image) # as for resize, with_crop doesn't take a block itself
          end
        end
      end
    end
  end
end
