require 'image_size'
require 'misc/extended_tempfile'
require 'processors/image'

class ImageSizeProcessorError < ImageProcessorError; end

module AttachmentSaver
  module Processors
    module ImageSize
      include Image
      
      def examine_image
        image_size = ::ImageSize.path(uploaded_file_path)
        raise ImageSizeProcessorError, "Not an image" if image_size.format.nil?

        self.width = image_size.width if respond_to?(:width)
        self.height = image_size.height if respond_to?(:height)
        self.file_extension = extension_for_image_format(image_size.format) unless self.class.attachment_options[:keep_file_extension]
        self.content_type = mime_type_for_image_format(image_size.format) unless self.class.attachment_options[:keep_content_type]
      rescue AttachmentSaverError
        raise
      rescue Exception => ex
        raise ImageSizeProcessorError, "#{ex.class}: #{ex.message}", ex.backtrace
      end

      def extension_for_image_format(format)
        case format
        when :jpeg then 'jpg'
        else format.to_s
        end
      end

      def mime_type_for_image_format(format)
        "image/#{format}"
      end

      def with_image(*args)
        raise NotImplementedError, "the image_size processor can only be used to check image types and dimensions, not produce resized images"
      end
    end
  end
end
