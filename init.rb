require 'attachment_saver'
ActiveRecord::Base.send(:extend, AttachmentSaver::BaseMethods)
