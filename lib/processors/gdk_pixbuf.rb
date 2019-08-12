require 'gdk_pixbuf2'
require 'processors/image'

class GdkPixbufProcessorError < ImageProcessorError; end

module AttachmentSaver
  module Processors
    module GdkPixbuf
      include Image

      def with_image(filename, &block)
        # we use GdkPixbuf::PixbufLoader rather than GdkPixbuf::Pixbuf.new(filename) so that we can learn the format of the
        # image, which process_image wants to know so that it can save the derived images in the same format.
        loader = ::GdkPixbuf::PixbufLoader.new
        File.open(filename, "rb") do |file|
          while buf = file.read(65536)
            loader.write(buf)
          end
        end
        loader.close
        image = loader.pixbuf
        image.extend(Operations)
        image.format = loader.format.name
        image.file_extension = normalize_extension(loader.format.extensions.first)
        block.call(image)
      end

      def examine_image
        fileinfo, width, height = ::GdkPixbuf::Pixbuf.get_file_info(uploaded_file_path)
        raise GdkPixbufProcessorError, "Not an image" if fileinfo.nil?

        self.width = width if respond_to?(:width)
        self.height = height if respond_to?(:height)
        self.content_type = fileinfo.mime_types.first unless self.class.attachment_options[:keep_content_type] || fileinfo.mime_types.empty?
        self.file_extension = normalize_extension(fileinfo.extensions.first) unless self.class.attachment_options[:keep_file_extension] || fileinfo.extensions.empty?
      rescue AttachmentSaverError
        raise
      rescue Exception => ex
        raise GdkPixbufProcessorError, "#{ex.class}: #{ex.message}", ex.backtrace
      end

      def normalize_extension(extension)
        case extension
        when 'jpeg' then 'jpg'
        else extension
        end
      end

      def process_image(original_image, derived_format_name, resize_format)
        resize_format = Image.from_geometry_string(resize_format) if resize_format.is_a?(String)

        result = original_image.send(*resize_format) do |derived_image|
          return nil unless want_format?(derived_format_name, derived_image.width, derived_image.height)

          if original_image.format == 'gif'
            # as a special case hack, don't try and save derived images into GIF format (gdk_pixbuf2 doesn't support that)
            derived_content_type = 'image/png'
            derived_extension = 'png'
            format = 'png'
          else
            # both original_filename and content_type must be defined for parents when using image processing
            # - but apps can just define them using attr_accessor if they don't want them persisted to db
            derived_content_type = content_type
            derived_extension = derived_image.file_extension
            format = original_image.format
          end

          # we leverage tempfiles as discussed in the uploaded_file method
          temp = Tempfile.new(["asgtemp", ".#{derived_extension}"], tempfile_directory)
          temp.binmode
          temp.close
          derived_image.save(temp.path, format)
          temp.open # we close & reopen so we see the file the processor wrote to, even if it created a new file rather than writing into our tempfile

          { :format_name => derived_format_name.to_s,
            :width => derived_image.width,
            :height => derived_image.height,
            :content_type => derived_content_type,
            :file_extension => derived_extension,
            :uploaded_data => temp }
        end

        result
      end

      module Operations
        include AttachmentSaver::Processors::Image::Operations

        attr_accessor :format, :file_extension

        def resize_to(new_width, new_height, &block)
          image = scale(new_width, new_height)
          image.extend Operations
          image.format = format
          image.file_extension = file_extension
          block.call(image)
        end

        def crop_to(new_width, new_height, &block) # crops to the center
          method = respond_to?(:subpixbuf) ? :subpixbuf : :new_subpixbuf
          image = send(method, (width - new_width)/2, (height - new_height)/2, new_width, new_height)
          image.extend Operations
          image.format = format
          image.file_extension = file_extension
          block.call(image)
        end
      end
    end
  end
end
