begin
  require 'rmagick'
rescue LoadError
  require 'RMagick'
end
require 'processors/image'

class RMagickProcessorError < ImageProcessorError; end

module AttachmentSaver
  module Processors
    module RMagick
      include Image
      
      def with_image(filename, &block)
        image = Magick::Image.read(filename).first
        block.call(image.extend(Operations))
      end
      
      def with_image_attributes(filename, &block)
        image = Magick::Image.ping(filename).first
        block.call(image.extend(Operations))
      end
      
      def examine_image
        with_image_attributes(uploaded_file_path) do |original_image|
          self.width = original_image.width if respond_to?(:width)
          self.height = original_image.height if respond_to?(:height)
          self.content_type = original_image.corrected_mime_type unless self.class.attachment_options[:keep_content_type] || original_image.corrected_mime_type.nil?
          self.file_extension = original_image.file_type_extension unless self.class.attachment_options[:keep_file_extension] || original_image.file_type_extension.nil?
        end
      rescue AttachmentSaverError
        raise
      rescue Exception => ex
        raise RMagickProcessorError, "#{ex.class}: #{ex.message}", ex.backtrace
      end
      
      def process_image(original_image, derived_format_name, resize_format)
        resize_format = Image.from_geometry_string(resize_format) if resize_format.is_a?(String)

        result = original_image.send(*resize_format) do |derived_image|
          return nil unless want_format?(derived_format_name, derived_image.width, derived_image.height)

          # both original_filename and content_type must be defined for parents when using image processing
          # - but apps can just define them using attr_accessor if they don't want them persisted to db
          derived_content_type = derived_image.corrected_mime_type || original_image.corrected_mime_type || content_type
          derived_extension = derived_image.file_type_extension
      
          # we leverage tempfiles as discussed in the uploaded_file method
          temp = Tempfile.new(["asrtemp", ".#{derived_extension}"], tempfile_directory)
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

        # modern versions of RMagick don't leak memory.  however, the (many and large) internal
        # buffers malloced inside the ImageMagick library are not allocated via the Ruby memory
        # management functions.  as Ruby GC runs are normally triggered at the point when those Ruby
        # memory management functions request a larger heap, ImageMagick's extra allocations will
        # not trigger a GC run.  so while no memory has been leaked - all the allocations by the
        # ImageMagick library *will* get freed when GC runs - GC will typically not run even if you
        # process a series of images and end up using all of the memory that can be made available
        # to the process, at which point your process dies!  until such time as RMagick rewraps the
        # ImageMagick memory allocation functions to put them through Ruby's (as was done in the
        # as-yet-uncompleted MagickWand project), we force a GC after each image processing to
        # ensure that your processes stay happy.
        GC.start
        result
      end
      
      module Operations
        include AttachmentSaver::Processors::Image::Operations
        
        def corrected_mime_type
          case mime_type
            when 'image/x-jpeg'   then 'image/jpeg'
            when 'image/x-magick' then nil
            else mime_type
          end
        end
        
        def file_type_extension
          case format.downcase
            when 'jpeg' then 'jpg'
            else format.downcase
          end
        end
        
        def width
          columns
        end
        
        def height
          rows
        end
        
        def resize_to(new_width, new_height, &block)
          image = resize(new_width, new_height)
          image.extend Operations
          block.call(image)
        end
        
        def crop_to(new_width, new_height, &block) # crops to the center
          image = crop(Magick::CenterGravity, new_width, new_height, true)
          image.extend Operations
          block.call(image)
        end
      end
    end
  end
end
