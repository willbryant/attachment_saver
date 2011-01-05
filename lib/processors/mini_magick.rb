require 'mini_magick'
require 'misc/mini_magick_extensions'
require 'misc/extended_tempfile'
require 'processors/image'

class MiniMagickProcessorError < ImageProcessorError; end

module AttachmentSaver
  module Processors
    module MiniMagick
      include Image
      
      def with_image(filename, &block)
        # note that we are instantiating minimagick on the file itself, not a copy (which is
        # what gets produced if you call from_file); we don't do any mutating operations on
        # our instances themselves (resize_to and crop_to create new instances).
        if ::MiniMagick::Image.respond_to?(:open) # v3
          image = ::MiniMagick::Image.open(filename)
        else # v1
          image = ::MiniMagick::Image.new(filename)
        end
        block.call(image.extend(Operations))
      end
      
      def with_image_attributes(filename, &block)
        # MiniMagick doesn't actually load the image, it just keeps a reference to the filename
        # and invokes the imagemagick programs to determine attributes
        with_image(filename, &block)
      end
      
      def examine_attachment
        with_image_attributes(uploaded_file_path) do |original_image|
          self.content_type = original_image.mime_type unless self.class.attachment_options[:keep_content_type] || original_image.mime_type.blank?
          self.file_extension = original_image.file_type_extension unless self.class.attachment_options[:keep_file_extension] || original_image.file_type_extension.blank?
          self.width = original_image.width if respond_to?(:width)
          self.height = original_image.height if respond_to?(:height)
        end
      rescue AttachmentSaverError
        raise
      rescue Exception => ex
        raise MiniMagickProcessorError, "#{ex.class}: #{ex.message}", ex.backtrace
      end
      
      def process_image(original_image, derived_format_name, resize_format)
        resize_format = Image.from_geometry_string(resize_format) if resize_format.is_a?(String)

        original_image.send(*resize_format) do |derived_image|
          return nil unless want_format?(derived_format_name, derived_image.width, derived_image.height)

          # both original_filename and content_type must be defined for parents when using image processing
          # - but apps can just define them using attr_accessor if they don't want them persisted to db
          derived_content_type = derived_image.mime_type || original_image.mime_type || content_type
          derived_extension = derived_image.file_type_extension
      
          # we leverage tempfiles as discussed in the uploaded_file method
          temp = ExtendedTempfile.new("asmtemp", tempfile_directory, derived_extension)
          temp.binmode
          temp.close
          derived_image.write(temp.path)
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
          case format.downcase
            when 'jpeg' then 'jpg'
            else format.downcase
          end
        end
        
        def format; @__format ||= self[:format]; end  # cached as each call to [] results in a process execution!
        def width;   @__width ||= self[:width];  end  # note that we can cache as we don't ever modify instances -
        def height; @__height ||= self[:height]; end  # whereas MiniMagick may, in general.
        
        def resize_to(new_width, new_height, &block)
          image = dup
          image.resize("#{new_width}x#{new_height}!")
          image.extend Operations
          block.call(image)
        end
        
        def crop_to(new_width, new_height, &block) # crops to the center
          left = (width - new_width)/2
          right = (height - new_height)/2
          image = dup
          image << "-crop #{new_width}x#{new_height}+#{left}+#{right} +repage" # mini_magick's #crop doesn't support the repage flag
          image.extend Operations
          block.call(image)
        end
      end
    end
  end
end