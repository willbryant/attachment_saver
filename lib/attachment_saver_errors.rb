class AttachmentSaverError < StandardError; end
class AttachmentDataStoreError < AttachmentSaverError; end
class AttachmentProcessorError < AttachmentSaverError; end