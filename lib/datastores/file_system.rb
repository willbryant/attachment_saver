require 'fileutils'
require 'tempfile'
require 'attachment_saver_errors'

class FileSystemAttachmentDataStoreError < AttachmentDataStoreError; end

module AttachmentSaver
  module DataStores
    module FileSystem
      RETRIES = 100 # max attempts at finding a unique storage key.  very rare to have to retry at all, so if it fails after 100 attempts, something's seriously wrong.
      
      def self.included(base)
        base.attachment_options[:storage_directory] ||= File.join(RAILS_ROOT, 'public') # this is the part of the full filename that _doesn't_ form part of the HTTP path to the files
        base.attachment_options[:storage_path_base] ||= RAILS_ENV == 'production' ? base.table_name : File.join(RAILS_ENV, base.table_name) # and this is the part that does.
        base.attachment_options[:filter_filenames] = Regexp.new(base.attachment_options[:filter_filenames]) if base.attachment_options[:filter_filenames].is_a?(String) # may be nil, in which case the normal randomised-filename scheme is used instead of the filtered-original-filename scheme
        base.attachment_options[:file_permissions] = 0664 unless base.attachment_options.has_key?(:file_permissions) # we don't use || as nil is a meaningful value for this option - it means to not explicitly set the file permissions
      end
      
      def save_attachment
        return unless @save_upload # this method is called every time the model is saved, not just when a new file has been uploaded
        
        old_storage_key = storage_key
        @old_filenames ||= []
        @old_filenames << storage_filename unless storage_key.blank?
        self.storage_key = nil
        define_finalizer
        
        # choose a storage key (ie. path/filename) and try it; note that we assign a new 
        # storage key for every new upload, not just every new AR model, so that the URL
        # changes each time, which allows long/infinite cache TTLs & CDN support.
        begin
          if derive_storage_key?
            begin
              # for thumbnail/other derived images, we base the filename on the original 
              # (parent) image + the derived format name
              self.storage_key = derive_storage_key_from(original)
              save_attachment_to(storage_filename)
            rescue Errno::EEXIST # if clobbering pre-existing files (only possible if using filtered_filenames, and even then only if creating new derived images explicitly at some time other than during processing the parent), we still don't want to write into them, we want to use a new file & an atomic rename
              retries = 0
              begin
                self.storage_key = derive_storage_key_from(original, retries + 2) # +2 is arbitrary, I just think it's more human-friendly to go from xyz_thumb.jpg to xyz_thumb2.jpg rather than xyz_thumb0.jpg
                save_attachment_to(storage_filename)
              rescue Errno::EEXIST
                raise if (retries += 1) >= RETRIES # in fact it would be very unusual to ever need to retry at all, let alone multiple times; if you hit this, your operating system is actually broken (or someone's messed with storage_filename)
                retry # pick a new random name and try again
              end
            end
          else
            retries = 0
            begin
              if self.class.attachment_options[:filter_filenames] && respond_to?(:original_filename) && !original_filename.blank?
                # replace all the original_filename characters not included in the keep_filenames character list with underscores, leave the rest; store in randomized directories to avoid naming clashes
                basename = AttachmentSaver::split_filename(original_filename).first.gsub(self.class.attachment_options[:filter_filenames], '_')
                self.storage_key = File.join(self.class.attachment_options[:storage_path_base], random_segment(3), random_segment(3), "#{basename}.#{file_extension}")
              else
                # for new files under this option, we pick a random name (split into 3 parts - 2 directories and a file - to help keep the directories at manageable sizes), and never overwrite
                # this is the default setting, and IMHO the most best choice for most apps; the original filenames are typically pretty meaningless
                self.storage_key = File.join(self.class.attachment_options[:storage_path_base], random_segment(2), random_segment(2), "#{random_segment(6)}.#{file_extension}") # in fact just two random characters in the last part would be ample, since 36^(2+2+2) = billions, but we sacrifice 4 more characters of URL shortness for the benefit of ppl saving the assets to disk without renaming them
              end
              save_attachment_to(storage_filename)
            rescue Errno::EEXIST
              raise if (retries += 1) >= RETRIES # in fact it would be very unusual to ever need to retry at all, let alone multiple times; if you hit this, your operating system is actually broken (or someone's messed with storage_filename)
              retry # pick a new random name and try again
            end
          end

          # successfully written to file; process the attachment
          process_attachment_with_wrapping(storage_filename) if process_attachment?
          # if there's exceptions later (ie. during save itself) that prevent the record from being saved, the finalizer will clean up the file

          @save_upload = nil
        rescue Exception => ex
          FileUtils.rm_f(storage_filename) unless storage_key.blank? || ex.is_a?(Errno::EEXIST)
          self.storage_key = old_storage_key
          @old_filenames.pop unless old_storage_key.blank?
          raise if ex.is_a?(AttachmentSaverError)
          raise FileSystemAttachmentDataStoreError, "#{ex.class}: #{ex.message}", ex.backtrace
        end
      end
      
      def storage_filename
        File.join(self.class.attachment_options[:storage_directory], storage_key)
      end
      
      def in_storage?
        File.exists?(storage_filename)
      end
      
      def public_path
        "/#{storage_key.tr('\\', '/')}" # the tr is just for windows' benefit
      end
    
      def reprocess!
        raise "this attachment already has a file open to process" unless uploaded_file.nil?
        process_attachment_with_wrapping(storage_filename) if process_attachment?
        save!
      end
      
    protected
      RND_CHARS = ('a'..'z').to_a + ('0'..'9').to_a # we generously support case-insensitive filesystems.  aren't we nice?
      
      def tempfile_directory
        # tempfiles go under the same directory as the actual files will, so they'll be on the same filesystem and thus hardlinkable
        File.join(self.class.attachment_options[:storage_directory], self.class.attachment_options[:storage_path_base])
      end
      
      def random_segment(chars)
        Array.new(chars) .collect { RND_CHARS[rand(RND_CHARS.length)] } .join
      end
      
      def derive_storage_key?
        respond_to?(:format_name) && !format_name.blank? && respond_to?(:original) && !original.nil? &&
          original.class.included_modules.include?(FileSystem) &&
          original.respond_to?(:storage_key) && !original.storage_key.blank?
      end
      
      def derive_storage_key_from(original, suffix = nil)
        basename, extension = AttachmentSaver::split_filename(original.storage_key)
        "#{basename}_#{format_name}#{suffix}.#{file_extension}"
      end
      
      def tidy_attachment # called after_save
        FileUtils.rm_f(@old_filenames)   unless @old_filenames.blank? || self.class.attachment_options[:keep_old_files]
        ObjectSpace.undefine_finalizer(self)
      rescue Exception => ex
        raise FileSystemAttachmentDataStoreError, "#{ex.class}: #{ex.message}", ex.backtrace
      end
      
      def delete_attachment # called after_destroy
        FileUtils.rm_f(storage_filename) unless storage_key.blank?
        FileUtils.rm_f(@old_filenames)   unless @old_filenames.blank? || self.class.attachment_options[:keep_old_files]
        ObjectSpace.undefine_finalizer(self)
      rescue Exception => ex
        raise FileSystemAttachmentDataStoreError, "#{ex.class}: #{ex.message}", ex.backtrace
      end
      
      def define_finalizer
        ObjectSpace.undefine_finalizer(self)
        ObjectSpace.define_finalizer(self, lambda { # called on GC finalization if a save was attempted at some point but wasn't completed (presumably because an exception was raised)
          FileUtils.rm_f(storage_filename)   if new_record? && !storage_key.blank?
          FileUtils.rm_f(@old_filenames) unless @old_filenames.blank? || self.class.attachment_options[:keep_old_files]
        })
      end
      
      # attempts to write the uploaded data/file to the given filename, setting the file
      # open flags so that Errno::EEXIST will be thrown if the file already exists.
      # creates any missing parent directories.
      def save_attachment_to(filename)
        binary_mode = defined?(File::BINARY) ? File::BINARY : 0
        open_mode = File::CREAT | File::RDWR | File::EXCL | binary_mode
        
        FileUtils.mkdir_p(File.dirname(filename))
        
        if @uploaded_data
          File.open(filename, open_mode, self.class.attachment_options[:file_permissions]) do |fout| 
            fout.write(@uploaded_data)
          end
        else
          # typically, the temp file we get given when a user uploads a file is on the same
          # volume as the directory we're storing to, and since the temporary uploaded files
          # aren't changed ever - they're unlinked when we finish processing the request - we
          # can just efficiently hardlink it instead of wasting time & IO making an independent
          # copy of it.  of course, we still need to make a copied file if it isn't on the same
          # volume, if the destination file already exists, if we're on an OS that doesn't
          # support hardlinks, or if the 'uploaded' file isn't a temporary uploaded file at all
          # (presumably someone running an import job) - we don't want any nasty semantics 
          # surprises with non-uploaded files!
          if @uploaded_file.is_a?(Tempfile)
            @uploaded_file.flush
            begin
              FileUtils.ln(@uploaded_file.path, filename)
              (File.chmod(self.class.attachment_options[:file_permissions], @uploaded_file.path) rescue nil) unless self.class.attachment_options[:file_permissions].nil? 
              return # successfully linked, we're done
            rescue
              # ignore and fall through do, it the long way
            end
          end
          File.open(filename, open_mode, self.class.attachment_options[:file_permissions]) do |fout|
            @uploaded_file.rewind
            while data = @uploaded_file.read(4096) 
              fout.write(data)
            end
          end
        end
      end
    end
  end
end
