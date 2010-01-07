require 'attachment_saver_errors'

class InColumnAttachmentDatastoreError < AttachmentDataStoreError; end

module AttachmentSaver
  module DataStores
    module InColumn
      def self.included(base)
        base.attachment_options[:column_name] ||= 'data'
        base.attachment_options[:temp_directory] ||= Dir.tmpdir
      end
      
      def save_attachment
        return unless @save_upload # this method is called every time the model is saved, not just when a new file has been uploaded

        if @uploaded_data
          send("#{self.class.attachment_options[:column_name]}=", @uploaded_data)
        else
          @uploaded_file.rewind
          send("#{self.class.attachment_options[:column_name]}=",  @uploaded_file.read)
        end

        save_temporary_and_process_attachment if process_attachment?

        @save_upload = nil
      end
      
      def   tidy_attachment; end
      def delete_attachment; end # delete_attachment is used when the record is deleted, so we don't need to do anything
      
      def in_storage?
        !send(self.class.attachment_options[:column_name]).nil?
      end
      
      # there is no public_path, since you need to make a controller to pull the blob from the database

      def reprocess!
        raise "this attachment already has a file open to process" unless uploaded_file.nil?
        save_temporary_and_process_attachment
        save!
      end
      
      def save_temporary_and_process_attachment
        Tempfile.open("asctemp", FileUtils.mkdir_p(self.class.attachment_options[:temp_directory])) do |temp|
          temp.binmode
          temp.write(send(self.class.attachment_options[:column_name]))
          temp.flush
          process_attachment_with_wrapping(temp.path)
        end
      end
    end
  end
end
