require 'attachment_saver_errors'
require 'mimemagic'

class ImageProcessorError < AttachmentProcessorError; end

module AttachmentSaver
  module Processors
    # shared code for all image processors
    module Image
      DEFAULT_VALID_IMAGE_TYPES = %w(image/jpeg image/png image/gif).freeze

      def image?
        return false if content_type.blank?
        parts = content_type.split(/\//)
        parts.size == 2 && parts.first.strip == 'image'
      end

      def valid_image_type
        valid_image_types = self.class.attachment_options[:valid_image_types] || DEFAULT_VALID_IMAGE_TYPES

        uploaded_file.rewind
        magic = MimeMagic.by_magic(uploaded_file)

        if magic.nil?
          # if it doesn't look like an image, make sure it's not labelled as an image
          self.content_type = 'application/octet-stream' if image? || content_type.nil?
        elsif !valid_image_types.include?(magic.type)
          # overwrite the content type given by the untrusted client with the real content type; it may get refined later by the image processor
          self.content_type = magic.type
        else
          # seems legit
          return true
        end

        errors.add(:content_type, "is invalid") if respond_to?(:errors)
        false
      end
      
      def before_validate_attachment
        unless uploaded_file.nil? || derived_image?
          return false unless valid_image_type
          examine_image
        end
      rescue ImageProcessorError
        # we examine all files, regardless of whether the client browser labelled them an
        # image, because they may be an image with the wrong extension or content type.
        # but this will raise for non-image files, so ignore such errors but make sure
        # image? will return false, if it doesn't already.
        self.content_type = "application/octet-stream" if image?
      end

      def process_attachment?
        image? && !self.class.attachment_options[:formats].blank? && !derived_image?
      end
      
      # determines if this is a derived image.  used to prevent infinite recursion when 
      # storing the derived images in the same model as the originals (and as a secondary
      # benefit avoid unnecessary work examining images for derived images, for which the
      # full metadata is already filled in by the resizing code).
      def derived_image?
        respond_to?(:format_name) && !format_name.blank?
      end
      
      # determines if a particular configured derived image should be created.  this
      # implementation, which always returns true, may be overridden by applications to make
      # certain formats conditional (for example, only creating certain larger sizes if the 
      # original image was at least that large).
      def want_format?(derived_name, derived_width, derived_height)
        true
      end

      def process_attachment(filename)
        with_image(filename) do |original_image|
          unless self.class.attachment_options[:formats].blank?
            old_children = new_record? ? {} : formats.group_by(&:format_name)
            self.class.attachment_options[:formats].each do |derived_name, resize_format|
              derived_attributes = process_image(original_image, derived_name, resize_format)
              if derived_attributes
                if old_children[derived_name.to_s]
                  update_derived(old_children[derived_name.to_s].pop, derived_attributes)
                else
                  build_derived(derived_attributes)
                end
              end
            end
            old_children = old_children.values.flatten
            formats.destroy(old_children) unless old_children.blank? # remove any old derived images for formats for which want_format? now returned false
          end
        end
      rescue AttachmentSaverError
        raise
      rescue NotImplementedError
        raise
      rescue Exception => ex
        raise ImageProcessorError, "#{ex.class}: #{ex.message}", ex.backtrace
      end
      
      # builds a new derived image model instance, but doesn't save it.
      # provided so apps can easily override this step.
      def build_derived(attributes)
        formats.build(attributes)
      end
      
      # updates an existing derived image model instance, and queues it for save when this
      # model is saved.  provided so apps can easily override this step.
      def update_derived(derived, attributes)
        derived.attributes = attributes
        @updated_derived_children ||= []
        @updated_derived_children << derived # we don't want to save it just yet in case processing subsequent images fail; rails will automatically save it if we're a new record, but we have to do it ourselves in an after_save if not
        derived
      end
      
      # unpacks a resize geometry string into an array contining the corresponding image
      # operation method name (see Operations below, plus any from your chosen image processor)
      # followed by the arguments to that method.
      def self.from_geometry_string(geom)
        match, w, cross, h, flag = geom.match(/^(\d+\.?\d*)?(?:([xX])(\d+\.?\d*)?)?([!%<>#*])?$/).to_a
        raise "couldn't parse geometry string '#{geom}'" if match.nil? || (w.nil? && h.nil?)
        h = w unless cross # there's <w>x<h>, there's <w>x, there's x<h>, and then there's just plain <n>, which means <w>=<h>=<n>
        return [:scale_by, (w || h).to_f/100, (h || w).to_f/100] if flag == '%'
        operation = case flag
          when nil then :scale_to_fit
          when '!' then w && h ? :squish : :scale_to_fit
          when '>' then :shrink_to_fit
          when '<' then :expand_to_fit
          when '*' then :scale_to_cover
          when '#' then :cover_and_crop
        end
        [operation, w ? w.to_i : nil, h ? h.to_i : nil]
      end
      
      module Operations
        # if they choose to use this module to implement the resize operations, the processor
        # module just needs to implement width, height, resize_to(new_width, new_height, &block),
        # and crop_to(new_width, new_height, &block).  they also need with_image for process_attachment.
        
        # squishes the image to the given width and height, without preserving the aspect ratio.
        # yields this image itself if it is already the given size.
        def squish(new_width, new_height, &block)
          return block.call(self) if new_width == width && new_height == height
          resize_to(new_width.to_i, new_height.to_i, &block)
        end
        
        # scales the image by the given factors.
        def scale_by(width_factor, height_factor, &block)
          squish(width*width_factor, height*height_factor, &block)
        end
        
        # calculates the appropriate dimensions for scale_to_fit.
        def scale_dimensions_to_fit(new_width, new_height)
          raise ArgumentError, "must supply the width and/or height" if new_width.nil? && new_height.nil?
          if new_height.nil? || (!new_width.nil? && height*new_width < width*new_height)
            return [new_width, height*new_width/width]
          else
            return [width*new_height/height, new_height]
          end
        end
        
        # scales the image proportionately so that it fits within the given width and height
        # (ie. one dimension will be equal to the given dimension, and the other dimension
        # will be smaller than the given other dimension).  either (but not both) of the new
        # width & height may be nil, in which case the image will be scaled solely based on
        # the other parameter.  yields this image itself if it is already the appropriate size.
        def scale_to_fit(new_width, new_height, &block)
          squish(*scale_dimensions_to_fit(new_width, new_height), &block)
        end
        
        # keeps proportions, as for scale_to_fit, but only ever makes images smaller.
        # yields this image itself if it is already within the given dimensions.
        def shrink_to_fit(new_width, new_height, &block)
          new_width, new_height = scale_dimensions_to_fit(new_width, new_height)
          return block.call(self) if new_width >= width && new_height >= height
          squish(new_width, new_height, &block)
        end
        
        # keeps proportions, as for scale_to_fit, but only ever makes images bigger.
        # yields this image itself if it is already within the given dimensions or if the
        # scaled dimensions would be smaller than the current dimensions.
        # this is one of the operations specified by the *magick geometry strings, but
        # IMHO it's not particularly useful as it doesn't establish any particularly helpful
        # postconditions; consider whether scale_to_cover would be more appropriate.
        def expand_to_fit(new_width, new_height, &block)
          new_width, new_height = scale_dimensions_to_fit(new_width, new_height)
          return block.call(self) if new_width <= width && new_height <= height
          squish(new_width, new_height, &block)
        end
        
        # scales the image proportionately so that it fits over the given width and height (ie.
        # one dimension will be equal to the given dimension, and the other dimension will be
        # larger than the given other dimension).  either (but not both) of the new width & 
        # height may be nil, in which case the image will be scaled solely based on the other
        # parameter (in this case the result is the same as using scale_to_fit).
        # yields this image itself if it is already the appropriate size.
        def scale_to_cover(new_width, new_height, &block)
          raise ArgumentError, "must supply the width and/or height" if new_width.nil? && new_height.nil?
          if new_height.nil? || (!new_width.nil? && height*new_width > width*new_height)
            squish(new_width, height*new_width/width, &block)
          else
            squish(width*new_height/height, new_height, &block)
          end
        end
        # haven't seen any reason to implement shrink_to_cover and expand_to_cover yet, but could.
        
        # scales the image proportionately to fit over the given width and height (as for
        # scale_to_cover), then crops the image to the given width & height.
        # yields this image itself if it is already the appropriate size.
        def cover_and_crop(new_width, new_height, &block)
          scale_to_cover(new_width, new_height) do |scaled|
            return block.call(scaled) if new_width == scaled.width && new_height == scaled.height
            scaled.crop_to(new_width || width, new_height || height, &block)
          end
        end
      end
    end
  end
end