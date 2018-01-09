#!/usr/bin/env ruby
require 'fileutils'
require 'active_record'
require 'active_support/inflector'
require 'attachment_saver'
require File.expand_path(File.join(File.dirname(__FILE__), 'test', 'image_operations'))

sample_dir = File.expand_path(File.join(File.dirname(__FILE__), 'samples'))
FileUtils.rm_r(sample_dir)
FileUtils.mkdir(sample_dir)

original_filenames = %w(test/fixtures/test.jpg test/fixtures/pd.png)

processors = %w(ImageScience RMagick MiniMagick GdkPixbuf).each.with_object({}) do |processor, results|
  require "processors/#{processor.underscore}"

  instance = Object.new
  instance.class_eval { attr_accessor :content_type }
  instance.extend(AttachmentSaver::InstanceMethods)
  instance.extend(AttachmentSaver::Processors.const_get(processor))

  results[processor] = instance
end

File.open("samples.html", "w") do |html|
  html.write "<html><body>"

  original_filenames.each do |original_filename|
    html.write "<h1>#{original_filename}</h1><table border='2'><tr><th></th>"
    processors.each do |processor, instance|
      html.write "<th>#{processor}</th>"
    end
    html.write "</tr>"

    ImageOperations.resize_operations.each do |derived_format_name, format_definition|
      html.write "<tr><th>#{derived_format_name}<br/><pre>#{format_definition.inspect}</pre></th>"
      processors.each do |processor, instance|
        instance.with_image(original_filename) do |original_image|
          result = instance.process_image(original_image, derived_format_name, format_definition)

          filename = "#{sample_dir}/#{processor.underscore}-#{File.basename original_filename}-#{result[:format_name]}.#{result[:file_extension]}"
          File.open(filename, "wb") do |f|
            result[:uploaded_data].rewind
            IO.copy_stream(result[:uploaded_data], f)
          end
          size = result[:uploaded_data].size < 1024 ? "#{result[:uploaded_data].size} bytes" : "%0.1fkb" % (result[:uploaded_data].size/1024.0)
          html.write "<td><img src='#{filename}' width='#{result[:width]}' height='#{result[:height]}'><br/>#{size}</td>"
        end
      end
      html.write "</tr>"
    end

    html.write "</table>"
  end

  html.write "</html></body>"
end
